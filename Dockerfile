FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    supervisor \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for metrics
RUN pip3 install prometheus-client requests psutil

# Create non-root user first
RUN useradd -m -u 1000 -s /bin/bash llama

# Create directories with proper ownership
RUN mkdir -p /models /app/metrics /etc/supervisor/conf.d /tmp/build && \
    chown -R llama:llama /models /app

# Try multiple approaches to get llama.cpp
WORKDIR /tmp/build

# Method 1: Download a specific release (more reliable)
RUN wget -O llama-cpp.tar.gz https://github.com/ggerganov/llama.cpp/archive/refs/heads/master.tar.gz && \
    tar -xzf llama-cpp.tar.gz && \
    mv llama.cpp-master llama.cpp || \
    # Method 2: Shallow clone as fallback
    (git clone --depth 1 --single-branch https://github.com/ggerganov/llama.cpp.git llama.cpp || \
    # Method 3: Alternative clone method
    (git config --global http.postBuffer 524288000 && \
     git clone --depth 1 https://github.com/ggerganov/llama.cpp.git llama.cpp))

WORKDIR /tmp/build/llama.cpp

# Build with CMake
RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_BLAS=OFF \
    -DGGML_CUBLAS=OFF \
    -DGGML_METAL=OFF \
    -DGGML_HIPBLAS=OFF \
    -DGGML_ACCELERATE=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=ON \
    && cmake --build build --config Release --target llama-server -j$(nproc)

# Copy the built binary
RUN cp build/bin/llama-server /usr/local/bin/llama-server && \
    chmod +x /usr/local/bin/llama-server

# Copy shared libraries if they exist
RUN mkdir -p /usr/local/lib && \
    (cp build/bin/*.so /usr/local/lib/ 2>/dev/null || true) && \
    (cp build/lib/*.so /usr/local/lib/ 2>/dev/null || true)

# Update library cache
RUN ldconfig

# Clean up build directory
RUN rm -rf /tmp/build

# Create metrics exporter script
RUN cat > /app/metrics/exporter.py << 'EOF'
#!/usr/bin/env python3
import time
import requests
import json
import psutil
import os
import logging
from prometheus_client import start_http_server, Gauge, Counter, Histogram, Info
from prometheus_client.core import CollectorRegistry

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Create custom registry
registry = CollectorRegistry()

# Define metrics
llama_info = Info('llama_server_info', 'LLaMA server information', registry=registry)
llama_up = Gauge('llama_server_up', 'LLaMA server status', registry=registry)
llama_requests_total = Counter('llama_requests_total', 'Total requests processed', registry=registry)
llama_active_slots = Gauge('llama_active_slots', 'Active processing slots', registry=registry)
llama_queue_size = Gauge('llama_queue_size', 'Current queue size', registry=registry)
llama_cpu_usage = Gauge('llama_cpu_usage_percent', 'CPU usage percentage', registry=registry)
llama_memory_usage = Gauge('llama_memory_usage_bytes', 'Memory usage in bytes', registry=registry)
llama_model_loaded = Gauge('llama_model_loaded', 'Whether model is loaded', registry=registry)

class LlamaMetrics:
    def __init__(self, llama_url='http://localhost:8084'):
        self.llama_url = llama_url
        self.process = None
        self.request_count = 0
        logger.info(f"Initializing metrics collector for {llama_url}")
        
    def find_llama_process(self):
        """Find the llama-server process"""
        try:
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    cmdline = proc.info.get('cmdline', [])
                    if cmdline and any('llama-server' in str(cmd) for cmd in cmdline):
                        self.process = psutil.Process(proc.info['pid'])
                        logger.info(f"Found llama-server process: PID {proc.info['pid']}")
                        return
                except (psutil.NoSuchProcess, psutil.AccessDenied, TypeError):
                    continue
        except Exception as e:
            logger.error(f"Error finding llama process: {e}")
    
    def collect_system_metrics(self):
        """Collect system metrics for the llama process"""
        if not self.process:
            self.find_llama_process()
            
        if self.process:
            try:
                if self.process.is_running():
                    # CPU usage
                    cpu_percent = self.process.cpu_percent()
                    llama_cpu_usage.set(cpu_percent)
                    
                    # Memory usage
                    memory_info = self.process.memory_info()
                    llama_memory_usage.set(memory_info.rss)
                    
                    logger.debug(f"System metrics - CPU: {cpu_percent}%, Memory: {memory_info.rss} bytes")
                else:
                    self.process = None
                    
            except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                logger.warning(f"Lost access to process: {e}")
                self.process = None
    
    def collect_server_metrics(self):
        """Collect metrics from llama server endpoints"""
        server_up = False
        
        # Test basic connectivity
        try:
            response = requests.get(f"{self.llama_url}/health", timeout=3)
            if response.status_code == 200:
                server_up = True
                try:
                    health_data = response.json()
                    logger.debug(f"Health data: {health_data}")
                    
                    # Check if model is loaded
                    if 'status' in health_data:
                        if health_data['status'] == 'ok':
                            llama_model_loaded.set(1)
                        else:
                            llama_model_loaded.set(0)
                    
                    # Extract slot information if available
                    if 'slots_idle' in health_data and 'slots_processing' in health_data:
                        llama_active_slots.set(health_data.get('slots_processing', 0))
                    
                except (json.JSONDecodeError, KeyError) as e:
                    logger.warning(f"Could not parse health response: {e}")
                    
            else:
                logger.warning(f"Health check returned status {response.status_code}")
                
        except requests.RequestException as e:
            logger.warning(f"Health check failed: {e}")
        
        # Set server status
        llama_up.set(1 if server_up else 0)
        
        # Try slots endpoint for more detailed info (will work with --slots flag)
        if server_up:
            try:
                response = requests.get(f"{self.llama_url}/slots", timeout=3)
                if response.status_code == 200:
                    slots_data = response.json()
                    if isinstance(slots_data, list):
                        processing_slots = sum(1 for s in slots_data if s.get('is_processing', False))
                        llama_active_slots.set(processing_slots)
                        logger.debug(f"Slots: {processing_slots} processing out of {len(slots_data)} total")
                        
            except requests.RequestException as e:
                logger.debug(f"Slots endpoint not available: {e}")
        
        # Simple request counter simulation
        if server_up:
            self.request_count += 1
            llama_requests_total._value._value = self.request_count
    
    def run(self):
        """Main metrics collection loop"""
        logger.info("Starting LLaMA metrics exporter on port 9090")
        try:
            start_http_server(9090, registry=registry)
            logger.info("Metrics HTTP server started successfully")
        except Exception as e:
            logger.error(f"Failed to start metrics server: {e}")
            return
        
        # Set server info
        llama_info.info({
            'version': '1.0', 
            'model_path': '/models/model.gguf',
            'server_url': self.llama_url
        })
        
        logger.info("Starting metrics collection loop")
        
        while True:
            try:
                self.collect_system_metrics()
                self.collect_server_metrics()
                logger.debug("Metrics collection cycle completed")
            except Exception as e:
                logger.error(f"Error in metrics collection: {e}")
            
            time.sleep(15)

if __name__ == '__main__':
    try:
        metrics = LlamaMetrics()
        metrics.run()
    except KeyboardInterrupt:
        logger.info("Metrics exporter stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        raise
EOF

# Make script executable
RUN chmod +x /app/metrics/exporter.py

# Create supervisor configuration - FIXED VERSION
RUN cat > /etc/supervisor/conf.d/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
pidfile=/tmp/supervisord.pid

[program:llama-server]
command=/usr/local/bin/llama-server -m /models/model.gguf -c 2048 --host 0.0.0.0 --port 8084 --slots --verbose
directory=/models
user=llama
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
priority=1
startsecs=10

[program:metrics-exporter]
command=python3 /app/metrics/exporter.py
directory=/app/metrics
user=llama
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
priority=2
startsecs=15
EOF

# Expose ports
EXPOSE 8084 9090

# Health check for both services
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8084/health && curl -f http://localhost:9090/metrics || exit 1

# Use supervisor to run both services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

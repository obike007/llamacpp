# llamacpp
# 🦙 LlamaCPP Kubernetes Deployment

A complete CI/CD pipeline for deploying LlamaCPP models on Kubernetes with automated model management, monitoring, and observability.

## 🌟 Features

- **🚀 Automated CI/CD Pipeline** - GitHub Actions workflow for seamless deployments
- **📦 Smart Model Management** - Intelligent model downloading and caching
- **📊 Comprehensive Monitoring** - Prometheus metrics collection and Grafana visualization
- **🔄 Zero-Downtime Deployments** - Rolling updates with health checks
- **⚡ Fast Deployments** - Optimized pipeline reducing deployment time from 20+ to 5 minutes
- **🛡️ Production Ready** - Resource limits, security contexts, and resilience patterns
- **🎯 Kind Integration** - Local development with Kind (Kubernetes in Docker)

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub        │    │   Kubernetes    │    │   Monitoring    │
│   Actions       │───▶│   Cluster       │───▶│   Stack         │
│                 │    │                 │    │                 │
│ • Build Image   │    │ • LlamaCPP App  │    │ • Prometheus    │
│ • Run Tests     │    │ • Model Storage │    │ • Grafana       │
│ • Deploy        │    │ • Health Checks │    │ • Alerting      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

### Required Tools
- [Docker](https://docs.docker.com/get-docker/) - Container runtime
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) - Local Kubernetes clusters

### GitHub Secrets
Configure these secrets in your repository (`Settings` → `Secrets and variables` → `Actions`):

| Secret | Description | Example |
|--------|-------------|---------|
| `DOCKER_HUB_USERNAME` | Your Docker Hub username | `myusername` |
| `DOCKER_HUB_TOKEN` | Docker Hub access token | `dckr_pat_...` |

> 💡 **Get Docker Hub Token**: Go to [Docker Hub](https://hub.docker.com) → Account Settings → Security → New Access Token

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd llamacpp-k8s
```

### 2. Local Development
```bash
# Create local Kind cluster
kind create cluster --name llama-cluster --config kind-config.yaml

# Set kubectl context
kubectl cluster-info --context kind-llama-cluster
```

### 3. Deploy Application
```bash
# Push code to main branch to trigger deployment
git add .
git commit -m "Initial deployment"
git push origin main
```

### 4. Access Services
After deployment completes:

```bash
# Application endpoint
curl http://localhost:8084/health

# Grafana dashboard
open http://localhost:3001
# Default login: admin/admin

# Prometheus metrics
open http://localhost:9090
```

## 📁 Project Structure

```
llamacpp-k8s/
├── .github/
│   └── workflows/
│       └── main.yml              # CI/CD pipeline
├── kubernetes/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── configmap.yaml            # Application configuration
│   ├── deployment.yaml           # Main application deployment
│   └── service.yaml              # Service definitions
├── scripts/
│   └── setup-monitoring.sh       # Monitoring stack setup
├── Dockerfile                    # Container image definition
├── kind-config.yaml              # Kind cluster configuration
└── README.md                     # This file
```

## 🔧 Configuration

### Application Configuration
Edit `kubernetes/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llamacpp-config
  namespace: llama-app
data:
  # Model configuration
  model_path: "/models/model.gguf"
  context_size: "4096"
  
  # Performance settings
  threads: "4"
  gpu_layers: "0"
  
  # API settings
  host: "0.0.0.0"
  port: "8084"
```

### Model Configuration
The pipeline uses **Llama-2-7B-GGUF** by default. To change models:

1. **Update the model URL** in `.github/workflows/main.yml`:
   ```yaml
   MODEL_URL="https://huggingface.co/YOUR_MODEL_PATH/model.gguf"
   ```

2. **Adjust resource limits** in `kubernetes/deployment.yaml`:
   ```yaml
   resources:
     requests:
       memory: "2Gi"    # Increase for larger models
       cpu: "1000m"
     limits:
       memory: "8Gi"    # Adjust based on model size
       cpu: "4000m"
   ```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow consists of:

### 1. **Build & Push** (2-3 minutes)
- Builds Docker image
- Pushes to Docker Hub with caching
- Tags with commit SHA and `latest`

### 2. **Deploy to Kind** (varies by deployment type)
- Creates Kind cluster with port mappings
- Sets up Kubernetes infrastructure
- Deploys application and monitoring

### Pipeline Optimization
- **First deployment**: ~20-25 minutes (downloads 4GB model)
- **Subsequent deployments**: ~7-10 minutes (model cached)

## 📊 Monitoring & Observability

### Prometheus Metrics
The application exposes metrics at `/metrics`:

```bash
# View available metrics
curl http://localhost:8084/metrics

# Key metrics include:
# - llamacpp_requests_total
# - llamacpp_request_duration_seconds
# - llamacpp_model_load_time_seconds
# - llamacpp_memory_usage_bytes
```

### Grafana Dashboards
Access Grafana at `http://localhost:3001`:

1. **Model Performance Dashboard**
   - Request latency and throughput
   - Token generation speed
   - Model load times

2. **Infrastructure Dashboard**
   - CPU and memory usage
   - Pod restart counts
   - Storage utilization

3. **Business Metrics Dashboard**
   - API endpoint usage
   - Error rates
   - User engagement patterns

### Custom Alerts
Configure alerts in `scripts/setup-monitoring.sh`:

```yaml
# High latency alert
alert: HighLatency
expr: llamacpp_request_duration_seconds > 5
for: 2m
labels:
  severity: warning
annotations:
  summary: "High response latency detected"
```

## 🐛 Troubleshooting

### Common Issues

#### 1. **Deployment Timeout**
```bash
# Check pod status
kubectl get pods -n llama-app -o wide

# View pod logs
kubectl logs -n llama-app -l app=llamacpp --tail=100

# Check model download progress
kubectl logs -n llama-app job/model-download-<RUN_NUMBER>
```

#### 2. **Model Download Fails**
```bash
# Check storage
kubectl get pvc -n llama-app

# Verify model file
kubectl exec -it -n llama-app <pod-name> -- ls -la /models/
```

#### 3. **Service Not Accessible**
```bash
# Check service status
kubectl get svc -n llama-app

# Port forward for testing
kubectl port-forward -n llama-app svc/llamacpp-service 8084:8084
```

### Debug Commands
```bash
# Get all resources
kubectl get all -n llama-app

# Describe problematic pod
kubectl describe pod -n llama-app <pod-name>

# View events
kubectl get events -n llama-app --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes
kubectl top pods -n llama-app
```

## 🔒 Security Considerations

### Container Security
- **Non-root user**: Containers run as user ID 1000
- **Read-only filesystem**: Root filesystem is read-only
- **Dropped capabilities**: All unnecessary capabilities removed
- **Resource limits**: CPU and memory limits enforced

### Network Security
- **Network policies**: Restrict inter-pod communication
- **TLS termination**: Use ingress for HTTPS
- **Secret management**: Sensitive data in Kubernetes secrets

### Access Control
```yaml
# Example RBAC configuration
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: llamacpp-operator
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps"]
  verbs: ["get", "list", "watch"]
```

## 📈 Performance Tuning

### Model Optimization
```yaml
# Optimize for your hardware
env:
- name: LLAMACPP_THREADS
  value: "8"           # Match CPU cores
- name: LLAMACPP_GPU_LAYERS  
  value: "32"          # GPU acceleration
- name: LLAMACPP_BATCH_SIZE
  value: "512"         # Batch processing
```

### Kubernetes Optimization
```yaml
# Node affinity for GPU nodes
nodeSelector:
  accelerator: nvidia-tesla-k80

# Pod anti-affinity for distribution
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: llamacpp
      topologyKey: kubernetes.io/hostname
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes and test locally**
4. **Run tests**: `make test`
5. **Commit changes**: `git commit -m 'Add amazing feature'`
6. **Push to branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### Development Workflow
```bash
# Install dev dependencies
make dev-setup

# Run local tests
make test

# Build and test locally
make build-local

# Deploy to test cluster
make deploy-test
```

## 📚 Additional Resources

### Documentation
- [LlamaCPP Documentation](https://github.com/ggerganov/llama.cpp)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/docs/)

### Community
- [GitHub Discussions](../../discussions) - Ask questions and share ideas
- [Issues](../../issues) - Report bugs and request features
- [Wiki](../../wiki) - Additional guides and tutorials

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [LlamaCPP Team](https://github.com/ggerganov/llama.cpp) - For the excellent inference engine
- [Kubernetes Community](https://kubernetes.io/community/) - For the orchestration platform
- [Prometheus & Grafana](https://prometheus.io/) - For monitoring and observability tools

---

## 📞 Support

- **📧 Email**: [your-email@domain.com](mailto:your-email@domain.com)
- **💬 Discord**: [Join our server](https://discord.gg/your-invite)
- **📱 Twitter**: [@yourhandle](https://twitter.com/yourhandle)

---

<div align="center">

**⭐ Star this repo if it helped you!**

[![GitHub stars](https://img.shields.io/github/stars/yourusername/llamacpp-k8s.svg?style=social&label=Star)](https://github.com/yourusername/llamacpp-k8s/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/yourusername/llamacpp-k8s.svg?style=social&label=Fork)](https://github.com/yourusername/llamacpp-k8s/network)

Made with ❤️ by [Your Name](https://github.com/yourusername)

</div>

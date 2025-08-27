#!/bin/bash
# Create KIND cluster configuration
cat <<INNEREOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30083
    hostPort: 8084
    protocol: TCP
  - containerPort: 30090
    hostPort: 9090
    protocol: TCP
  - containerPort: 30030
    hostPort: 3000
    protocol: TCP
INNEREOF
# Create cluster
kind create cluster --name llama-cluster --config kind-config.yaml
# Load local image to KIND (optional for local testing)
# docker build -t llamacpp-server:local .
# kind load docker-image llamacpp-server:local --name llama-cluster
echo "KIND cluster created successfully!"
kubectl cluster-info --context kind-llama-cluster

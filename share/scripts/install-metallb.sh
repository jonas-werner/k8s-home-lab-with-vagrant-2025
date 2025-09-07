#!/bin/bash

# MetalLB Load Balancer Installation Script
# This script installs MetalLB for load balancing services in a bare metal Kubernetes cluster

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "============================================================================"
print_status "Installing MetalLB Load Balancer"
print_status "============================================================================"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please ensure Kubernetes is installed first."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm not found. Please install Helm first."
    exit 1
fi

# Ensure kubectl uses the correct kubeconfig
if [ "$EUID" -eq 0 ]; then
    # Running as root, use admin.conf
    export KUBECONFIG=/etc/kubernetes/admin.conf
else
    # Running as vagrant user, use user kubeconfig
    export KUBECONFIG=/home/vagrant/.kube/config
fi

# Install MetalLB using Helm
print_status "Installing MetalLB using Helm..."

# Add MetalLB Helm repository
helm repo add metallb https://metallb.github.io/metallb
helm repo update

# Install MetalLB
helm install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --version 0.13.12 \
  --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set controller.tolerations[0].operator=Exists \
  --set controller.tolerations[0].effect=NoSchedule

# Wait for MetalLB to be ready
print_status "Waiting for MetalLB to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=metallb -n metallb-system --timeout=300s

# Configure MetalLB with IP range (avoiding VirtualBox DHCP range 192.168.56.101-254)
print_status "Configuring MetalLB IP address pool..."
kubectl apply -f /home/vagrant/share/config/metallb-config.yaml

print_status "MetalLB installation complete!"
print_status "IP range configured: 192.168.56.60-192.168.56.80"
print_status "To test: kubectl apply -f https://k8s.io/examples/service/loadbalancer-example.yaml"
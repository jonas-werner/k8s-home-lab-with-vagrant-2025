#!/bin/bash

# ============================================================================
# Cilium CNI Installation Script
# ============================================================================
# This script installs Cilium CNI for Kubernetes networking
# ============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Installing Cilium CNI..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please ensure Kubernetes is installed first."
    exit 1
fi

# Check if cluster control plane is running
print_status "Checking cluster control plane..."
max_attempts=10
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if kubectl get nodes --no-headers 2>/dev/null | grep -q "control-plane"; then
        print_status "Control plane is running, proceeding with Cilium installation..."
        break
    fi
    print_status "Waiting for control plane to be ready... (attempt $((attempt + 1))/$max_attempts)"
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    print_error "Cluster control plane is not running after $max_attempts attempts. Please check the cluster status."
    exit 1
fi

# Check if Cilium is already installed
if kubectl get pods -n kube-system | grep -q "cilium"; then
    print_status "Cilium is already installed. Skipping installation."
    print_status "Verifying Cilium installation..."
    cilium status
    print_status "Cilium CNI installation completed successfully!"
    exit 0
fi

# Install Cilium CLI if not present
if ! command -v cilium &> /dev/null; then
    print_status "Installing Cilium CLI..."
    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
    sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
    rm cilium-linux-amd64.tar.gz
    sudo chmod +x /usr/local/bin/cilium
fi

# Install Cilium
print_status "Installing Cilium CNI..."
cilium install --version 1.15.5

# Wait for Cilium to be ready
print_status "Waiting for Cilium to be ready..."
cilium status --wait

# Verify installation
print_status "Verifying Cilium installation..."
kubectl get pods -n kube-system -l k8s-app=cilium

print_status "Cilium CNI installation completed successfully!"

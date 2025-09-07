#!/bin/bash

# ============================================================================
# Helm Installation Script
# ============================================================================
# Installs Helm package manager for Kubernetes
# ============================================================================

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

print_header "Installing Helm Package Manager"

# Install Helm
print_status "Downloading and installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
print_status "Verifying Helm installation..."
helm version

# Add some common repositories
print_status "Adding common Helm repositories..."
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

print_status "Helm installation complete!"
print_status "Available commands:"
print_status "  helm list                    # List releases"
print_status "  helm search repo <name>      # Search charts"
print_status "  helm install <name> <chart>  # Install a chart"

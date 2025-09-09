#!/bin/bash

# ============================================================================
# Additional Tools Installation Script
# ============================================================================
# This script installs additional useful tools for Kubernetes management
# ============================================================================

# Don't exit on error for individual tool installations
# set -e

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

print_status "Installing additional tools..."

# Install kubectx and kubens
print_status "Installing kubectx and kubens..."
if ! command -v kubectx &> /dev/null; then
    if git clone https://github.com/ahmetb/kubectx /opt/kubectx; then
        ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
        ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
        chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens
        print_status "kubectx and kubens installed successfully"
    else
        print_warning "Failed to install kubectx and kubens, skipping..."
    fi
fi

# Install kubectl-tree
print_status "Installing kubectl-tree..."
if ! command -v kubectl-tree &> /dev/null; then
    # Get the latest release URL
    LATEST_URL=$(curl -s https://api.github.com/repos/ahmetb/kubectl-tree/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d '"' -f 4)
    if [ -n "$LATEST_URL" ]; then
        if curl -L "$LATEST_URL" | tar -xz -C /usr/local/bin; then
            chmod +x /usr/local/bin/kubectl-tree
            print_status "kubectl-tree installed successfully"
        else
            print_warning "Failed to install kubectl-tree, skipping..."
        fi
    else
        print_warning "Could not find kubectl-tree release, skipping..."
    fi
fi

# Install k9s
print_status "Installing k9s..."
if ! command -v k9s &> /dev/null; then
    if curl -sS https://webinstall.dev/k9s | bash; then
        ln -sf ~/.local/bin/k9s /usr/local/bin/k9s
        print_status "k9s installed successfully"
    else
        print_warning "Failed to install k9s, skipping..."
    fi
fi

# Install kubectl-neat
print_status "Installing kubectl-neat..."
if ! command -v kubectl-neat &> /dev/null; then
    # Get the latest release URL
    LATEST_URL=$(curl -s https://api.github.com/repos/itaysk/kubectl-neat/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d '"' -f 4)
    if [ -n "$LATEST_URL" ]; then
        if curl -L "$LATEST_URL" | tar -xz -C /usr/local/bin; then
            chmod +x /usr/local/bin/kubectl-neat
            print_status "kubectl-neat installed successfully"
        else
            print_warning "Failed to install kubectl-neat, skipping..."
        fi
    else
        print_warning "Could not find kubectl-neat release, skipping..."
    fi
fi

print_status "Additional tools installation completed successfully!"
print_status "Available tools:"
print_status "  - kubectx: Switch between Kubernetes contexts"
print_status "  - kubens: Switch between Kubernetes namespaces"
print_status "  - kubectl-tree: Visualize resource hierarchies"
print_status "  - k9s: Terminal-based Kubernetes dashboard"
print_status "  - kubectl-neat: Remove clutter from kubectl output"

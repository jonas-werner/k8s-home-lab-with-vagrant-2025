#!/bin/bash

# ============================================================================
# NFS CSI Driver Installation Script
# ============================================================================
# This script installs the NFS CSI driver for dynamic storage provisioning
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

print_status "Installing NFS CSI driver..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please ensure Kubernetes is installed first."
    exit 1
fi

# Proceed with NFS CSI installation
print_status "Proceeding with NFS CSI installation..."

# Ensure kubectl uses the correct kubeconfig
if [ "$EUID" -eq 0 ]; then
    # Running as root, use admin.conf
    export KUBECONFIG=/etc/kubernetes/admin.conf
else
    # Running as vagrant user, use user kubeconfig
    export KUBECONFIG=/home/vagrant/.kube/config
fi

# Install NFS client tools on all nodes
print_status "Installing NFS client tools on all nodes..."
for node in $(kubectl get nodes -o name | cut -d'/' -f2); do
    print_status "Installing NFS client on node: $node"
    kubectl debug node/$node -it --image=busybox -- chroot /host bash -c "
        apt-get update && 
        apt-get install -y nfs-common &&
        mkdir -p /mnt/nfs-storage &&
        echo '192.168.56.31:/mnt/nfs-storage/k8s-pvcs /mnt/nfs-storage nfs defaults 0 0' >> /etc/fstab &&
        mount -a
    "
done

# Install NFS CSI driver using Helm
print_status "Installing NFS CSI driver using Helm..."

# Add the NFS CSI driver Helm repository
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

# Install the NFS CSI driver
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --set nfs.server=192.168.56.31 \
  --set nfs.share=/mnt/nfs-storage/k8s-pvcs \
  --set storageClass.create=true \
  --set storageClass.name=nfs-csi \
  --set storageClass.reclaimPolicy=Delete

# Wait for CSI driver to be ready
print_status "Waiting for NFS CSI driver to be ready..."
kubectl wait --for=condition=Available deployment/csi-nfs-controller -n kube-system --timeout=300s

# Apply storage examples
print_status "Applying storage examples..."
kubectl apply -f /home/vagrant/share/config/storage-examples.yaml

# Verify storage classes
print_status "Verifying storage classes..."
kubectl get storageclass

# Verify persistent volumes
print_status "Verifying persistent volumes..."
kubectl get pv

print_status "NFS CSI driver installation completed successfully!"

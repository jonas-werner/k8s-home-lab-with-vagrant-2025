#!/bin/bash

# ============================================================================
# NFS Server Installation Script
# ============================================================================
# This script installs and configures NFS server for shared storage
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

print_status "Installing NFS server..."

# Install NFS server
print_status "Installing NFS packages..."

# Ensure we're using the standard Ubuntu repositories for NFS packages
print_status "Updating package sources for NFS packages..."
cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

apt-get update
apt-get install -y nfs-kernel-server nfs-common

# Prepare NFS storage
print_status "Preparing NFS storage..."
mkdir -p /mnt/nfs-storage

# Create NFS export directories
mkdir -p /mnt/nfs-storage/k8s-pvs
mkdir -p /mnt/nfs-storage/k8s-pvcs
mkdir -p /mnt/nfs-storage/shared-data

# Set proper permissions
chown -R nobody:nogroup /mnt/nfs-storage
chmod -R 755 /mnt/nfs-storage

# Configure NFS exports
print_status "Configuring NFS exports..."
cat > /etc/exports <<EOF
/mnt/nfs-storage/k8s-pvs 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/nfs-storage/k8s-pvcs 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)
/mnt/nfs-storage/shared-data 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)
EOF

# Export the shares
exportfs -a

# Enable and start NFS services
systemctl enable nfs-kernel-server
systemctl start nfs-kernel-server

# Create NFS client installation script for other nodes
print_status "Creating NFS client installation script..."
cat > /home/vagrant/share/scripts/install-nfs-client.sh <<EOF
#!/bin/bash
echo "Installing NFS client tools on all nodes..."
apt-get update
apt-get install -y nfs-common
mkdir -p /mnt/nfs-storage
echo "192.168.56.31:/mnt/nfs-storage/k8s-pvs /mnt/nfs-storage nfs defaults 0 0" >> /etc/fstab
mount -a
EOF

chmod +x /home/vagrant/share/scripts/install-nfs-client.sh

print_status "NFS server installation completed successfully!"
print_status "NFS Server IP: 192.168.56.31"
print_status "NFS Exports:"
exportfs -v

fine#!/bin/bash

# ============================================================================
# Kubernetes Installation Script
# ============================================================================
# This script installs and configures Kubernetes on all nodes
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

print_status "Installing Kubernetes..."

# Update package index
print_status "Updating package index..."
apt-get update

# Install required packages
print_status "Installing required packages..."
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release containerd

# Add Kubernetes repository
print_status "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Update package index again
print_status "Updating package index with Kubernetes repository..."
apt-get update

# Install Kubernetes packages
print_status "Installing Kubernetes packages..."
apt-get install -y kubelet kubeadm kubectl --allow-downgrades

# Pin Kubernetes packages to prevent automatic updates
print_status "Pinning Kubernetes packages..."
apt-mark hold kubelet kubeadm kubectl

# Configure containerd for Kubernetes
print_status "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Configure kernel parameters
print_status "Configuring kernel parameters..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
print_status "Configuring sysctl..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Disable swap
print_status "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Check if we're on the controller node
if [ "$(hostname)" = "k8s-controller-1" ]; then
    print_status "Configuring controller node..."
    
    # Clean up any existing cluster state
    print_status "Cleaning up any existing cluster state..."
    if [ -d "/etc/kubernetes/manifests" ]; then
        rm -rf /etc/kubernetes/manifests/*
    fi
    
    if [ -d "/var/lib/etcd" ]; then
        rm -rf /var/lib/etcd/*
    fi
    
    if [ -d "/var/lib/kubelet" ]; then
        rm -rf /var/lib/kubelet/*
    fi
    
    # Reset kubeadm if it was previously initialized
    if [ -f "/etc/kubernetes/admin.conf" ]; then
        print_status "Resetting kubeadm..."
        kubeadm reset -f
    fi
    
    # Wait for the system to be fully ready
    sleep 30
    
    # Initialize the cluster
    print_status "Initializing Kubernetes cluster..."
    kubeadm init --apiserver-advertise-address=192.168.56.11 \
      --pod-network-cidr=10.244.0.0/16 \
      --control-plane-endpoint=192.168.56.11:6443 | tee /home/vagrant/k8s-init.log
    
    # Generate fresh tokens and commands
    WORKER_TOKEN=$(kubeadm token create --print-join-command)
    
    # Create worker join script
    cat > /home/vagrant/share/scripts/worker-join.sh << EOF
#!/bin/bash
# Worker join command for Kubernetes cluster
# Generated on $(date)

# Install required packages
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Configure kernel parameters
cat <<EOF2 | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF2

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF2 | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF2

sysctl --system

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Join the cluster
$WORKER_TOKEN
EOF
    
    chmod +x /home/vagrant/share/scripts/worker-join.sh
    
    # Configure kubectl for vagrant user
    print_status "Configuring kubectl for vagrant user..."
    mkdir -p /home/vagrant/.kube
    cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    chown -R vagrant:vagrant /home/vagrant/.kube
    
    # Wait for the cluster to be ready
    print_status "Waiting for cluster to be ready..."
    sleep 30
    
    # Check if the cluster is ready
    if [ -f "/home/vagrant/share/scripts/worker-join.sh" ]; then
        print_status "Kubernetes cluster initialized successfully!"
        print_status "Worker join script created at /home/vagrant/share/scripts/worker-join.sh"
        
        # Copy join script to worker nodes
        cp /home/vagrant/share/scripts/worker-join.sh /home/vagrant/worker-join.sh
        chmod +x /home/vagrant/worker-join.sh
    else
        print_error "Failed to create worker join script"
        exit 1
    fi
    
else
    print_status "Configuring worker node..."
    
    # Wait for the join script to be available
    print_status "Waiting for join script from controller..."
    while [ ! -f "/home/vagrant/share/scripts/worker-join.sh" ]; do
        sleep 10
        print_status "Waiting for join script..."
    done
    
    # Execute the join script
    print_status "Joining Kubernetes cluster..."
    bash /home/vagrant/share/scripts/worker-join.sh
fi

print_status "Kubernetes installation completed!"
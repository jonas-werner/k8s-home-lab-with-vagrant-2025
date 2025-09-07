#!/bin/bash
# Worker setup script for Kubernetes cluster

set -e

# Install required packages
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release containerd

# Add Kubernetes repository (only if not already added)
if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
fi

# Update package index again
apt-get update

# Install NFS client and net-tools
apt-get install nfs-common -y
apt-get install net-tools -y


# Install Kubernetes packages
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Configure kernel parameters
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Configure sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Worker setup completed successfully"

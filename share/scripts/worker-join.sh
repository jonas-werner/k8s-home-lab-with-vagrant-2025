#!/bin/bash
# Worker join command for Kubernetes cluster
# Generated on Sat Sep  6 03:38:49 UTC 2025

# Install required packages
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release containerd

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Update package index again
apt-get update

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
kubeadm join 192.168.56.11:6443 --token 94654k.58u01i5zjqp556bt --discovery-token-ca-cert-hash sha256:715be0104129b99b24bbcb05c9cc0bfd645e5706d4e85018d4ec0f647967611a 

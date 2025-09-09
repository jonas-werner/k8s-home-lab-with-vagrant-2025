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
kubeadm join 192.168.56.11:6443 --token e23ig9.36bfy27ov4hsmvw2 --discovery-token-ca-cert-hash sha256:2e6f5dd094fae95b555d330f6407cea65fd20e09a37695f0fe518f7f52ceb2f7 

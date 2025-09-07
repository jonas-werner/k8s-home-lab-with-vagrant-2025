#!/bin/bash
echo "Installing NFS client tools on all nodes..."
apt-get update
apt-get install -y nfs-common
mkdir -p /mnt/nfs-storage
echo "192.168.56.31:/mnt/nfs-storage/k8s-pvs /mnt/nfs-storage nfs defaults 0 0" >> /etc/fstab
mount -a

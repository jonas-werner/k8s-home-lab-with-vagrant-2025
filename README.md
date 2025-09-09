# Kubernetes Home Lab with Vagrant

A complete Kubernetes home lab setup using Vagrant and VirtualBox, designed for learning and experimentation with k8s, storage, networking and service mesh.

## Overview

This project provides a fully automated Kubernetes cluster with:
- Single controller node (k8s-controller-1)
- Configurable worker nodes (default: 2 workers)
- NFS server for shared storage to practice PV and PVC with
- Web-based tutorials and documentation (a work in progress)
- Comprehensive component stack (Cilium, MetalLB, Istio, Helm)

## Prerequisites

- VirtualBox 7.0+
- Vagrant
- 10GB+ RAM available for VMs
- Internet connection for package downloads

## Quick Start

1. Clone the repository:
```bash
git clone https://github.com/jonas-werner/k8s-home-lab-with-vagrant-2025.git
cd k8s-home-lab-with-vagrant-2025
```

2. Configure components (optional):
```bash
# Edit share/config/config.env to enable/disable components
vi share/config/config.env
```

3. Update the VMs to use your private SSH key (optional - vagrant ssh is still available):
```bash
# Edit line 122 of the Vagrantfile to add the location of your public SSH key
vi Vagrantfile
```

4. Deploy the cluster:
```bash
./deploy.sh
```

5. Access the tutorial web interface (only storage included at this point):

These will be expanded over time to include more examples. 

```bash
# Get the load balancer IP
kubectl get svc istio-ingressgateway -n istio-system

# Access tutorials at http://<LB-IP>/practice/

# Example:
vagrant@k8s-controller-1:~$ kubectl get svc istio-ingressgateway -n istio-system
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                                      AGE
istio-ingressgateway   LoadBalancer   10.108.178.153   192.168.56.60   15021:31920/TCP,80:30434/TCP,443:30985/TCP   26h

# In the above case the tutorials can be accessed on http://192.168.56.60/practice/

```

## Deploy Script Commands

The `deploy.sh` script provides several commands for managing your Kubernetes home lab:

### Basic Usage

```bash
# Deploy/update the entire cluster and components
./deploy.sh

# Check current deployment status
./deploy.sh status

# Reset deployment state (allows re-running from scratch)
./deploy.sh reset

# Destroy all VMs and clean up
./deploy.sh destroy
```

### Command Details

#### `./deploy.sh` (default)
- **Purpose**: Deploy or update the entire Kubernetes cluster and components
- **Behavior**: 
  - Creates VMs if they don't exist
  - Installs Kubernetes on controller and joins worker nodes
  - Installs all enabled components (Cilium, MetalLB, Istio, etc.)
  - Deploys the practice web interface
  - Skips already-installed components automatically
- **Use when**: First deployment or when you want to ensure everything is up to date

#### `./deploy.sh status`
- **Purpose**: Check the current status of your deployment
- **Shows**:
  - Configuration table with enabled/disabled components
  - Current cluster status (nodes, pods)
  - Which components are installed vs. missing
- **Use when**: You want to see what's currently running without making changes

#### `./deploy.sh reset`
- **Purpose**: Reset the deployment state to allow fresh installation
- **Behavior**: Removes state files that track installation progress
- **Use when**: You want to force reinstallation of all components

#### `./deploy.sh destroy`
- **Purpose**: Completely destroy all VMs and clean up
- **Behavior**: 
  - Destroys all VMs using `vagrant destroy -f`
  - Removes state files
  - **Warning**: This will delete all your work!
- **Use when**: You want to start completely fresh or free up resources

### Smart Deployment Features

The deploy script includes several smart features:

- **Incremental Updates**: Only installs components that aren't already present
- **Worker Node Management**: Automatically handles multiple worker nodes
- **Component Detection**: Checks if components are already installed before attempting installation
- **Error Recovery**: Provides clear error messages and diagnostic information
- **State Management**: Tracks what's been installed to avoid unnecessary work

### Example Workflow

```bash
# First time setup
./deploy.sh

# Check what's running
./deploy.sh status

# Later, add more components by editing config and re-running
vi share/config/config.env
./deploy.sh

# Check status again
./deploy.sh status

# If something goes wrong, reset and try again
./deploy.sh reset
./deploy.sh
```

## Configuration

### Component Configuration

Edit `share/config/config.env` to enable/disable components:

```bash
# Core Kubernetes Components
INSTALL_KUBERNETES=true
INSTALL_CILIUM=true

# Storage Components
INSTALL_NFS_SERVER=true
INSTALL_NFS_CSI=true

# Networking Components
INSTALL_METALLB=true

# Package Management
INSTALL_HELM=true

# Service Mesh
INSTALL_ISTIO=true

# Additional Tools
INSTALL_ADDITIONAL_TOOLS=true

# Practice Web Interface
INSTALL_PRACTICE_WEB=true
```

### Network Configuration

The lab uses VirtualBox's default network configuration:
- Network: 192.168.56.0/24
- Controller: 192.168.56.11
- Workers: 192.168.56.21, 192.168.56.22, etc.
- NFS Server: 192.168.56.31
- MetalLB DHCP: 192.168.56.60-192.168.56.80

### Node Configuration

Edit `Vagrantfile` to configure the number of nodes:

```ruby
$num_controllers = 1  # Single controller node (will break if changed)
$num_workers = 1      # Configurable number of worker nodes (change as required)
```

### Ubuntu Mirror Configuration

Configure the Ubuntu package mirror in `Vagrantfile`:

```ruby
# Choose your preferred mirror by uncommenting one of the options below:
$ubuntu_mirror = "http://ftp.riken.jp/Linux/ubuntu/"  # Japan Riken (default)
# $ubuntu_mirror = "http://archive.ubuntu.com/ubuntu/"  # Official Ubuntu Archive
# $ubuntu_mirror = "http://mirror.ubuntu.com/ubuntu/"   # Ubuntu Mirror Network
# $ubuntu_mirror = "http://us.archive.ubuntu.com/ubuntu/"  # US Archive
# $ubuntu_mirror = "http://de.archive.ubuntu.com/ubuntu/"  # Germany Archive
# $ubuntu_mirror = "http://gb.archive.ubuntu.com/ubuntu/"  # UK Archive
# $ubuntu_mirror = "http://au.archive.ubuntu.com/ubuntu/"  # Australia Archive
# $ubuntu_mirror = "http://cn.archive.ubuntu.com/ubuntu/"  # China Archive
```

## Architecture

### VM Specifications

- **Controller Node**: 4GB RAM, 2 CPUs
- **Worker Nodes**: 6GB RAM, 3 CPUs each
- **NFS Server**: 2GB RAM, 2 CPUs

### Installed Components

- **Kubernetes**: Control plane and worker nodes
- **Cilium**: eBPF-based CNI for networking
- **MetalLB**: Load balancer for bare metal
- **NFS Server**: Shared storage backend
- **NFS CSI Driver**: Dynamic storage provisioning
- **Helm**: Package manager
- **Istio**: Service mesh with observability
- **Additional Tools**: kubectx, kubens, kubectl-tree
- **Practice Web Interface**: Docsify-based tutorial website

## Web Interface

The lab includes a web-based tutorial system accessible via Istio Gateway:

- **URL**: `http://<load-balancer-ip>/practice/`
- **Content**: Interactive tutorials and documentation
- **Current Modules**: Storage (complete), Network (planned), Security (planned), Monitoring (planned)

### Storage Tutorials

Complete hands-on exercises for:
- Dynamic PVC provisioning (RWX)
- Static PV/PVC binding
- Multi-pod storage sharing
- Troubleshooting storage issues

## Usage Examples

### Access the Cluster

```bash
# SSH to controller
vagrant ssh k8s-controller-1

# kubeconfig is already set for the vagrant user on the controller node, but if you manually want to copy kubeconfig to local machine:
vagrant ssh k8s-controller-1 -c "sudo cat /etc/kubernetes/admin.conf" > kubeconfig
export KUBECONFIG=./kubeconfig
```

### Cluster Operations post deployment

```bash
# Stop all VMs 
vagrant halt

# Start all VMs
vagrant up

# Start specific VM
vagrant up k8s-controller-1

# Destroy cluster
vagrant destroy
```

### Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check storage
kubectl get pv,pvc,storageclass

# Check networking
kubectl get svc --all-namespaces
kubectl get ingress --all-namespaces

# Check Istio
kubectl get pods -n istio-system
```

## File Structure

```
k8s-home-lab-with-vagrant/
├── Vagrantfile                 # VM configuration
├── deploy.sh                   # Component deployment script
├── share/
│   ├── config/
│   │   ├── config.env         # Component configuration
│   │   ├── metallb-config.yaml
│   │   └── nfs-csi-driver.yaml
│   ├── scripts/               # Installation scripts for compoments
│   ├── practice/              # Tutorial content
│   │   ├── storage/           # Storage tutorials (complete)
│   │   ├── network/           # Network tutorials (planned)
│   │   ├── security/          # Security tutorials (planned)
│   │   └── monitoring/        # Monitoring tutorials (planned)
│   └── web-serve/             # Web interface configuration
```

## License

This project is provided as-is for educational purposes.

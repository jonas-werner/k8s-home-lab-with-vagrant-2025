#!/bin/bash

########################################################################################
#  _   ___      _                    _      _         _          _                  
# | |_( _ )___ | |_  ___ _ __  ___  | |__ _| |__   __| |___ _ __| |___ _  _ ___ _ _ 
# | / / _ (_-< | ' \/ _ \ '  \/ -_) | / _` | '_ \ / _` / -_) '_ \ / _ \ || / -_) '_|
# |_\_\___/__/ |_||_\___/_|_|_\___| |_\__,_|_.__/ \__,_\___| .__/_\___/\_, \___|_|  
#                                                          |_|         |__/         
########################################################################################
# Author: Jonas Werner
# Date: 2025-09-07
# Version: 1.0.0
########################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# State file to track deployment progress
STATE_FILE=".deployment-state"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
}

# Function to save deployment state
save_state() {
    echo "$1" > "$STATE_FILE"
}

# Function to get deployment state
get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "none"
    fi
}

# Function to check if VMs are running
check_vms_running() {
    if vagrant status | grep -q "running"; then
        return 0
    else
        return 1
    fi
}

# Function to check if cluster is ready
check_cluster_ready() {
    if vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | grep -q "control-plane"; then
        return 0
    else
        return 1
    fi
}

# Function to check if worker is joined
check_worker_joined() {
    # Check if we have exactly 2 nodes (controller + worker)
    local node_count
    node_count=$(vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -eq 2 ]; then
        # Double-check that we have a worker node (not just controller)
        if vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | grep -q "k8s-worker"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Load configuration from config.env file
if [ -f "share/config/config.env" ]; then
    print_status "Loading configuration from share/config/config.env..."
    source share/config/config.env
else
    print_error "share/config/config.env not found! Please create the configuration file first."
    exit 1
fi

# Function to get status with color
get_status() {
    if [ "$1" = "true" ]; then
        echo -e "${GREEN}YES${NC}"
    else
        echo -e "${RED}NO${NC}"
    fi
}

# Function to create table row
create_row() {
    local component="$1"
    local status="$2"
    local description="$3"
    printf "${BLUE}│${NC} %-35s ${BLUE}│${NC} %-18s ${BLUE}│${NC} %-30s ${BLUE}│${NC}\n" "$component" "$(get_status $status)" "$description"
}

# Display configuration table
print_header "Kubernetes Home Lab Deployment Configuration"
echo
echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC} ${CYAN}Component${NC}                           ${BLUE}│${NC} ${CYAN}Install${NC} ${BLUE}│${NC} ${CYAN}Description${NC}                    ${BLUE}│${NC}"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Core Kubernetes Components${NC}          ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  Kubernetes Control Plane" "$INSTALL_KUBERNETES" "Control plane and worker nodes"
create_row "  Cilium CNI" "$INSTALL_CILIUM" "eBPF-based networking"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Storage Components${NC}                  ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  NFS Server" "$INSTALL_NFS_SERVER" "Shared storage server"
create_row "  NFS CSI Driver" "$INSTALL_NFS_CSI" "Dynamic storage provisioning"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Networking Components${NC}               ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  MetalLB LoadBalancer" "$INSTALL_METALLB" "LoadBalancer for bare metal"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Package Management${NC}                  ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  Helm Package Manager" "$INSTALL_HELM" "Kubernetes package manager"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Service Mesh${NC}                        ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  Istio Service Mesh" "$INSTALL_ISTIO" "Advanced traffic management"
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Additional Tools${NC}                    ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  kubectx, k9s, kubectl-tree, etc." "$INSTALL_ADDITIONAL_TOOLS" "Useful Kubernetes tools"
echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────────────┘${NC}"
echo

# Function to wait for cluster to be ready
wait_for_cluster() {
    print_status "Waiting for Kubernetes control plane to be ready..."
    
    # Wait for control plane to be running (not necessarily Ready - that requires CNI)
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if check_cluster_ready; then
            print_status "Control plane is running! (Nodes will be Ready after CNI installation)"
            return 0
        fi
        print_status "Waiting for control plane to be running... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "Control plane failed to start after $max_attempts attempts"
    return 1
}

# Function to join worker node
join_worker_node() {
    print_status "Joining worker node to cluster..."
    
    # First, install Kubernetes packages on worker node
    print_status "Installing Kubernetes packages on worker node..."
    if ! vagrant ssh k8s-worker-1 -- sudo bash /home/vagrant/share/scripts/worker-setup.sh; then
        print_error "Failed to install Kubernetes packages on worker node"
        return 1
    fi
    
    # Generate fresh join command
    print_status "Generating fresh join command..."
    local join_cmd
    join_cmd=$(vagrant ssh k8s-controller-1 -- kubeadm token create --print-join-command 2>/dev/null)
    
    if [ -z "$join_cmd" ]; then
        print_error "Failed to generate join command"
        return 1
    fi
    
    print_status "Executing join command: $join_cmd"
    
    # Execute join command on worker
    if vagrant ssh k8s-worker-1 -- sudo $join_cmd; then
        print_status "Worker node joined successfully!"
        return 0
    else
        print_error "Failed to join worker node"
        return 1
    fi
}

# Function to install additional components
install_additional_components() {
    print_status "Installing additional components..."
    
    # Package management (install first as it's needed by other components)
    if [ "$INSTALL_HELM" = true ]; then
        print_status "Installing Helm..."
        if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-helm.sh; then
            print_error "Failed to install Helm"
            return 1
        fi
    fi
    
    # Core Kubernetes components (already installed during VM provisioning)
    if [ "$INSTALL_CILIUM" = true ]; then
        print_status "Installing Cilium CNI..."
        if ! vagrant ssh k8s-controller-1 -- bash /home/vagrant/share/scripts/install-cilium.sh; then
            print_error "Failed to install Cilium CNI"
            return 1
        fi
    fi
    
    if [ "$INSTALL_NFS_CSI" = true ]; then
        print_status "Installing NFS CSI Driver..."
        if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-nfs-csi.sh; then
            print_error "Failed to install NFS CSI Driver"
            return 1
        fi
    fi
    
    # Networking components
    if [ "$INSTALL_METALLB" = true ]; then
        print_status "Installing MetalLB..."
        if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-metallb.sh; then
            print_error "Failed to install MetalLB"
            return 1
        fi
    fi
    
    # Service mesh
    if [ "$INSTALL_ISTIO" = true ]; then
        print_status "Installing Istio..."
        if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-istio.sh; then
            print_error "Failed to install Istio"
            return 1
        fi
    fi
    
    # Additional tools
    if [ "$INSTALL_ADDITIONAL_TOOLS" = true ]; then
        print_status "Installing additional tools..."
        if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-additional-tools.sh; then
            print_error "Failed to install additional tools"
            return 1
        fi
    fi
    
    print_status "All additional components installed successfully!"
    return 0
}

# Function to confirm installation
confirm_installation() {
    echo -e "${YELLOW}Press ENTER to continue with the installation or CTRL+C to cancel...${NC}"
    read -r
}

# Function to show current status
show_status() {
    print_status "Current deployment status:"
    echo
    if [ "$INSTALL_KUBERNETES" = true ]; then
        vagrant ssh k8s-controller-1 -- kubectl get nodes 2>/dev/null || echo "Cluster not ready"
        echo
        vagrant ssh k8s-controller-1 -- kubectl get pods -A 2>/dev/null || echo "No pods found"
    fi
}

# Main deployment process
main() {
    print_header "Kubernetes Home Lab Deployment"
    
    # Check current state
    current_state=$(get_state)
    print_status "Current deployment state: $current_state"
    
    # Confirm installation
    confirm_installation
    
    # Step 1: Deploy VMs if not already running
    if [ "$current_state" = "none" ] || [ "$current_state" = "vms_failed" ]; then
        print_status "Step 1: Deploying VMs and installing components..."
        if vagrant up; then
            save_state "vms_ready"
            print_status "VMs deployed successfully!"
        else
            save_state "vms_failed"
            print_error "Failed to deploy VMs"
            exit 1
        fi
    else
        print_status "Step 1: VMs already deployed, skipping..."
    fi
    
    # Step 2: Wait for cluster to be ready
    if [ "$INSTALL_KUBERNETES" = true ]; then
        if [ "$current_state" = "vms_ready" ] || [ "$current_state" = "cluster_failed" ]; then
            print_status "Step 2: Waiting for cluster to be ready..."
            if wait_for_cluster; then
                save_state "cluster_ready"
                print_status "Cluster is ready!"
            else
                save_state "cluster_failed"
                print_error "Failed to start Kubernetes cluster"
                exit 1
            fi
        else
            print_status "Step 2: Cluster already ready, skipping..."
        fi
        
        # Step 2.5: Join worker node if not already joined
        if [ "$current_state" = "cluster_ready" ] || [ "$current_state" = "worker_failed" ] || [ "$current_state" = "none" ]; then
            print_status "Checking if worker node is joined..."
            if ! check_worker_joined; then
                print_status "Step 2.5: Joining worker node..."
                if join_worker_node; then
                    save_state "worker_joined"
                    print_status "Worker node joined successfully!"
                else
                    save_state "worker_failed"
                    print_error "Failed to join worker node"
                    exit 1
                fi
            else
                print_status "Step 2.5: Worker node already joined, skipping..."
                save_state "worker_joined"
            fi
        else
            print_status "Step 2.5: Worker node already joined, skipping..."
        fi
    fi
    
    # Step 3: Install additional components
    if [ "$current_state" = "worker_joined" ] || [ "$current_state" = "components_failed" ]; then
        print_status "Step 3: Installing additional components..."
        if install_additional_components; then
            save_state "components_ready"
            print_status "All components installed successfully!"
        else
            save_state "components_failed"
            print_error "Failed to install some components"
            print_warning "You can re-run this script to retry failed components"
            exit 1
        fi
    else
        print_status "Step 3: Components already installed, skipping..."
    fi
    
    # Step 4: Display final status
    print_status "Step 4: Deployment complete! Displaying cluster status..."
    echo
    show_status
    
    print_status "Deployment completed successfully!"
    print_status "You can now SSH into the controller: vagrant ssh k8s-controller-1"
    print_status "Or SSH into the NFS server: vagrant ssh nfs-server"
    
    # Clean up state file
    rm -f "$STATE_FILE"
}

# Handle command line arguments
case "${1:-}" in
    "status")
        show_status
        exit 0
        ;;
    "reset")
        print_status "Resetting deployment state..."
        rm -f "$STATE_FILE"
        print_status "State reset. You can now run ./deploy.sh again."
        exit 0
        ;;
    "destroy")
        print_status "Destroying all VMs..."
        vagrant destroy -f
        rm -f "$STATE_FILE"
        print_status "All VMs destroyed."
        exit 0
        ;;
    *)
        # Run main function
        main "$@"
        ;;
esac
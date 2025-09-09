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

# Configuration - should match Vagrantfile
num_workers=2  # Number of worker nodes

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;94m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


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

# Function to check if a specific component is installed
check_component_installed() {
    local component=$1
    case $component in
        "cilium")
            vagrant ssh k8s-controller-1 -- "kubectl get pods -n kube-system | grep -q cilium" 2>/dev/null
            ;;
        "nfs-csi")
            vagrant ssh k8s-controller-1 -- "kubectl get pods -n kube-system | grep -q csi-nfs" 2>/dev/null
            ;;
        "metallb")
            vagrant ssh k8s-controller-1 -- "kubectl get pods -n metallb-system" 2>/dev/null | grep -q "metallb"
            ;;
        "istio")
            vagrant ssh k8s-controller-1 -- "kubectl get pods -n istio-system" 2>/dev/null | grep -q "istio"
            ;;
        "helm")
            vagrant ssh k8s-controller-1 -- "which helm" 2>/dev/null >/dev/null
            ;;
        "additional-tools")
            vagrant ssh k8s-controller-1 -- "kubectx --help >/dev/null 2>&1 && kubens --help >/dev/null 2>&1 && kubectl-tree --help >/dev/null 2>&1" 2>/dev/null
            ;;
        "practice-web")
            vagrant ssh k8s-controller-1 -- "kubectl get deployment practice-web -n default" 2>/dev/null | grep -q "practice-web"
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to check if components are installed
check_components_installed() {
    if ! check_cluster_ready; then
        return 1
    fi
    
    # Check each enabled component individually
    local missing_components=()
    
    if [ "$INSTALL_CILIUM" = true ]; then
        if ! check_component_installed "cilium"; then
            missing_components+=("Cilium")
        fi
    fi
    
    if [ "$INSTALL_NFS_CSI" = true ]; then
        if ! check_component_installed "nfs-csi"; then
            missing_components+=("NFS CSI")
        fi
    fi
    
    if [ "$INSTALL_METALLB" = true ]; then
        if ! check_component_installed "metallb"; then
            missing_components+=("MetalLB")
        fi
    fi
    
    if [ "$INSTALL_ISTIO" = true ]; then
        if ! check_component_installed "istio"; then
            missing_components+=("Istio")
        fi
    fi
    
    if [ "$INSTALL_HELM" = true ]; then
        if ! check_component_installed "helm"; then
            missing_components+=("Helm")
        fi
    fi
    
    if [ "$INSTALL_ADDITIONAL_TOOLS" = true ]; then
        if ! check_component_installed "additional-tools"; then
            missing_components+=("Additional Tools")
        fi
    fi
    
    if [ "$INSTALL_PRACTICE_WEB" = true ]; then
        if ! check_component_installed "practice-web"; then
            missing_components+=("Practice Web")
        fi
    fi
    
    if [ ${#missing_components[@]} -eq 0 ]; then
        return 0  # All components installed
    else
        print_status "Missing components: ${missing_components[*]}"
        return 1  # Some components missing
    fi
}

# Function to check if Kubernetes is installed on controller
check_kubernetes_installed() {
    if check_vms_running && vagrant ssh k8s-controller-1 -- "which kubectl" 2>/dev/null >/dev/null; then
        return 0
    else
        return 1
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
    # Check if we have the expected number of nodes (controller + workers)
    local expected_nodes=$((1 + $num_workers))  # 1 controller + N workers
    local node_count
    node_count=$(vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -eq $expected_nodes ]; then
        # Double-check that we have worker nodes (not just controller)
        if vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | grep -q "k8s-worker"; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Function to check which specific workers are already joined
get_joined_workers() {
    vagrant ssh k8s-controller-1 -- kubectl get nodes --no-headers 2>/dev/null | grep "k8s-worker" | awk '{print $1}' | sed 's/k8s-worker-//' || true
}

# Function to check if a specific worker is joined
is_worker_joined() {
    local worker_num=$1
    local joined_workers
    joined_workers=$(get_joined_workers)
    echo "$joined_workers" | grep -q "^$worker_num$"
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
echo -e "${BLUE}├────────────────────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${BLUE}│${NC} ${YELLOW}Practice Interface${NC}                  ${BLUE}│${NC}         ${BLUE}│${NC}                                ${BLUE}│${NC}"
create_row "  Practice Web Interface" "$INSTALL_PRACTICE_WEB" "Docsify-based practice website"
echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────────────┘${NC}"
echo

# Function to check cluster readiness (no waiting)
check_cluster_readiness() {
    print_status "Checking Kubernetes control plane status..."
    
    if check_cluster_ready; then
        print_status "Control plane is running! (Nodes will be Ready after CNI installation)"
        return 0
    else
        print_error "Control plane is not ready"
        return 1
    fi
}

# Function to join worker nodes
join_worker_node() {
    print_status "Joining worker nodes to cluster..."
    
    # Check which workers are already joined
    local joined_workers
    joined_workers=$(get_joined_workers)
    print_status "Already joined workers: $([ -n "$joined_workers" ] && echo "$joined_workers" | tr '\n' ' ' || echo "none")"
    
    # Install Kubernetes packages and join only workers that aren't already joined
    for i in $(seq 1 $num_workers); do
        if is_worker_joined $i; then
            print_status "Worker node $i is already joined, skipping..."
            continue
        fi
        
        print_status "Installing Kubernetes packages on worker node $i..."
        if ! vagrant ssh k8s-worker-$i -- sudo bash /home/vagrant/share/scripts/worker-setup.sh; then
            print_error "Failed to install Kubernetes packages on worker node $i"
            return 1
        fi
    done
    
    # Generate fresh join command
    print_status "Generating fresh join command..."
    
    # First, check if the cluster is ready
    print_status "Checking cluster status..."
    if ! vagrant ssh k8s-controller-1 -- kubectl get nodes 2>/dev/null | grep -q "k8s-controller-1"; then
        print_error "Cluster is not ready. Controller node not found in cluster."
        return 1
    fi
    
    # Cluster should be ready at this point
    print_status "Cluster is ready for worker joins..."
    
    # Generate join command
    local join_cmd
    local token_output
    local ca_cert_hash
    
    print_status "Creating join token..."
    token_output=$(vagrant ssh k8s-controller-1 -- kubeadm token create --ttl=0 --print-join-command 2>&1)
    
    if [ $? -eq 0 ] && [ -n "$token_output" ]; then
        join_cmd="$token_output"
        print_status "Join command generated successfully"
    else
        print_error "Failed to generate join command. Error: $token_output"
        print_status "Trying alternative method..."
        
        # Alternative: Get token and CA cert hash separately
        local token
        token=$(vagrant ssh k8s-controller-1 -- kubeadm token list -o jsonpath='{.items[0].token}' 2>/dev/null)
        
        if [ -z "$token" ]; then
            print_status "Creating new token..."
            token=$(vagrant ssh k8s-controller-1 -- kubeadm token create --ttl=0 2>/dev/null)
        fi
        
        if [ -z "$token" ]; then
            print_error "Failed to create or retrieve token"
            return 1
        fi
        
        # Get CA cert hash
        ca_cert_hash=$(vagrant ssh k8s-controller-1 -- openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
        
        if [ -z "$ca_cert_hash" ]; then
            print_error "Failed to get CA cert hash"
            return 1
        fi
        
        join_cmd="kubeadm join 192.168.56.11:6443 --token $token --discovery-token-ca-cert-hash sha256:$ca_cert_hash"
        print_status "Join command constructed manually"
    fi
    
    if [ -z "$join_cmd" ]; then
        print_error "Failed to generate join command"
        return 1
    fi
    
    print_status "Updating worker-join.sh script with fresh join command..."
    
    # Update the worker-join.sh script with the fresh join command
    vagrant ssh k8s-controller-1 -- bash -c "cat > /home/vagrant/share/scripts/worker-join.sh << 'EOF'
#!/bin/bash
# Worker join command for Kubernetes cluster
# Generated on \$(date)

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
sed -i '/ swap / s/^\\(.*\\)$/#\\1/g' /etc/fstab

# Join the cluster
$join_cmd
EOF"
    
    # Make the script executable
    vagrant ssh k8s-controller-1 -- chmod +x /home/vagrant/share/scripts/worker-join.sh
    
    print_status "Executing join command: $join_cmd"
    
    # Execute join command only on workers that aren't already joined
    local joined_any=false
    for i in $(seq 1 $num_workers); do
        if is_worker_joined $i; then
            print_status "Worker node $i is already joined, skipping join command..."
            continue
        fi
        
        print_status "Attempting to join worker node $i..."
        local join_output
        join_output=$(vagrant ssh k8s-worker-$i -- sudo $join_cmd 2>&1)
        local join_exit_code=$?
        
        if [ $join_exit_code -eq 0 ]; then
            print_status "Worker node $i joined successfully!"
            print_status "Join output: $join_output"
            joined_any=true
        else
            print_error "Failed to join worker node $i (exit code: $join_exit_code)"
            print_error "Join output: $join_output"
            
            # Get more diagnostic information
            print_status "Gathering diagnostic information..."
            print_status "Controller node status:"
            vagrant ssh k8s-controller-1 -- kubectl get nodes 2>/dev/null || echo "Failed to get nodes"
            
            print_status "Controller pods status:"
            vagrant ssh k8s-controller-1 -- kubectl get pods -n kube-system 2>/dev/null || echo "Failed to get pods"
            
            return 1
        fi
    done
    
    if [ "$joined_any" = true ]; then
        print_status "New worker nodes joined successfully!"
    else
        print_status "All worker nodes were already joined!"
    fi
    return 0
}

# Install Kubernetes on controller node
install_kubernetes_controller() {
    print_status "Installing Kubernetes on controller node..."
    
    # Run the Kubernetes installation script on the controller
    if vagrant ssh k8s-controller-1 -- "sudo bash /home/vagrant/share/scripts/install-kubernetes.sh"; then
        print_status "Kubernetes installation completed on controller"
        return 0
    else
        print_error "Failed to install Kubernetes on controller"
        return 1
    fi
}

# Install additional components
install_additional_components() {
    print_status "Installing additional components..."
    
    local installed_any=false
    
    # Package management (install first as it's needed by other components)
    if [ "$INSTALL_HELM" = true ]; then
        if check_component_installed "helm"; then
            print_status "Helm already installed, skipping..."
        else
            print_status "Installing Helm..."
            if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-helm.sh; then
                print_error "Failed to install Helm"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    # Core Kubernetes components 
    if [ "$INSTALL_CILIUM" = true ]; then
        if check_component_installed "cilium"; then
            print_status "Cilium already installed, skipping..."
        else
            print_status "Installing Cilium CNI..."
            if ! vagrant ssh k8s-controller-1 -- bash /home/vagrant/share/scripts/install-cilium.sh; then
                print_error "Failed to install Cilium CNI"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    if [ "$INSTALL_NFS_CSI" = true ]; then
        if check_component_installed "nfs-csi"; then
            print_status "NFS CSI Driver already installed, skipping..."
        else
            print_status "Installing NFS CSI Driver..."
            if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-nfs-csi.sh; then
                print_error "Failed to install NFS CSI Driver"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    # Networking components
    if [ "$INSTALL_METALLB" = true ]; then
        if check_component_installed "metallb"; then
            print_status "MetalLB already installed, skipping..."
        else
            print_status "Installing MetalLB..."
            if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-metallb.sh; then
                print_error "Failed to install MetalLB"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    # Service mesh
    if [ "$INSTALL_ISTIO" = true ]; then
        if check_component_installed "istio"; then
            print_status "Istio already installed, skipping..."
        else
            print_status "Installing Istio..."
            if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-istio.sh; then
                print_error "Failed to install Istio"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    # Additional tools
    if [ "$INSTALL_ADDITIONAL_TOOLS" = true ]; then
        if check_component_installed "additional-tools"; then
            print_status "Additional tools already installed, skipping..."
        else
            print_status "Installing additional tools..."
            if ! vagrant ssh k8s-controller-1 -- sudo bash /home/vagrant/share/scripts/install-additional-tools.sh; then
                print_error "Failed to install additional tools"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    # Practice web interface
    if [ "$INSTALL_PRACTICE_WEB" = true ]; then
        if check_component_installed "practice-web"; then
            print_status "Practice web already installed, skipping..."
        else
            print_status "Installing practice web interface..."
            if ! vagrant ssh k8s-controller-1 -- "cd /home/vagrant/share/web-serve && for i in *.yaml; do kubectl create -f \$i; done"; then
                print_error "Failed to install practice web interface"
                return 1
            fi
            installed_any=true
        fi
    fi
    
    if [ "$installed_any" = true ]; then
        print_status "New components installed successfully!"
    else
        print_status "All components were already installed!"
    fi
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
    
    # Check current system state
    print_status "Checking current system state..."
    if check_vms_running; then
        print_status "VMs are running"
        if check_kubernetes_installed; then
            print_status "Kubernetes is installed on controller"
            if check_cluster_ready; then
                print_status "Kubernetes cluster is ready"
                if check_worker_joined; then
                    print_status "Worker nodes are joined"
                    if check_components_installed; then
                        print_status "All components are installed"
                    else
                        print_status "Some components are missing"
                    fi
                else
                    print_status "Worker nodes are not joined"
                fi
            else
                print_status "Kubernetes cluster is not ready"
            fi
        else
            print_status "Kubernetes is not installed on controller"
        fi
    else
        print_status "VMs are not running"
    fi
    
    # Confirm installation
    confirm_installation
    
    # Step 1: Deploy VMs if not already running
    if ! check_vms_running; then
        print_status "Step 1: Deploying VMs and installing components..."
        if vagrant up; then
            print_status "VMs deployed successfully!"
        else
            print_error "Failed to deploy VMs"
            exit 1
        fi
    else
        print_status "Step 1: VMs already deployed, skipping..."
    fi
    
    # Step 2: Install Kubernetes on controller
    if [ "$INSTALL_KUBERNETES" = true ]; then
        if ! check_kubernetes_installed; then
            print_status "Step 2: Installing Kubernetes on controller node..."
            if install_kubernetes_controller; then
                print_status "Kubernetes installed successfully on controller!"
            else
                print_error "Failed to install Kubernetes on controller"
                exit 1
            fi
        else
            print_status "Step 2: Kubernetes already installed on controller, skipping..."
        fi
    fi
    
    # Step 3: Check cluster readiness
    if [ "$INSTALL_KUBERNETES" = true ]; then
        if ! check_cluster_ready; then
            print_status "Step 3: Checking cluster readiness..."
            if check_cluster_readiness; then
                print_status "Cluster is ready!"
            else
                print_error "Failed to start Kubernetes cluster"
                exit 1
            fi
        else
            print_status "Step 3: Cluster already ready, skipping..."
        fi
        
        # Step 4: Join worker nodes if not already joined
        if ! check_worker_joined; then
            print_status "Step 4: Joining worker nodes..."
            if join_worker_node; then
                print_status "Worker nodes joined successfully!"
            else
                print_error "Failed to join worker nodes"
                exit 1
            fi
        else
            print_status "Step 4: Worker nodes already joined, skipping..."
        fi
    fi
    
    # Step 5: Install additional components
    if ! check_components_installed; then
        print_status "Step 5: Installing additional components..."
        if install_additional_components; then
            print_status "All components installed successfully!"
        else
            print_error "Failed to install some components"
            print_warning "You can re-run this script to retry failed components"
            exit 1
        fi
    else
        print_status "Step 5: Components already installed, skipping..."
    fi
    
    # Step 6: Display final status
    print_status "Step 6: Deployment complete! Displaying cluster status..."
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
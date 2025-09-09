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


Vagrant.configure("2") do |config|

  # Sync time with the local host
  config.vm.provider 'virtualbox' do |vb|
   vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
  end

  # Load configuration from config.env
  config_file = File.join(File.dirname(__FILE__), 'share', 'config', 'config.env')
  if File.exist?(config_file)
    config_content = File.read(config_file)
    num_workers_match = config_content.match(/NUM_WORKERS=(\d+)/)
    $num_workers = num_workers_match ? num_workers_match[1].to_i : 1
  else
    $num_workers = 1  # Default fallback
  end
  
  # Configuration for different node types
  $num_controllers = 1  # Single controller node (will break if changed)
  $total_nodes = $num_controllers + $num_workers
  
  # Ubuntu mirror configuration
  # Choose your preferred mirror by uncommenting one of the options below:
  $ubuntu_mirror = "http://ftp.riken.jp/Linux/ubuntu/"  # Japan Riken (default)
  # $ubuntu_mirror = "http://archive.ubuntu.com/ubuntu/"  # Official Ubuntu Archive
  # $ubuntu_mirror = "http://mirror.ubuntu.com/ubuntu/"   # Ubuntu Mirror Network
  # $ubuntu_mirror = "http://us.archive.ubuntu.com/ubuntu/"  # US Archive
  # $ubuntu_mirror = "http://de.archive.ubuntu.com/ubuntu/"  # Germany Archive
  # $ubuntu_mirror = "http://gb.archive.ubuntu.com/ubuntu/"  # UK Archive
  # $ubuntu_mirror = "http://au.archive.ubuntu.com/ubuntu/"  # Australia Archive
  # $ubuntu_mirror = "http://cn.archive.ubuntu.com/ubuntu/"  # China Archive
  
  # Network configuration - using VirtualBox default 192.168.56.x/24 
  $network_base = "192.168.56"
  $controller_ip = "192.168.56.11"
  $worker_ip_start = 20
  $nfs_server_ip = "192.168.56.31"

  # Controller node (single)
  config.vm.define "k8s-controller-1" do |node|
    node.vm.box = "ubuntu/jammy64"
    node.vm.hostname = "k8s-controller-1"
    ip = $controller_ip  # Fixed IP for controller
    node.vm.network "private_network", ip: ip
    # Share folder with scripts and configs
    node.vm.synced_folder "./share", "/home/vagrant/share"

    node.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"  # 4GB for controller node
      vb.cpus = 2
      vb.name = "k8s-controller-1"
    end

    node.vm.provision "shell" do |s|
      s.inline = <<-SHELL

        echo "-------------------------------------------------------------------------- Update hosts file"
# Dynamic hosts file generation based on configurable workers
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 k8s-controller-1

# Controller node
#{$controller_ip} k8s-controller-1

# Worker nodes
EOF

# Add worker nodes dynamically
for i in $(seq 1 #{$num_workers}); do
  echo "#{$network_base}.$((#{$worker_ip_start}+i)) k8s-worker-$i" >> /etc/hosts
done

# Add NFS server
echo "#{$nfs_server_ip} nfs-server" >> /etc/hosts

cat /etc/hosts

echo "-------------------------------------------------------------------------- Configure apt caching and mirrors"

# Configure apt to use configurable mirror
cat > /etc/apt/sources.list <<EOF
deb #{$ubuntu_mirror} jammy main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-updates main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

echo "-------------------------------------------------------------------------- Update DNS settings"
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo "-------------------------------------------------------------------------- Disable swap"
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo "-------------------------------------------------------------------------- Load kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "-------------------------------------------------------------------------- Set kernel parameters"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "-------------------------------------------------------------------------- Install SSH keys"
# Update with your own public key plz :)
mkdir -p /home/vagrant/.ssh
wget -qO- https://raw.githubusercontent.com/jonas-werner/pubkeys/master/nopass.pub >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

echo "-------------------------------------------------------------------------- Basic OS setup complete"
echo "Kubernetes installation will be done during deployment"

      SHELL
    end
  end

  # Worker nodes (configurable number)
  (1..$num_workers).each do |i|
    config.vm.define "k8s-worker-#{i}" do |node|
      node.vm.box = "ubuntu/jammy64"
      node.vm.hostname = "k8s-worker-#{i}"
      ip = "#{$network_base}.#{$worker_ip_start + i}"  # 192.168.56.21, 192.168.56.22, etc.
      node.vm.network "private_network", ip: ip
      # Share folder with scripts and configs
      node.vm.synced_folder "./share", "/home/vagrant/share"

      node.vm.provider "virtualbox" do |vb|
        vb.memory = "6144"  # 6GB for worker nodes
        vb.cpus = 3
        vb.name = "k8s-worker-#{i}"
      end

      node.vm.provision "shell" do |s|
        s.inline = <<-SHELL

          echo "-------------------------------------------------------------------------- Update hosts file"

# Dynamic hosts file generation based on configurable workers
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 k8s-worker-#{i}

# Controller node
#{$controller_ip} k8s-controller-1

# Worker nodes
EOF

# Add worker nodes dynamically
for w in $(seq 1 #{$num_workers}); do
  echo "#{$network_base}.$((#{$worker_ip_start}+w)) k8s-worker-$w" >> /etc/hosts
done

# Add NFS server
echo "#{$nfs_server_ip} nfs-server" >> /etc/hosts

cat /etc/hosts

echo "-------------------------------------------------------------------------- Configure apt mirrors"

# Configure apt to use configurable mirror
cat > /etc/apt/sources.list <<EOF
deb #{$ubuntu_mirror} jammy main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-updates main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

echo "-------------------------------------------------------------------------- Update DNS settings"
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo "-------------------------------------------------------------------------- Disable swap"
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo "-------------------------------------------------------------------------- Load kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo "-------------------------------------------------------------------------- Set kernel parameters"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "-------------------------------------------------------------------------- Install SSH keys"
mkdir -p /home/vagrant/.ssh
wget -qO- https://raw.githubusercontent.com/jonas-werner/pubkeys/master/nopass.pub >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

echo "-------------------------------------------------------------------------- Basic OS setup complete"
echo "VM is ready for component installation via deploy.sh"

        SHELL
      end
    end
  end

  # NFS Server VM for shared storage
  config.vm.define "nfs-server" do |node|
    node.vm.box = "ubuntu/jammy64"
    node.vm.hostname = "nfs-server"
    node.vm.network "private_network", ip: $nfs_server_ip
    # Share folder with scripts and configs
    node.vm.synced_folder "./share", "/home/vagrant/share"

    node.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"  # 2GB for NFS server
      vb.cpus = 2
      vb.name = "nfs-server"
    end
    

    node.vm.provision "shell" do |s|
      s.inline = <<-SHELL

        echo "-------------------------------------------------------------------------- Update hosts file"
        cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 nfs-server

# Controller node
#{$controller_ip} k8s-controller-1

# Worker nodes
EOF

# Add worker nodes dynamically
for w in $(seq 1 #{$num_workers}); do
  echo "#{$network_base}.$((#{$worker_ip_start}+w)) k8s-worker-$w" >> /etc/hosts
done

# Add NFS server
echo "#{$nfs_server_ip} nfs-server" >> /etc/hosts

cat /etc/hosts

echo "-------------------------------------------------------------------------- Configure apt caching and mirrors"

# Configure apt to use configurable mirror
cat > /etc/apt/sources.list <<EOF
deb #{$ubuntu_mirror} jammy main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-updates main restricted universe multiverse
deb #{$ubuntu_mirror} jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

echo "-------------------------------------------------------------------------- Update DNS settings"
echo "nameserver 8.8.8.8">/etc/resolv.conf
cat /etc/resolv.conf

echo "-------------------------------------------------------------------------- Install SSH keys"
mkdir -p /home/vagrant/.ssh
wget -qO- https://raw.githubusercontent.com/jonas-werner/pubkeys/master/nopass.pub >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

echo "-------------------------------------------------------------------------- Run NFS installation"
# Run NFS installation on server
sudo bash /home/vagrant/share/scripts/install-nfs.sh

echo "-------------------------------------------------------------------------- Basic OS setup complete"
echo "NFS installation completed"

      SHELL
    end
  end

end

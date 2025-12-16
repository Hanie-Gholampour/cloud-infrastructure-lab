# Set the default provider (virtualbox, vmware_desktop, libvirt)
provider = ENV['VAGRANT_DEFAULT_PROVIDER'] || 'vmware_desktop'
# Set the number of worker nodes
NUM_TARGET=2
# Set default RAM and CPU values (worker nodes)
RAM_SIZE=1024
CPU_COUNT=2
# Set the default RAM and CPU values (control node)
CONTROL_RAM_SIZE=1024
CONTROL_CPU_COUNT=1
# if exists, upload this public key to the VMs (Windows path example)
KEY_FILE_PATH = "C:\\users\\enriquez\\.ssh\\id_rsa.pub"
# Set the network configuration (prefixes)
WORKLOAD_NET = "192.168.255"
STORAGE_NET  = "10.10.255"
# Domain name
DOMAIN_NAME = "vcc.local"
# Set the box name and version
BOX = "enricorusso/VCCubuntu"
BOX_VERSION = "24.04.3"

unless ['vmware_desktop', 'virtualbox', 'libvirt'].include?(provider)
  raise "This Vagrantfile is not compatible with the '#{provider}' provider. Please use 'vmware_desktop', 'virtualbox', or 'libvirt'."
end

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.box_version = BOX_VERSION

  config.vm.hostname = "default"
  config.vm.synced_folder ".", "/vagrant" # , disabled: true

  case provider
  when 'vmware_desktop'
    config.vm.provider "vmware_desktop" do |vmw|
      vmw.gui = true
      vmw.memory = RAM_SIZE
      vmw.cpus = CPU_COUNT
    end

  when 'virtualbox'
    config.vm.provider "virtualbox" do |vb|
      vb.gui = true
      vb.memory = RAM_SIZE
      vb.cpus = CPU_COUNT
    end

  when 'libvirt'
    config.vm.provider "libvirt" do |lv|
      lv.memory = RAM_SIZE
      lv.cpus = CPU_COUNT
    end
  end

  (1..NUM_TARGET).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.hostname = "node#{i}"

      if provider == 'vmware_desktop'
        node.vm.network "private_network", ip: "#{WORKLOAD_NET}.1#{i}", mac: "DEADBEEF000#{i}", vmware_network: "VMnet2"
        node.vm.network "private_network", ip: "#{STORAGE_NET}.1#{i}",  mac: "CAFEBABE000#{i}", vmware_network: "VMnet3"
      else
        node.vm.network "private_network", ip: "#{WORKLOAD_NET}.1#{i}", mac: "DEADBEEF000#{i}"
        node.vm.network "private_network", ip: "#{STORAGE_NET}.1#{i}",  mac: "CAFEBABE000#{i}"
      end

      if File.exist?(KEY_FILE_PATH)
        node.vm.provision :file, :source => "#{KEY_FILE_PATH}", :destination => "/tmp/id.pub"
        node.vm.provision :shell, :inline => "cat /tmp/id.pub >> ~vagrant/.ssh/authorized_keys", :privileged => false
      end

      (1..NUM_TARGET).each do |i|
        node.vm.provision :shell, :inline => "grep #{WORKLOAD_NET}.1#{i} /etc/hosts || echo '#{WORKLOAD_NET}.1#{i} node#{i}.#{DOMAIN_NAME} node#{i}' >> /etc/hosts"
        node.vm.provision :shell, :inline => "grep  registry.#{DOMAIN_NAME} /etc/hosts || echo '127.0.0.1  registry.#{DOMAIN_NAME} registry' >> /etc/hosts"
        node.vm.provision :shell, :inline => "apt-get update; apt-get -y install rsync ntpdate"
        node.vm.provision :shell, :inline => "timedatectl set-ntp true"
      end

      node.vm.provision :shell, :inline => "grep #{STORAGE_NET}.10 /etc/hosts || echo '#{STORAGE_NET}.10 storage.#{DOMAIN_NAME} storage' >> /etc/hosts"
      node.vm.provision :shell, :inline => "grep  www.#{DOMAIN_NAME} /etc/hosts || echo '192.168.255.100  www.#{DOMAIN_NAME} auth.#{DOMAIN_NAME} git.#{DOMAIN_NAME} mon.#{DOMAIN_NAME}' >> /etc/hosts"
      node.vm.provision :shell, :inline => "rm -f /etc/apt/apt.conf.d/20auto-upgrades"
    end
  end

  config.vm.define "control" do |control|
    control.vm.hostname = "controlnode"

    if provider == 'vmware_desktop'
      control.vm.network "private_network", ip: "#{WORKLOAD_NET}.10", mac: "DEADBEEF000C", vmware_network: "VMnet2"
      control.vm.network "private_network", ip: "#{STORAGE_NET}.10",  mac: "CAFEBABE000C", vmware_network: "VMnet3"
    else
      control.vm.network "private_network", ip: "#{WORKLOAD_NET}.10", mac: "DEADBEEF000C"
      control.vm.network "private_network", ip: "#{STORAGE_NET}.10",  mac: "CAFEBABE000C"
    end

    if File.exist?(KEY_FILE_PATH)
      control.vm.provision :file, :source => "#{KEY_FILE_PATH}", :destination => "/tmp/id.pub"
      control.vm.provision :shell, :inline => "cat /tmp/id.pub >> ~vagrant/.ssh/authorized_keys", :privileged => false
    end

    control.vm.provision :shell, :inline => "apt-get update; apt-get -y install python3.12-venv sshpass make ntpdate"
    control.vm.provision :shell, :inline => "test -f /home/vagrant/.ssh/id_rsa || ssh-keygen -f /home/vagrant/.ssh/id_rsa -q -P \"\"", :privileged => false
    control.vm.provision :shell, :inline => "grep #{WORKLOAD_NET}.10 /etc/hosts || echo '#{WORKLOAD_NET}.10 controlnode.#{DOMAIN_NAME} controlnode' >> /etc/hosts"
    control.vm.provision :shell, :inline => "grep #{STORAGE_NET}.10 /etc/hosts || echo '#{STORAGE_NET}.10 storage.#{DOMAIN_NAME} storage' >> /etc/hosts"
    control.vm.provision :shell, :inline => "grep  registry.#{DOMAIN_NAME} /etc/hosts || echo '127.0.0.1  registry.#{DOMAIN_NAME} registry' >> /etc/hosts"
    control.vm.provision :shell, :inline => "grep  www.#{DOMAIN_NAME} /etc/hosts || echo '192.168.255.100  www.#{DOMAIN_NAME} auth.#{DOMAIN_NAME} git.#{DOMAIN_NAME} mon.#{DOMAIN_NAME}' >> /etc/hosts"
    control.vm.provision :shell, :inline => "rm -f /etc/apt/apt.conf.d/20auto-upgrades"
    control.vm.provision :shell, :inline => "echo -e '[defaults]\nhost_key_checking = False' >> ~/.ansible.cfg", :privileged => false
    control.vm.provision :shell, :inline => "timedatectl set-ntp true"
    (1..NUM_TARGET).each do |i|
      control.vm.provision :shell, :inline => "sshpass -p vagrant ssh-copy-id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -f vagrant@#{WORKLOAD_NET}.1#{i}", :privileged => false
      control.vm.provision :shell, :inline => "grep #{WORKLOAD_NET}.1#{i} /etc/hosts || echo '#{WORKLOAD_NET}.1#{i} node#{i}.#{DOMAIN_NAME} node#{i}' >> /etc/hosts"
    end
  end
end
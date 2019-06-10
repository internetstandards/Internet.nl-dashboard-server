# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/bionic64"

  config.vm.network "private_network", ip: "172.30.1.5"

  config.vm.provision "shell" do |s|
    ssh_pub_key = File.readlines("#{Dir.home}/.ssh/id_rsa.pub").first.strip
    s.inline = <<-SHELL
      set -xe
      id johan || useradd johan -m -G sudo -s /bin/bash
      echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/sudo_group
      mkdir -p /home/johan/.ssh
      echo #{ssh_pub_key} >> /home/johan/.ssh/authorized_keys
      chown -R johan:johan /home/johan/
    SHELL
  end
end

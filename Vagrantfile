# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "master" do |master|
    master.vm.box = "ubuntu/jammy64"
    master.vm.hostname = "master"

    master.vm.network "private_network", type: "dhcp"
    master.vm.network :forwarded_port, guest: 22, host: 2030, id: "ssh"

    master.vm.provider "virtualbox" do |v|
      v.name = "Master"
    end
  end

  config.vm.define "slave" do |slave|
    slave.vm.box = "ubuntu/jammy64"
    slave.vm.hostname = "slave"

    slave.vm.network "private_network", type: "dhcp"
    slave.vm.network :forwarded_port, guest: 22, host: 2032, id: "ssh"

    slave.vm.provider "virtualbox" do |v|
      v.name = "Slave"
    end
  end

end

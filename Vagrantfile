# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.network :forwarded_port, host: 8080, guest: 80
  config.vm.box = "ubuntu/xenial64"
  config.vm.provision "shell", inline: <<-SHELL
  DEBIAN_FRONTEND=noninteractive apt-get install -qy python
  SHELL
end

Vagrant.configure("2") do |config|
  config.vm.define "hashicorp" do |config|
    config.vm.box = "hashicorp/bionic64"
    config.vm.provider "virtualbox" do |vm|
        vm.memory = 2048
        vm.cpus = 2
    end

    config.vbguest.auto_update = true

    # For testing encrypted drive
    config.vm.disk :disk, size: "10GB", name: "extra_storage"

    config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

    # Upload user's ssh key into box so it can be used for downloading stuff from github
    ssh_key_path = "~/.ssh/"
    config.vm.provision "shell", inline: "mkdir -p /home/vagrant/.ssh"
    config.vm.provision "file", source: "#{ ssh_key_path + 'id_rsa' }", destination: "/home/vagrant/.ssh/id_rsa"
    config.vm.provision "file", source: "#{ ssh_key_path + 'id_rsa.pub' }", destination: "/home/vagrant/.ssh/id_rsa.pub"

    config.vm.provision "shell", path: "src/pins/keyscript/vm-setup.sh"
  end
end
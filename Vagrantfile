require "base64"

Vagrant.configure("2") do |config|
  config.env.enable # Enable vagrant-env.

  vagrant_vm_name = "vb-vm"
  vagrant_vm_user = "vagrant"
  vagrant_vm_user_group = "vagrant"
  config.vm.define vagrant_vm_name, autostart: false do |sys|
    sys.vm.box = "ubuntu/xenial64"
    sys.vm.hostname = vagrant_vm_name
    sys.vm.provider "virtualbox" do |provider|
      provider.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      provider.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      provider.gui = false
      provider.memory = 4096
    end
    sys.vm.network "private_network", type: "dhcp"
    sys.vm.synced_folder ".", "/vagrant",
      type: "rsync",
      create: "true",
      rsync__args: [
        "-lrt",
        "--exclude-from=bin.host-only/synced-folder-exclude",
        "--chown=#{vagrant_vm_user}:#{vagrant_vm_user_group}"
      ],
      rsync__verbose: "true"
    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provisioning/provision.sh"
      shell.env = {
        "VAGRANT_VM_NAME" => vagrant_vm_name,
        "VAGRANT_USER" => vagrant_vm_user,
        "VAGRANT_USER_GROUP" => vagrant_vm_user_group,
        "GIT_USER_NAME" => ENV["GIT_USER_NAME"],
        "GIT_USER_EMAIL" => ENV["GIT_USER_EMAIL"]
      }

      git_ssh_private_key = ""
      File.foreach(ENV["GIT_SSH_PRIVATE_KEY_FILE"]) {|line|git_ssh_private_key << line}
      shell.env["GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
    end
  end
end

require "base64"

Vagrant.configure("2") do |config|
  config.env.enable # Enable vagrant-env.

  config.vm.define "vb-vm", autostart: false do |sys|
    sys.vm.box = "ubuntu/xenial64"
    sys.vm.hostname = "vb-vm"
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
        "-lrtz",
        "--exclude-from=bin.host-only/synced-folder-exclude",
        "--chown=#{"vagrant"}:#{"vagrant"}"
      ],
      rsync__verbose: "true"
    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provisioning/provision.sh"
      shell.env = {
        "VAGRANT_VM_NAME" => "vb-vm",
        "VAGRANT_USER" => "vagrant",
        "VAGRANT_USER_GROUP" => "vagrant",
        "GIT_USER_NAME" => ENV["GIT_USER_NAME"],
        "GIT_USER_EMAIL" => ENV["GIT_USER_EMAIL"]
      }
      git_ssh_private_key = ""
      File.foreach(ENV["GIT_SSH_PRIVATE_KEY_FILE"]) {|line|git_ssh_private_key << line}
      shell.env["GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
    end
  end

  if ENV.has_key?("DO_API_TOKEN")
    config.vm.define "do-vm", autostart: false do |sys|
      sys.vm.box = "digital_ocean"
      sys.vm.hostname = "do-vm"
      sys.ssh.private_key_path = ENV["DO_PRIVATE_KEY_FILE"]
      sys.vm.provider "digital_ocean" do |provider|
        provider.token = ENV["DO_API_TOKEN"]
        provider.image = "ubuntu-16-04-x64"
        provider.region = "nyc1"
        provider.size = "4gb"
        provider.ssh_key_name = ENV["DO_SSH_KEY_NAME"]
      end
      sys.vm.synced_folder ".", "/vagrant",
        type: "rsync",
        create: "true",
        rsync__args: [
          "-lrtz",
          "--exclude-from=bin.host-only/synced-folder-exclude",
          "--chown=#{"root"}:#{"root"}"
        ],
        rsync__verbose: "true"
      sys.vm.provision "shell" do |shell|
        shell.keep_color = true
        shell.path = "provisioning/provision.sh"
        shell.env = {
          "VAGRANT_VM_NAME" => "do-vm",
          "VAGRANT_USER" => "root",
          "VAGRANT_USER_GROUP" => "root",
          "GIT_USER_NAME" => ENV["GIT_USER_NAME"],
          "GIT_USER_EMAIL" => ENV["GIT_USER_EMAIL"]
        }
        git_ssh_private_key = ""
        File.foreach(ENV["GIT_SSH_PRIVATE_KEY_FILE"]) {|line|git_ssh_private_key << line}
        shell.env["GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
      end
    end
  end

end

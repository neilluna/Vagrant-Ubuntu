require "base64"
require "pathname"
require "yaml"

module Vagrant_Ansible_Linux
  PROJECT_DIR = Pathname.new(__FILE__).dirname.relative_path_from(Pathname.getwd)
  CONFIG_FILE = "config.yaml"

  # Vagrantfile API/syntax version. Don't change unless you know what you're doing!
  VAGRANTFILE_API_VERSION = "2"

  # Configure the build VMs.
  def self.configure
    if !(PROJECT_DIR + CONFIG_FILE).file?
      puts "Error: #{PROJECT_DIR + CONFIG_FILE} is missing."
      exit!
    end
    @@config_vars = YAML.load_file(PROJECT_DIR + CONFIG_FILE)
    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      if @@config_vars["digitalocean"]["include_configuration"]
        configure_digitalocean config
      end
      if @@config_vars["virtualbox"]["include_configuration"]
        configure_virtualbox config
      end
    end
  end

  # Configure the DigitalOcean build VM.
  def self.configure_digitalocean(config)
    name = "#{@@config_vars["vagrant"]["vm_prefix"]}-do"
    config.vm.define name, autostart: false do |sys|
      sys.vm.box = "digital_ocean"
      sys.vm.hostname = name
      sys.ssh.private_key_path = @@config_vars["digitalocean"]["private_key_file"]
      sys.vm.provider "digital_ocean" do |provider|
        provider.token = @@config_vars["digitalocean"]["api_token"]
        provider.image = "ubuntu-18-04-x64"
        provider.region = "nyc1"
        provider.size = "4gb"
        provider.ssh_key_name = @@config_vars["digitalocean"]["ssh_key_name"]
      end
      sync_folder sys, "root", "root"
      provision sys, "root", "root"
    end
  end

  # Configure the VirtualBox build VM.
  def self.configure_virtualbox(config)
    name = "#{@@config_vars["vagrant"]["vm_prefix"]}-vb"
    config.vm.define name, autostart: false do |sys|
      sys.vm.box = "ubuntu/bionic64"
      sys.vm.hostname = name
      sys.vm.provider "virtualbox" do |provider|
        provider.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        provider.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        provider.gui = false
        provider.memory = 4096
      end
      if @@config_vars["virtualbox"]["add_public_network_adapter"]
        sys.vm.network "public_network", type: "dhcp"
      end
      sync_folder sys, "vagrant", "vagrant"
      provision sys, "vagrant", "vagrant"
    end
  end

  # Define the provisioning script and variables.
  def self.provision(sys, user, group)
    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provisioning/provision.sh"
      shell.env = {
        "VAGRANT_VM_NAME" => sys.vm.hostname,
        "VAGRANT_USER" => user,
        "VAGRANT_USER_GROUP" => group
      }
      if @@config_vars["git"]["provision_environment"]
        shell.env["PROVISION_GIT_ENVIRONMENT"] = "true"
        shell.env["GIT_USER_NAME"] = @@config_vars["git"]["user_name"]
        shell.env["GIT_USER_EMAIL"] = @@config_vars["git"]["user_email"]
        git_ssh_private_key = ""
        File.foreach(@@config_vars["git"]["ssh_private_key_file"]) {|line|git_ssh_private_key << line}
        shell.env["GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
      end
    end
  end

  # Define the synced folder and method.
  def self.sync_folder(sys, user, group)
    sys.vm.synced_folder ".", "/vagrant",
      type: "rsync",
      create: "true",
      rsync__args: [
        "-lrtz",
        "--exclude-from=bin.host-only/synced-folder-exclude",
        "--chown=#{user}:#{group}"
      ],
      rsync__verbose: "true"
  end

end

Vagrant_Ansible_Linux.configure

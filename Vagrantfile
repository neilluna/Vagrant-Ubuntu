require "base64"

module Vagrant_Ansible_Linux

  # Vagrantfile API/syntax version. Don't change unless you know what you're doing!
  VAGRANTFILE_API_VERSION = "2"

  # Return true if all of the given environment variables are set.
  def self.are_all_env_vars_present?(env_vars)
    env_vars.each do |env_var|
      if !ENV.has_key? env_var
        return false
      end
    end
    return true
  end

  # Return true if any of the given environment variables are set.
  def self.are_any_env_vars_present?(env_vars)
    env_vars.each do |env_var|
      if ENV.has_key? env_var
        return true
      end
    end
    return false
  end

  # Print an error message and abort if some, but not all, of the DigitalOcean environment variables are set.
  # Return true if all of the DigitalOcean environment variables are set.
  # Return false if none of the DigitalOcean environment variables are set.
  def self.check_digitalocean_env_vars?()
    check_env_vars? ["DIGITALOCEAN_API_TOKEN", "DIGITALOCEAN_SSH_KEY_NAME", "DIGITALOCEAN_PRIVATE_KEY_FILE"]
  end

  # Print an error message and abort if some, but not all, of the given environment variables are set.
  # Return true if all of the given environment variables are set.
  # Return false if none of the given environment variables are set.
  def self.check_env_vars?(env_vars)
    if are_any_env_vars_present? env_vars
      if !are_all_env_vars_present? env_vars
        puts "Error: Some environment variables are missing."
        puts "Check: #{env_vars.join(", ")}"
        puts "Either set or unset them all."
        exit!
      end
      return true
    end
    return false
  end

  # Print an error message and abort if any of the required environment variables are missing.
  def self.check_required_env_vars()
    env_vars = ["GIT_USER_NAME", "GIT_USER_EMAIL", "GIT_SSH_PRIVATE_KEY_FILE", "VAGRANT_VM_PREFIX"]
    if !are_all_env_vars_present? env_vars
        puts "Error: Some environment variables are missing."
        puts "Check: #{env_vars.join(", ")}"
        exit!
    end
  end

  # Configure the build VMs.
  def self.configure
    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      config.env.enable # Enable vagrant-env.
      check_required_env_vars
      if check_digitalocean_env_vars?
        configure_digitalocean config
      end
      if !ignore_virtualbox?
        configure_virtualbox config
      end
    end
  end

  # Configure the DigitalOcean build VM.
  def self.configure_digitalocean(config)
    name = "#{ENV["VAGRANT_VM_PREFIX"]}-do"
    config.vm.define name, autostart: false do |sys|
      sys.vm.box = "digital_ocean"
      sys.vm.hostname = name
      sys.ssh.private_key_path = ENV["DIGITALOCEAN_PRIVATE_KEY_FILE"]
      sys.vm.provider "digital_ocean" do |provider|
        provider.token = ENV["DIGITALOCEAN_API_TOKEN"]
        provider.image = "ubuntu-16-04-x64"
        provider.region = "nyc1"
        provider.size = "4gb"
        provider.ssh_key_name = ENV["DIGITALOCEAN_SSH_KEY_NAME"]
      end
      sync_folder sys, "root", "root"
      provision sys, "root", "root"
    end
  end

  # Configure the VirtualBox build VM.
  def self.configure_virtualbox(config)
    name = "#{ENV["VAGRANT_VM_PREFIX"]}-vb"
    config.vm.define name, autostart: false do |sys|
      sys.vm.box = "ubuntu/xenial64"
      sys.vm.hostname = name
      sys.vm.provider "virtualbox" do |provider|
        provider.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        provider.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        provider.gui = false
        provider.memory = 4096
      end
      sys.vm.network "private_network", type: "dhcp"
      sync_folder sys, "vagrant", "vagrant"
      provision sys, "vagrant", "vagrant"
    end
  end

  # Return true if the VirtualBox VM should be ignored.
  def self.ignore_virtualbox?()
    return ENV.has_key? "VAGRANT_IGNORE_VIRTUALBOX"
  end

  # Define the provisioning script and variables.
  def self.provision(sys, user, group)
    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provisioning/provision.sh"
      shell.env = {
        "VAGRANT_VM_NAME" => sys.vm.hostname,
        "VAGRANT_USER" => user,
        "VAGRANT_USER_GROUP" => group,
        "GIT_USER_NAME" => ENV["GIT_USER_NAME"],
        "GIT_USER_EMAIL" => ENV["GIT_USER_EMAIL"]
      }
      git_ssh_private_key = ""
      File.foreach(ENV["GIT_SSH_PRIVATE_KEY_FILE"]) {|line|git_ssh_private_key << line}
      shell.env["GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
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

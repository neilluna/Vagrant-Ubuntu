require "base64"
require "pathname"
require "yaml"

module Vagrant_Dev_Sys
  PROJECT_DIR = Pathname.new(__FILE__).dirname.relative_path_from(Pathname.getwd)
  CONFIG_FILE = PROJECT_DIR + "config.yml"

  # Vagrantfile API/syntax version. Don't change unless you know what you're doing!
  VAGRANTFILE_API_VERSION = "2"

  # Configure the build VMs.
  def self.configure
    if !(CONFIG_FILE).file?
      puts "Error: #{CONFIG_FILE} is missing."
      exit!
    end
    config_file = YAML.load_file(CONFIG_FILE)
    default_options = config_file["defaults"]
    Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
      config_file["virtual_machines"].each do |vm_options|
        options = merge_options(vm_options, default_options)
        provider = options["provider"]
        if provider == "digitalocean"
          configure_digitalocean(config, options)
        end
        if provider == "virtualbox"
          configure_virtualbox(config, options)
        end
      end
    end
  end

  # Configure a DigitalOcean VM.
  def self.configure_digitalocean(config, options)
    vm_name = options["hostname"]
    provider_options = options["digitalocean"]
    config.vm.define vm_name, autostart: options["autostart"] do |sys|
      sys.vm.box = "digital_ocean"
      sys.vm.hostname = vm_name
      sys.ssh.private_key_path = provider_options["private_key_file"]
      sys.vm.provider "digital_ocean" do |provider|
        provider.token = provider_options["api_token"]
        provider.image = provider_options["image"]
        provider.region = provider_options["region"]
        provider.size = provider_options["size"]
        provider.ssh_key_name = provider_options["ssh_key_name"]
      end
      options["user"] = "root"
      options["group"] = "root"
      options["home_dir"] = "/root"
      synced_folder(sys, options)
      provision(sys, options)
    end
  end

  # Configure a VirtualBox VM.
  def self.configure_virtualbox(config, options)
    vm_name = options["hostname"]
    provider_options = options["virtualbox"]
    config.vm.define vm_name, autostart: options["autostart"] do |sys|
      sys.vm.box = provider_options["box"]
      sys.vm.hostname = vm_name
      sys.vm.provider "virtualbox" do |provider|
        provider.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        provider.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        provider.gui = provider_options["gui"]
        provider.memory = provider_options["memory"]
      end
      if provider_options["disk_size"] != 'default'
        sys.disksize.size = provider_options["disk_size"]
      end
      if provider_options["add_public_network_adapter"]
        sys.vm.network "public_network", type: "dhcp"
      end
      options["user"] = "vagrant"
      options["group"] = "vagrant"
      options["home_dir"] = "/home/vagrant"
      synced_folder(sys, options)
      update_guest_additions = provider_options["update_guest_additions"]
      config.vbguest.auto_update = update_guest_additions
      if update_guest_additions
        sys.vm.provision "shell", reboot: true
      end
      provision(sys, options)
    end
  end

  # Recursively merge two values.
  def self.merge_options(vm_option, default_option)
    if vm_option.is_a?(Hash) && default_option.is_a?(Hash)
      merged_option = {}
      default_option.each do |key, default_value|
        if vm_option.key?(key)
          merged_option[key] = merge_options(vm_option[key], default_value)
        else
          merged_option[key] = default_value
        end
      end
      vm_option.each do |key, vm_value|
        if !default_option.key?(key)
          merged_option[key] = vm_value
        end
      end
      return merged_option
    elsif vm_option.is_a?(Array) && default_option.is_a?(Array)
      return vm_option | default_option
    else
      return vm_option
    end
  end

  # Define the provisioning script and variables.
  def self.provision(sys, options)
    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provisioning/vagrant.sh"
      shell.env = {
        "DEV_SYS_USER" => options["user"],
        "DEV_SYS_GROUP" => options["group"]
      }
      if options.key?("ansible_dev_sys") && options["ansible_dev_sys"].is_a?(Hash)
        ansible_dev_sys_options = options["ansible_dev_sys"]
        if ansible_dev_sys_options.key?("branch")
          shell.env["DEV_SYS_ANSIBLE_DEV_SYS_BRANCH"] = ansible_dev_sys_options["branch"]
        end
      end
      if options.key?("aws") && options["aws"].is_a?(Hash)
        aws_options = options["aws"]
        if aws_options.key?("aws_config_dir")
          aws_config = ""
          File.foreach(Pathname.new(aws_options["aws_config_dir"])  + "config") {|line|aws_config << line}
          shell.env["DEV_SYS_AWS_CONFIG"] = Base64.strict_encode64(aws_config)
          aws_credentials = ""
          File.foreach(Pathname.new(aws_options["aws_config_dir"])  + "credentials") {|line|aws_credentials << line}
          shell.env["DEV_SYS_AWS_CREDENTIALS"] = Base64.strict_encode64(aws_credentials)
        end
      end
      if options.key?("bash_environment") && options["bash_environment"].is_a?(Hash)
        bash_environment_options = options["bash_environment"]
        if bash_environment_options.key?("branch")
          shell.env["DEV_SYS_BASH_ENVIRONMENT_BRANCH"] = bash_environment_options["branch"]
        end
      end
      if options.key?("git") && options["git"].is_a?(Hash)
        git_options = options["git"]
        if git_options.key?("git_config_file")
          git_config = ""
          File.foreach(git_options["git_config_file"]) {|line|git_config << line}
          shell.env["DEV_SYS_GIT_CONFIG"] = Base64.strict_encode64(git_config)
        end
        if git_options.key?("ssh_private_key_file")
          git_ssh_private_key = ""
          File.foreach(git_options["ssh_private_key_file"]) {|line|git_ssh_private_key << line}
          shell.env["DEV_SYS_GIT_SSH_PRIVATE_KEY"] = Base64.strict_encode64(git_ssh_private_key)
        end
      end
    end
  end

  # Define the synced folder and method.
  def self.synced_folder(sys, options)
    sys.vm.synced_folder ".", "/vagrant",
      type: "rsync",
      create: "true",
      rsync__args: [
        "-lrtz",
        "--exclude-from=synced-folder-exclude",
      ],
      rsync__verbose: "true"
  end

end

Vagrant_Dev_Sys.configure

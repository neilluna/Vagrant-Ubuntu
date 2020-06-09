require "pathname"
require "yaml"

module Vagrant_Dev_Sys
  PROJECT_DIR = Pathname.new(__FILE__).dirname.relative_path_from(Pathname.getwd)
  CONFIG_FILE = PROJECT_DIR + "config.yml"

  # Vagrantfile API/syntax version. Do not change this unless you know what you're doing!
  VAGRANTFILE_API_VERSION = "2"

  # Configure the VMs.
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
      end  # config_file ... do |vm_options|
    end  # Vagrant.configure ...  do |config|
  end  # def self.configure

  # Configure a DigitalOcean VM.
  def self.configure_digitalocean(config, options)
    vm_name = options["hostname"]
    options["user"] = "root"
    options["group"] = "root"
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
      end  # sys.vm.provider ... do |provider|

      synced_folders(sys, options)
      provision(sys, options)
    end  # config.vm.define ... do |sys|
  end  # def self.configure_digitalocean()

  # Configure a VirtualBox VM.
  def self.configure_virtualbox(config, options)
    vm_name = options["hostname"]
    options["user"] = "vagrant"
    options["group"] = "vagrant"
    provider_options = options["virtualbox"]

    config.vm.define vm_name, autostart: options["autostart"] do |sys|
      sys.vm.box = provider_options["box"]
      sys.vm.hostname = vm_name
      sys.vm.provider "virtualbox" do |provider|
        provider.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        provider.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        provider.gui = provider_options["gui"]
        provider.memory = provider_options["memory"]
      end  # sys.vm.provider ... do |provider|

      if provider_options["disk_size"] != 'default'
        sys.disksize.size = provider_options["disk_size"]
      end

      if provider_options["add_public_network_adapter"]
        sys.vm.network "public_network", type: "dhcp"
      end

      config.vbguest.auto_update = provider_options["update_guest_additions"]
      if provider_options["update_guest_additions"]
        sys.vm.provision "shell", reboot: true
      end

      synced_folders(sys, options)
      provision(sys, options)
    end  # config.vm.define ... do |sys|
  end  # def self.configure_virtualbox()

  # Recursively merge two values.
  def self.merge_options(vm_option, default_option)
    # If both are hashes, then merge them.
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
    
    # If both are arrays, then union them.
    elsif vm_option.is_a?(Array) && default_option.is_a?(Array)
      return vm_option | default_option

    # If they are of dissimilar types, or either is not a hash or array, the vm_option overrides the default_option.
    else
      return vm_option
    end
  end  # def self.merge_options()

  # Provisioning a VM.
  def self.provision(sys, options)
    provision_options = options.key?("provision") ? options["provision"] : {}
    provision_dirs = provision_options.key?("dirs") ? provision_options["dirs"] : {}
    provision_files = provision_options.key?("files") ? provision_options["files"] : {}

    ansible_dev_sys_options = options.key?("ansible_dev_sys") ? options["ansible_dev_sys"] : {}
    bash_environment_options = options.key?("bash_environment") ? options["bash_environment"] : {}

    provision_dirs.each do |dir|
      sys.vm.provision "file", source: dir["host"], destination: dir["remote"]
      if dir.key?("dir_mode")
        command = "find #{dir["remote"]} -type d -exec chmod #{dir["dir_mode"]}" + ' {} \;'
        sys.vm.provision "shell", inline: command
      end
      if dir.key?("file_mode")
        command = "find #{dir["remote"]} -type f -exec chmod #{dir["file_mode"]}" + ' {} \;'
        sys.vm.provision "shell", inline: command
      end
    end  # provision_dirs.each do |dir|

    provision_files.each do |file|
      sys.vm.provision "file", source: file["host"], destination: file["remote"]
      if file.key?("file_mode")
        command = "chmod #{file["file_mode"]} #{file["remote"]}"
        sys.vm.provision "shell", inline: command
      end
    end  # provision_files.each do |file|

    sys.vm.provision "shell" do |shell|
      shell.keep_color = true
      shell.path = "provision.sh"

      if ansible_dev_sys_options.key?("playbook_name")
        shell.args = ansible_dev_sys_options["playbook_name"]
      end

      shell.env = {
        "DEV_SYS_USER" => options["user"],
        "DEV_SYS_GROUP" => options["group"]
      }

      if ansible_dev_sys_options.key?("dir")
        shell.env["ANSIBLE_DEV_SYS_DIR"] = ansible_dev_sys_options["dir"]
      elsif ansible_dev_sys_options.key?("version")
        shell.env["ANSIBLE_DEV_SYS_VERSION"] = ansible_dev_sys_options["version"]
      end

      if bash_environment_options.key?("dir")
        shell.env["BASH_ENVIRONMENT_DIR"] = bash_environment_options["dir"]
      elsif bash_environment_options.key?("version")
        shell.env["BASH_ENVIRONMENT_VERSION"] = bash_environment_options["version"]
      end
    end  # sys.vm.provision "shell"
  end  # def self.provision()

  # Define the synced folder and method.
  def self.synced_folders(sys, options)
    synced_folders = options.key?("synced_folders") ? options["synced_folders"] : {}

    sys.vm.synced_folder ".", "/vagrant", disabled: true
    synced_folders.each do |folder|
      sys.vm.synced_folder folder["host"], folder["remote"],
        type: "rsync",
        create: "true",
        rsync__args: ["-lrtz"],
        rsync__exclude: [".git/", ".gitignore"],
        rsync__verbose: "true"
    end  # synced_folders.each do |folder|
  end  # def self.synced_folders()
end  # module Vagrant_Dev_Sys

Vagrant_Dev_Sys.configure

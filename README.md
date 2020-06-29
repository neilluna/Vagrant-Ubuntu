# vagrant-dev-sys
Version 0.1.0

Provision one or more development environments using Vagrant.

## Prerequisites
In order to use this project, you must have the following:

- VirtualBox installed.
- Vagrant installed.
- A DigitalOcean account and API token, if you are creating the VM on DigitalOcean.

Once Vagrant is installed, please install the following Vagrant plugins:
```
vagrant-digitalocean
vagrant-disksize
vagrant-vbguest
vagrant_reboot_linux
```

## Use:
1. Copy `sample.config.yaml` to `config.yaml`. Edit `config.yaml` with your parameters.
1. Use the standard Vagrant commands ("status", "up", "ssh", "destroy") to manage your VMs.

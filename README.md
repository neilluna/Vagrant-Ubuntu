# ReadMe

## vagrant-ansible-linux

Vagrant and Ansible scripts to spin up a Linux virtual machine.

This project will allow you to create and manage a Virtual Machine running Ubuntu 18.04 LTS on either VirtualBox or DigitalOcean. The VM will be provisioned with the following software:

- [bash-environment](https://github.com/neilluna/bash-environment)
- Ansible
- build-essential
- Git. Optionally, the developer's Git configuration on the host can be replicated on the VM.
- nodejs
- Python 2 and pip 2
- Python 3 and pip 3
- virtualenv, virtualenvwrappeer, and pipenv (using pip 3)
- AWS CLI (in a pipenv environment using Python 3). Optionally, the developer's AWS default configuration and credentials on the host can be replicated on the VM.
- NVM, NodeJS (installed local using NVM), and NPM
- Docker
- sglite
- Misc other tools

In order to use this project, you must have the following:

- VirtualBox installed.
- Vagrant installed.
- Bash. You can use Cygwin on Windows.
- Python 3. You can use the Cygwin version of Python 3 on Windows.
- A DigitalOcean account and API token, if you are creating the VM on DigitalOcean.

Once Vagrant is installed, please install the following Vagrant plugins if you plan to use DigitalOcean VMs.
```
vagrant plugin install --plugin-version 1.0.1 fog-ovirt
vagrant plugin install vagrant-digitalocean
```

## How to use:
1. Copy `sample.config.yaml` to `config.yaml`. Edit `config.yaml` with your parameters.
1. Use the standard Vagrant commands ("status", "up", "ssh", "destroy") to manage your VM.
1. `./bin.hostonly/sync-vm.sh` can be used to easily sync changes from the host to the VM, or vice versa.  Use the `-h` parameter for help.

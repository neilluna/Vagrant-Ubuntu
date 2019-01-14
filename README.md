# ReadMe

## vagrant-ansible-linux

Vagrant and Ansible scripts to spin up a Linux virtual machine.

This project will allow you to create and manage a Virtual Machine running Ubuntu 18.04 LTS on either VirtualBox or DigitalOcean. The VM will be provisioned with the following software:

- [bash-environment](https://github.com/neilluna/bash-environment)
- build-essential
- docker
- git
- nodejs
- python 2 and pip 2
- python 3 and pip 3
- sglite
- Misc other tools

In order to use this project, you must have the following:

- VirtualBox installed.
- Vagrant installed.
- Bash. You can use Cygwin on Windows.
- Python 3. You can use the Cygwin version of Python 3 on Windows.
- A DigitalOcean account.
- A DigitalOcean API token.

Once Vagrant is installed, please install the following Vagrant plugins:
```
vagrant plugin install --plugin-version 1.0.1 fog-ovirt
vagrant plugin install vagrant-digitalocean
```

## How to use:
1. Copy sample.config.yaml to config.yaml. Edit config.yaml with your parameters.

1. Use the standard Vagrant commands ("status", "up", "ssh", "destroy") to manage your VM.

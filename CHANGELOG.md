# Change log for vagrant-dev-sys

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- Removed all Ansible rules. This project now uses ansible-dev-sys.
- `provision-vagrant.sh` now only sets up a minimum. It call `dev-sys.sh` in ansible-dev-sys for the majority of provisioning.
- Replication of the developer's AWS configuration and credentials has been removed temporarily. It will be restored when ansible-dev-sys has been updated to support AWS EC2 VMs.

## [1.1.0] - 2019-03-08
### Added
- The developer's AWS configuration and credentials on the host can be replicated on the VM.

## [1.0.0] - 2019-01-03
### Added
- Initial release.
- VirtualBox and DigitalOcean VMs are supported.
- The [Bash-Environment](https://github.com/neilluna/Bash-Environment) is installed for the Vagrant user.
- The developer's Git configuration on the host can be replicated on the VM.
    - The [Bash-Environment](https://github.com/neilluna/Bash-Environment)'s `create-gitconfig.sh` tool is used to create the developer's Git configuration.
    - A user specified SSH key on the host is copied to the VM for Git SSH operations.
- A host-to-VM sync tool is provided. Run `bin.host_only/sync-vm.sh -h` for usage.

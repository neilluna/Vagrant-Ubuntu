# Changelog

## vagrant-dev-sys

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2019-03-08
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

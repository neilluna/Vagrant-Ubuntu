#!/usr/bin/env bash

# ANSI color escape sequences for use in log().
black='\e[30m'
red='\e[31m'
green='\e[32m'
yellow='\e[33m'
blue='\e[34m'
magenta='\e[35m'
cyan='\e[36m'
white='\e[37m'
reset='\e[0m'

# Using ANSI escape codes for color works, yet tput does not.
# This may be caused by tput not being able to determine the terminal type.
function log()
{
  color=${1}
  message=${2}
  echo -e "${color}${message}${reset}"
}

function retry_if_fail()
{
  ${*}
  if [ ${?} -ne 0 ]; then
    max_retries=3
    retry_wait=15
    retry=1
    while [ ${retry} -le ${max_retries} ]; do
      log ${red} "- Failed. Will retry in ${retry_wait} seconds ..."
      sleep ${retry_wait}
      log ${cyan} "- Retrying ..."
      ${*} && break
      retry=$[$retry + 1]
    done
    if [ ${retry} -gt ${max_retries} ]; then
      exit 1
    fi
  fi
}

set_permissions_script=/vagrant/provisioning/set-permissions.sh
log ${cyan} "Running ${set_permissions_script} ..."
chmod u+rwx,go+rx-w ${set_permissions_script}
${set_permissions_script}

if [ ! -d /opt ]; then
  log ${cyan} "Creating the /opt directory ..."
  sudo mkdir -p /opt
  sudo chown root:root /opt
  sudo chmod u+rwx,go+rx-w /opt
fi

# Make installations non-interactive.
export DEBIAN_FRONTEND=noninteractive

log ${cyan} "Running apt-get update ..."
retry_if_fail sudo apt-get update

log ${cyan} "Installing software-properties-common ..."
retry_if_fail sudo apt-get -y install software-properties-common

log ${cyan} "Adding the Ansible repository ..."
retry_if_fail sudo apt-add-repository -y ppa:ansible/ansible

log ${cyan} "Running apt-get update ..."
retry_if_fail sudo apt-get update

log ${cyan} "Installing Ansible ..."
retry_if_fail sudo apt-get -y install ansible

vagrant_user_home_dir=$(eval echo ~${VAGRANT_USER})

git_ssh_private_key_file=${vagrant_user_home_dir}/.ssh/id_git
log ${cyan} "Saving the Git SSH private key ..."
echo "${GIT_SSH_PRIVATE_KEY}" | base64 --decode > ${git_ssh_private_key_file}
sudo chmod u+rw-x,go-rwx ${git_ssh_private_key_file}
sudo chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${git_ssh_private_key_file}

ansible_ssh_private_key_file=${vagrant_user_home_dir}/.ssh/id_ansible
ansible_ssh_public_key_file=${ansible_ssh_private_key_file}.pub
log ${cyan} "Creating new SSH keys for Ansible ..."
ssh-keygen -C id_rsa_ansible -f ${ansible_ssh_private_key_file} -N ""
sudo chmod u+rw-x,go-rwx ${ansible_ssh_private_key_file}
sudo chmod u+rw-x,go+r-wx ${ansible_ssh_public_key_file}
sudo chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${ansible_ssh_private_key_file} ${ansible_ssh_public_key_file}

ansible_ssh_public_key_contents=$(cat ${ansible_ssh_public_key_file})
vagrant_user_authorized_keys=${vagrant_user_home_dir}/.ssh/authorized_keys
grep -Fx "${ansible_ssh_public_key_contents}" ${vagrant_user_authorized_keys} > /dev/null
if [ ${?} -ne 0 ]; then
  log ${cyan} "Adding the new Ansible SSH public key to ${vagrant_user_authorized_keys} ..."
  echo "${ansible_ssh_public_key_contents}" >> ${vagrant_user_authorized_keys}
fi

provisioning_information_dir=/etc/provisioning
log ${cyan} "Creating ${provisioning_information_dir} ..."
mkdir -p ${provisioning_information_dir}
sudo chmod u+rwx,go+rx-w ${provisioning_information_dir}
sudo chown root:root ${provisioning_information_dir}

ansible_config_file=${provisioning_information_dir}/ansible.cfg
ansible_inventory_file=${provisioning_information_dir}/ansible-inventory

log ${cyan} "Creating ${ansible_config_file} ..."
cat << EOF1 > ${ansible_config_file}
[defaults]
force_color = True
inventory = ${ansible_inventory_file}
roles_path = /vagrant/provisioning/ansible/roles:/etc/ansible/roles

EOF1
sudo chmod u+rw-x,go+r-wx ${ansible_config_file}
sudo chown root:root ${ansible_config_file}

log ${cyan} "Creating ${ansible_inventory_file} ..."
cat << EOF2 > ${ansible_inventory_file}
[self]
${VAGRANT_VM_NAME}

[self:vars]
ansible_connection=ssh
ansible_host=127.0.0.1
ansible_user=${VAGRANT_USER}
ansible_ssh_private_key_file=${ansible_ssh_private_key_file}

EOF2
sudo chmod u+rw-x,go+r-wx ${ansible_inventory_file}
sudo chown root:root ${ansible_inventory_file}

ansible_vars_script=${provisioning_information_dir}/ansible-vars.sh
log ${cyan} "Creating ${ansible_vars_script} ..."
cat << EOF3 > ${ansible_vars_script}
#!/usr/bin/env bash

# Keep this script idempotent. It will probably be called multiple times.

export ANSIBLE_CONFIG=${ansible_config_file}

# So that playbooks will echo while playing.
export PYTHONUNBUFFERED=1

EOF3
sudo chmod u+rwx,go+rx-w ${ansible_vars_script}
sudo chown root:root ${ansible_vars_script}

git_vars_script=${provisioning_information_dir}/git-vars.sh
log ${cyan} "Creating ${git_vars_script} ..."
cat << EOF4 > ${git_vars_script}
#!/usr/bin/env bash

# Keep this script idempotent. It will probably be called multiple times.

export GIT_SSH_COMMAND='ssh -i ${git_ssh_private_key_file}'

EOF4
sudo chmod u+rwx,go+rx-w ${git_vars_script}
sudo chown root:root ${git_vars_script}

git_vars_yaml=${provisioning_information_dir}/git-vars.yaml
log ${cyan} "Creating ${git_vars_yaml} ..."
cat << EOF5 > ${git_vars_yaml}
---
git_user_name: ${GIT_USER_NAME}
git_user_email: ${GIT_USER_EMAIL}

EOF5
sudo chmod u+rw-x,go+r-wx ${git_vars_yaml}
sudo chown root:root ${git_vars_yaml}

vagrant_vars_script=${provisioning_information_dir}/vagrant-vars.sh
log ${cyan} "Creating ${vagrant_vars_script} ..."
cat << EOF6 > ${vagrant_vars_script}
#!/usr/bin/env bash

# Keep this script idempotent. It will probably be called multiple times.

export VAGRANT_VM_NAME=${VAGRANT_VM_NAME}
export VAGRANT_USER=${VAGRANT_USER}
export VAGRANT_USER_GROUP=${VAGRANT_USER_GROUP}

EOF6
sudo chmod u+rwx,go+rx-w ${vagrant_vars_script}
sudo chown root:root ${vagrant_vars_script}

vagrant_vars_yaml=${provisioning_information_dir}/vagrant-vars.yaml
log ${cyan} "Creating ${vagrant_vars_yaml} ..."
cat << EOF7 > ${vagrant_vars_yaml}
---
vagrant_vm_name: ${VAGRANT_VM_NAME}
vagrant_user: ${VAGRANT_USER}
vagrant_user_group: ${VAGRANT_USER_GROUP}

EOF7
sudo chmod u+rw-x,go+r-wx ${vagrant_vars_yaml}
sudo chown root:root ${vagrant_vars_yaml}

log ${cyan} "Sourcing ${ansible_vars_script} ..."
source ${ansible_vars_script}

export ANSIBLE_HOST_KEY_CHECKING=False

ansible_playbook=/vagrant/provisioning/ansible/ansible-playbook.yaml
log ${cyan} "Playing ${ansible_playbook} ..."
ansible-playbook ${ansible_playbook} || exit 1

exit 0

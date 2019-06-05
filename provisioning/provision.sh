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

function add_self_to_known_hosts()
{
	user=${1}
	users_home_dir=$(eval echo ~${1})
	users_known_hosts_file=${users_home_dir}/.ssh/known_hosts
	if [ ! -f ${users_known_hosts_file} ]; then
		log ${cyan} "Creating ${users_known_hosts_file} ..."
		touch ${users_known_hosts_file}
		chmod u+rw-x,go+r-wx ${users_known_hosts_file}
		chown ${user}:${user} ${users_known_hosts_file}
	fi
	ssh-keygen -F 127.0.0.1 -f ${users_known_hosts_file} > /dev/null 2>&1
	if [ ${?} -ne 0 ]; then
		log ${cyan} "Adding the VM's SSH fingerprint to ${users_known_hosts_file} ..."
		ssh-keyscan -H 127.0.0.1 >> ${users_known_hosts_file}
	fi
}

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

set_permissions_script=/vagrant/bin.vm-only/set-permissions.sh
log ${cyan} "Running ${set_permissions_script} ..."
chmod u+rwx,go+rx-w ${set_permissions_script}
${set_permissions_script}

if [ ! -d /opt ]; then
	log ${cyan} "Creating /opt ..."
	mkdir -p /opt
	chmod u+rwx,go+rx-w /opt
	chown root:root /opt
fi

# Make installations non-interactive.
export DEBIAN_FRONTEND=noninteractive

log ${cyan} "Running apt-get update ..."
retry_if_fail apt-get update --yes

log ${cyan} "Running apt-get upgrade ..."
retry_if_fail apt-get upgrade --yes

log ${cyan} "Installing aptitude ..."
retry_if_fail apt-get install aptitude --yes

log ${cyan} "Installing software-properties-common ..."
retry_if_fail apt-get install software-properties-common --yes

log ${cyan} "Installing Python3 and pip3 ..."
retry_if_fail apt-get install python3 python3-pip --yes

log ${cyan} "Installing Ansible ..."
retry_if_fail pip3 install ansible

add_self_to_known_hosts $(whoami)
add_self_to_known_hosts ${VAGRANT_USER}

vagrant_user_home_dir=$(eval echo ~${VAGRANT_USER})

if [ "${PROVISION_GIT_ENVIRONMENT}" == "true" ]; then
	git_ssh_private_key_file=${vagrant_user_home_dir}/.ssh/id_git
	log ${cyan} "Saving the Git SSH private key ..."
	echo "${GIT_SSH_PRIVATE_KEY}" | base64 --decode > ${git_ssh_private_key_file}
	chmod u+rw-x,go-rwx ${git_ssh_private_key_file}
	chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${git_ssh_private_key_file}
fi

ansible_ssh_private_key_file=${vagrant_user_home_dir}/.ssh/id_rsa_ansible
ansible_ssh_public_key_file=${ansible_ssh_private_key_file}.pub
log ${cyan} "Creating new SSH keys for Ansible ..."
ssh-keygen -C id_rsa_ansible -f ${ansible_ssh_private_key_file} -N ""
chmod u+rw-x,go-rwx ${ansible_ssh_private_key_file}
chmod u+rw-x,go+r-wx ${ansible_ssh_public_key_file}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${ansible_ssh_private_key_file} ${ansible_ssh_public_key_file}

ansible_ssh_public_key_contents=$(cat ${ansible_ssh_public_key_file})
vagrant_user_authorized_keys=${vagrant_user_home_dir}/.ssh/authorized_keys
grep -Fx "${ansible_ssh_public_key_contents}" ${vagrant_user_authorized_keys} > /dev/null
if [ ${?} -ne 0 ]; then
	log ${cyan} "Adding the new Ansible SSH public key to ${vagrant_user_authorized_keys} ..."
	echo "${ansible_ssh_public_key_contents}" >> ${vagrant_user_authorized_keys}
fi

provisioning_information_dir=${vagrant_user_home_dir}/provisioning
log ${cyan} "Creating ${provisioning_information_dir} ..."
mkdir -p ${provisioning_information_dir}
chmod u+rwx,go-rwx ${provisioning_information_dir}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${provisioning_information_dir}

ansible_config_file=${provisioning_information_dir}/ansible.cfg
ansible_inventory_file=${provisioning_information_dir}/ansible-inventory

log ${cyan} "Creating ${ansible_config_file} ..."
cat << EOF1 > ${ansible_config_file}
[defaults]
force_color = True
inventory = ${ansible_inventory_file}
roles_path = /vagrant/provisioning/ansible/roles:/etc/ansible/roles

EOF1
chmod u+rw-x,go-rwx ${ansible_config_file}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${ansible_config_file}

log ${cyan} "Creating ${ansible_inventory_file} ..."
cat << EOF2 > ${ansible_inventory_file}
[self]
${VAGRANT_VM_NAME}

[self:vars]
ansible_connection=ssh
ansible_host=127.0.0.1
ansible_python_interpreter=$(which python3)
ansible_user=${VAGRANT_USER}
ansible_ssh_private_key_file=${ansible_ssh_private_key_file}

EOF2
chmod u+rw-x,go-rwx ${ansible_inventory_file}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${ansible_inventory_file}

ansible_vars_script=${provisioning_information_dir}/ansible-vars.sh
log ${cyan} "Creating ${ansible_vars_script} ..."
cat << EOF3 > ${ansible_vars_script}
#!/usr/bin/env bash

# Keep this script idempotent. It will probably be called multiple times.

export ANSIBLE_CONFIG=${ansible_config_file}

# So that playbooks will echo while playing.
export PYTHONUNBUFFERED=1

EOF3
chmod u+rwx,go-rwx ${ansible_vars_script}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${ansible_vars_script}

aws_vars_yaml=${provisioning_information_dir}/aws-vars.yaml
log ${cyan} "Creating ${aws_vars_yaml} ..."
if [ "${PROVISION_AWS_ENVIRONMENT}" == "true" ]; then
	cat <<-EOF4 > ${aws_vars_yaml}
	---
	provision_aws_environment: true
	aws_access_key_id: ${AWS_ACCESS_KEY_ID}
	aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}

	EOF4
else
	cat <<-EOF5 > ${aws_vars_yaml}
	---
	provision_aws_environment: false

	EOF5
fi
chmod u+rw-x,go-rwx ${aws_vars_yaml}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${aws_vars_yaml}

if [ "${PROVISION_GIT_ENVIRONMENT}" == "true" ]; then
	git_vars_script=${provisioning_information_dir}/git-vars.sh
	log ${cyan} "Creating ${git_vars_script} ..."
	cat <<-EOF6 > ${git_vars_script}
	#!/usr/bin/env bash

	# Keep this script idempotent. It will probably be called multiple times.

	export GIT_SSH_COMMAND='ssh -i ${git_ssh_private_key_file}'

	EOF6
	chmod u+rwx,go-rwx ${git_vars_script}
	chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${git_vars_script}
fi

git_vars_yaml=${provisioning_information_dir}/git-vars.yaml
log ${cyan} "Creating ${git_vars_yaml} ..."
if [ "${PROVISION_GIT_ENVIRONMENT}" == "true" ]; then
	cat <<-EOF7 > ${git_vars_yaml}
	---
	provision_git_environment: true
	git_user_name: ${GIT_USER_NAME}
	git_user_email: ${GIT_USER_EMAIL}

	EOF7
else
	cat <<-EOF8 > ${git_vars_yaml}
	---
	provision_git_environment: false

	EOF8
fi
chmod u+rw-x,go-rwx ${git_vars_yaml}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${git_vars_yaml}

vagrant_vars_yaml=${provisioning_information_dir}/vagrant-vars.yaml
log ${cyan} "Creating ${vagrant_vars_yaml} ..."
cat << EOF9 > ${vagrant_vars_yaml}
---
vagrant_vm_name: ${VAGRANT_VM_NAME}
vagrant_user: ${VAGRANT_USER}
vagrant_user_group: ${VAGRANT_USER_GROUP}

EOF9
chmod u+rw-x,go-rwx ${vagrant_vars_yaml}
chown ${VAGRANT_USER}:${VAGRANT_USER_GROUP} ${vagrant_vars_yaml}

log ${cyan} "Sourcing ${ansible_vars_script} ..."
source ${ansible_vars_script}

ansible_playbook=/vagrant/provisioning/ansible/provision-self.yaml
log ${cyan} "Playing ${ansible_playbook} ..."

ansible-playbook \
	--extra-vars "@${aws_vars_yaml}" \
	--extra-vars "@${git_vars_yaml}" \
	--extra-vars "@${vagrant_vars_yaml}" \
	${ansible_playbook} || exit 1

exit 0

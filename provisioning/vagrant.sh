#!/usr/bin/env bash

script_version=1.0.0

script_name=$(basename ${BASH_SOURCE[0]})
script_dir=$(dirname ${BASH_SOURCE[0]})
script_path=${BASH_SOURCE[0]}

function echo_usage()
{
	echo "${script_name} - Version ${script_version}"
	echo ""
	echo "Provision a VirtualBox virtual machine."
	echo ""
	echo "Usage: ${script_name} [options] [playbook_name]"
	echo ""
	echo "  -h, --help     Output this help information."
	echo "  -v, --verbose  Verbose output."
	echo "      --version  Output the version."
}

# ANSI color escape sequences for use in echo_color().
black='\e[30m'
red='\e[31m'
green='\e[32m'
yellow='\e[33m'
blue='\e[34m'
magenta='\e[35m'
cyan='\e[36m'
white='\e[37m'
reset='\e[0m'

# Echo color messages.
# Echoing ANSI escape codes for color works, yet tput does not.
# This may be caused by tput not being able to determine the terminal type.
# Usage: echo_color color message
function echo_color()
{
	color=${1}
	message=${2}
	echo -e "${color}${message}${reset}"
}

# Set the mode, user, and group of a file or directory.
# Usage: set_mode_user_group mode user group file_or_dir
function set_mode_user_group()
{
	mode=${1}
	user=${2}
	group=${3}
	file_or_dir=${4}
	sudo chmod ${mode} ${file_or_dir}
	sudo chown ${user}:${group} ${file_or_dir}
}

# Create a directory, if it does not exist.
# If created, set the mode, user, and group of the new directory.
# Usage: create_dir_with_mode_user_group mode user group dir
function create_dir_with_mode_user_group()
{
	mode=${1}
	user=${2}
	group=${3}
	dir=${4}
	[ -d ${dir} ] && return
	echo_color ${cyan} "Creating ${dir} ..."
	sudo mkdir -p ${dir}
	sudo chmod ${mode} ${dir}
	sudo chown ${user}:${group} ${dir}
}

# Attempt a command up to four times; one initial attempt followed by three reties.
# Attempts are spaced 15 seconds apart.
# Usage: retry_if_fail command args
function retry_if_fail()
{
	${*}
	if [ ${?} -ne 0 ]; then
		max_retries=3
		retry_wait=15
		retry=1
		while [ ${retry} -le ${max_retries} ]; do
			echo_color ${yellow} "- Failed. Will retry in ${retry_wait} seconds ..."
			sleep ${retry_wait}
			echo_color ${cyan} "- Retrying (${retry} of ${max_retries}) ..."
			${*} && break
			retry=$[$retry + 1]
		done
		if [ ${retry} -gt ${max_retries} ]; then
			echo_color ${red} "- Failed."
			exit 1
		fi
	fi
}

# Adds 127.0.0.1 to the known_hosts file for the specified user.
# Used to avoid prompts when Ansible uses SSH to provison the local host.
# Usage: add_localhost_to_known_hosts_for_user user
function add_localhost_to_known_hosts_for_user()
{
	user=${1}
	users_home_dir=$(eval echo ~${1})
	users_known_hosts_file=${users_home_dir}/.ssh/known_hosts
	if [ ! -f ${users_known_hosts_file} ]; then
		echo_color ${cyan} "Creating ${users_known_hosts_file} ..."
		touch ${users_known_hosts_file}
		chown ${user}:${user} ${users_known_hosts_file}
		chmod u+rw-x,go+r-wx ${users_known_hosts_file}
	fi
	ssh-keygen -F 127.0.0.1 -f ${users_known_hosts_file} > /dev/null 2>&1
	if [ ${?} -ne 0 ]; then
		echo_color ${cyan} "Adding the VM's SSH fingerprint to ${users_known_hosts_file} ..."
		ssh-keyscan -H 127.0.0.1 >> ${users_known_hosts_file}
	fi
}

# Provision directory and file modes. Keeps things private.
ASSET_DIR_MODE=u+rwx,go-rwx
ASSET_FILE_MODE=u+rw-x,go-rwx
ASSET_SCRIPT_MODE=u+rwx,go-rwx

# Make installations non-interactive.
export DEBIAN_FRONTEND=noninteractive

# Command-line switch variables.
playbook_name=
verbose=no

# NOTE: This requires GNU getopt. On Mac OS X and FreeBSD, you have to install this separately.
ARGS=$(getopt -o h -l help,version -n ${script_name} -- "${@}")
if [ ${?} != 0 ]; then
	exit 1
fi

# The quotes around "${ARGS}" are necessary.
eval set -- "${ARGS}"

# Parse the command line arguments.
while true; do
	case "${1}" in
		-h | --help)
			echo_usage
			exit 0
			;;
		-v | --verbose)
			verbose=yes
			shift
			;;
		--version)
			echo "${script_version}"
			exit 0
			;;
		--)
			shift
			break
			;;
	esac
done
while [ ${#} -gt 0 ]; do
	if [ -z "${playbook_name}" ]; then
		playbook_name=${1}
	else
		echo "${script_name}: Error: Invalid argument: ${1}" >&2
		echo_usage
		exit 1
	fi
	shift
done
if [ -z "${playbook_name}" ]; then
	playbook_name=common
fi

echo_color ${cyan} "Script: '${script_path}', playbook: '${playbook_name}'"
echo_color ${cyan} "Current user: '$(whoami)', home: '${HOME}'"
echo_color ${cyan} "Current directory: '$(pwd)'"

dev_user_home_dir=$(eval echo ~${DEV_SYS_USER})
echo_color ${cyan} "DEV_SYS user: '${DEV_SYS_USER}', group: '${DEV_SYS_GROUP}', home: '${dev_user_home_dir}'"

# Create the provisioning assets directory.
assets_dir=${dev_user_home_dir}/.dev-sys
create_dir_with_mode_user_group ${ASSET_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${assets_dir}

# If ANSIBLE_DEV_SYS_DIR is not defined, set it to a default.
if [ -z "${ANSIBLE_DEV_SYS_DIR}" ]; then
	ANSIBLE_DEV_SYS_DIR=${assets_dir}/ansible-dev-sys
fi

# Save ANSIBLE_DEV_SYS_DIR into a script for later use.
ansible_dev_sys_dir_script=${assets_dir}/ansible-dev-sys-dir.sh
echo_color ${cyan} "Creating ${ansible_dev_sys_dir_script} ..."
cat << EOF > ${ansible_dev_sys_dir_script}
#!/usr/bin/env bash
ANSIBLE_DEV_SYS_DIR=${ANSIBLE_DEV_SYS_DIR}
EOF
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${ansible_dev_sys_dir_script}

# If BASH_ENVIRONMENT_DIR is not defined, set it to a default.
if [ -z "${BASH_ENVIRONMENT_DIR}" ]; then
	BASH_ENVIRONMENT_DIR=${assets_dir}/bash-environment
fi

# Save BASH_ENVIRONMENT_DIR into a script for later use.
bash_environment_dir_script=${assets_dir}/bash-environment-dir.sh
echo_color ${cyan} "Creating ${bash_environment_dir_script} ..."
cat << EOF > ${bash_environment_dir_script}
#!/usr/bin/env bash
BASH_ENVIRONMENT_DIR=${BASH_ENVIRONMENT_DIR}
EOF
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${bash_environment_dir_script}

# If ansible-dev-sys does not exist ...
if [ ! -d ${ANSIBLE_DEV_SYS_DIR} ]; then
	# Temporarily clone ansible-dev-sys.
	temp_ansible_dev_sys=${assets_dir}/tmp-ansible-dev-sys
	ansible_dev_sys_url=https://github.com/neilluna/ansible-dev-sys.git
	echo_color ${cyan} "Cloning ${ansible_dev_sys_url} to ${temp_ansible_dev_sys} ..."
	retry_if_fail git clone ${ansible_dev_sys_url} ${temp_ansible_dev_sys} || exit 1
	cd ${temp_ansible_dev_sys}

	# Get a temporary copy of dev-sys.sh from the temporary ansible-dev-sys.
	temp_dev_sys_script=${temp_ansible_dev_sys}/dev-sys.sh
	dev_sys_script=${assets_dir}/dev-sys.sh
	echo_color ${cyan} "Copying ${temp_dev_sys_script} to ${dev_sys_script} ..."
	cp -f ${tmp_dev_sys_script} ${dev_sys_script}

	# Remove the temporarily ansible-dev-sys.
	echo_color ${cyan} "Removing ${ANSIBLE_DEV_SYS_DIR} ..."
	rm -rf ${ANSIBLE_DEV_SYS_DIR}
else
	dev_sys_script=${ANSIBLE_DEV_SYS_DIR}/dev-sys.sh
fi
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_script}

# Create the SSH keys used to run commands as the dev-sys user.
dev_sys_ssh_key_basename=id_dev-sys
dev_sys_ssh_private_key_file=${assets_dir}/${dev_sys_ssh_key_basename}
dev_sys_ssh_public_key_file=${dev_sys_ssh_private_key_file}.pub
if [ ! -f ${dev_sys_ssh_private_key_file} ]; then
	echo_color ${cyan} "Creating new SSH keys for use by dev-sys ..."
	ssh-keygen -C ${dev_sys_ssh_key_basename} -f ${dev_sys_ssh_private_key_file} -N ""
	set_mode_user_group ${ASSET_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_private_key_file}
	set_mode_user_group ${ASSET_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_public_key_file}
fi
dev_sys_ssh_public_key_contents=$(cat ${dev_sys_ssh_public_key_file})
dev_sys_authorized_keys_file=${dev_user_home_dir}/.ssh/authorized_keys
grep -Fx "${dev_sys_ssh_public_key_contents}" ${dev_sys_authorized_keys_file} > /dev/null
if [ ${?} -ne 0 ]; then
	echo_color ${cyan} "Adding the dev-sys SSH public key to ${dev_sys_authorized_keys_file} ..."
	echo "${dev_sys_ssh_public_key_contents}" >> ${dev_sys_authorized_keys_file}
fi
add_localhost_to_known_hosts_for_user $(whoami)

# Running dev-sys.sh ...
echo_color ${cyan} "Running ${dev_sys_script} '${playbook_name}' as '${DEV_SYS_USER}' ..."
ssh ${DEV_SYS_USER}@127.0.0.1 -i ${dev_sys_ssh_private_key_file} ${dev_sys_script} ${playbook_name}

exit 0

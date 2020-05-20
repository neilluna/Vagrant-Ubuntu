#!/usr/bin/env bash

script_version=1.0.0

script_name=$(basename ${BASH_SOURCE[0]})
script_dir=$(dirname ${BASH_SOURCE[0]})

function echo_usage()
{
	echo "${script_name} - Version ${script_version}"
	echo ""
	echo "Provision a VirtualBox virtual machine."
	echo ""
	echo "Usage: ${script_name} [options]"
	echo ""
	echo "  -h, --help     Output this help information and exit successfully."
	echo "      --version  Output the version and exit successfully."
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
PROVISIONING_DIR_MODE=u+rwx,go-rwx
PROVISIONING_FILE_MODE=u+rw-x,go-rwx
PROVISIONING_SCRIPT_MODE=u+rwx,go-rwx

# Make installations non-interactive.
export DEBIAN_FRONTEND=noninteractive

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

echo_color ${cyan} "Script: '${script_name}', Script directory: '${script_dir}'"
echo_color ${cyan} "Current user: '$(whoami)', Home directory: '${HOME}', Current directory: '$(pwd)'"

dev_user_home_dir=$(eval echo ~${DEV_SYS_USER})
echo_color ${cyan} "dev-sys user: '${DEV_SYS_USER}', Home directory: '${dev_user_home_dir}'"

# Create the provisioning directory.
# This is where dev-sys files and configuration from the host will be stored.
provisioning_dir=${dev_user_home_dir}/.dev-sys-provisioning
create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${provisioning_dir}

aws_provisioning_dir=${provisioning_dir}/aws

# If DEV_SYS_AWS_CONFIG is specifed, create the AWS config file from it.
if [ ! -z "${DEV_SYS_AWS_CONFIG}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${aws_provisioning_dir}
	aws_config_file=${aws_provisioning_dir}/config
	echo_color ${cyan} "Creating ${aws_config_file} ..."
	echo "${DEV_SYS_AWS_CONFIG}" | base64 --decode > ${aws_config_file}
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${aws_config_file}
fi

# If DEV_SYS_AWS_CREDENTIALS is specifed, create the AWS credentials file from it.
if [ ! -z "${DEV_SYS_AWS_CREDENTIALS}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${aws_provisioning_dir}
	aws_credentials_file=${aws_provisioning_dir}/credentials
	echo_color ${cyan} "Creating ${aws_credentials_file} ..."
	echo "${DEV_SYS_AWS_CREDENTIALS}" | base64 --decode > ${aws_credentials_file}
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${aws_credentials_file}
fi

git_provisioning_dir=${provisioning_dir}/git

# If DEV_SYS_ANSIBLE_DEV_SYS_BRANCH is specifed, save it into a config file.
if [ ! -z "${DEV_SYS_ANSIBLE_DEV_SYS_BRANCH}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_provisioning_dir}
	ansible_dev_sys_script=${git_provisioning_dir}/ansible-dev-sys.sh
	echo_color ${cyan} "Creating ${ansible_dev_sys_script} ..."
	cat <<-EOF > ${ansible_dev_sys_script}
	#!/usr/bin/env bash
	export DEV_SYS_ANSIBLE_DEV_SYS_BRANCH=${DEV_SYS_ANSIBLE_DEV_SYS_BRANCH}
	EOF
	set_mode_user_group ${PROVISIONING_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${ansible_dev_sys_script}
fi

# If DEV_SYS_BASH_ENVIRONMENT_BRANCH is specifed, save it into a config file.
if [ ! -z "${DEV_SYS_BASH_ENVIRONMENT_BRANCH}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_provisioning_dir}
	bash_environment_script=${git_provisioning_dir}/bash-environment.sh
	echo_color ${cyan} "Creating ${bash_environment_script} ..."
	cat <<-EOF > ${bash_environment_script}
	#!/usr/bin/env bash
	export DEV_SYS_BASH_ENVIRONMENT_BRANCH=${DEV_SYS_BASH_ENVIRONMENT_BRANCH}
	EOF
	set_mode_user_group ${PROVISIONING_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${bash_environment_script}
fi

# If DEV_SYS_GIT_CONFIG is specifed, create the Git configuration file from it.
if [ ! -z "${DEV_SYS_GIT_CONFIG}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_provisioning_dir}
	git_config_file=${git_provisioning_dir}/gitconfig
	echo_color ${cyan} "Creating ${git_config_file} ..."
	echo "${DEV_SYS_GIT_CONFIG}" | base64 --decode > ${git_config_file}
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_config_file}
fi

# If DEV_SYS_GIT_SSH_PRIVATE_KEY is specifed, create the Git SSH private key file from it.
if [ ! -z "${DEV_SYS_GIT_SSH_PRIVATE_KEY}" ]; then
	create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_provisioning_dir}
	git_ssh_private_key_file=${git_provisioning_dir}/id_git
	echo_color ${cyan} "Creating ${git_ssh_private_key_file} ..."
	echo "${DEV_SYS_GIT_SSH_PRIVATE_KEY}" | base64 --decode > ${git_ssh_private_key_file}
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${git_ssh_private_key_file}
fi

# Get ansible-dev-sys.
ansible_dev_sys_dir=${provisioning_dir}/ansible-dev-sys
if [ -d ${ansible_dev_sys_dir} ]; then
	echo_color ${cyan} "Removing ${ansible_dev_sys_dir} ..."
	rm -rf ${ansible_dev_sys_dir}
fi
ansible_dev_sys_url=https://github.com/neilluna/ansible-dev-sys.git
echo_color ${cyan} "Cloning ${ansible_dev_sys_url} to ${ansible_dev_sys_dir} ..."
retry_if_fail git clone ${ansible_dev_sys_url} ${ansible_dev_sys_dir} || exit 1
cd ${ansible_dev_sys_dir}
git config core.autocrlf false
git config core.filemode false
if [ -f ${ansible_dev_sys_script} ]; then
	echo_color ${cyan} "Sourcing ${ansible_dev_sys_script} ..."
	source ${ansible_dev_sys_script}
	echo_color ${cyan} "Changing to branch ${DEV_SYS_ANSIBLE_DEV_SYS_BRANCH} ..."
	git checkout ${DEV_SYS_ANSIBLE_DEV_SYS_BRANCH}
fi

# Getting dev-sys.sh from ansible-dev-sys.
ansible_dev_sys_script=${ansible_dev_sys_dir}/dev-sys.sh
dev_sys_script=${provisioning_dir}/dev-sys.sh
echo_color ${cyan} "Copying ${ansible_dev_sys_script} to ${dev_sys_script} ..."
cp -f ${ansible_dev_sys_dir}/dev-sys.sh ${dev_sys_script}
set_mode_user_group ${PROVISIONING_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_script}

echo_color ${cyan} "Removing ${ansible_dev_sys_dir} ..."
rm -rf ${ansible_dev_sys_dir}

# Create the dev-sys user provisioning directory.
# This is where dev-sys user related files will be stored.
dev_user_provisioning_dir=${provisioning_dir}/dev-sys-user
create_dir_with_mode_user_group ${PROVISIONING_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP}  ${dev_user_provisioning_dir}

# Create the SSH keys used to run commands as the dev-sys user.
dev_user_ssh_private_key_file=${dev_user_provisioning_dir}/id_dev_user
dev_user_ssh_public_key_file=${dev_user_ssh_private_key_file}.pub
if [ ! -f ${dev_user_ssh_private_key_file} ]; then
	echo_color ${cyan} "Creating new SSH keys for dev-sys user ..."
	ssh-keygen -C id_dev_user -f ${dev_user_ssh_private_key_file} -N ""
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_user_ssh_private_key_file}
	set_mode_user_group ${PROVISIONING_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_user_ssh_public_key_file}
fi
dev_user_ssh_public_key_contents=$(cat ${dev_user_ssh_public_key_file})
dev_user_authorized_keys_file=${dev_user_home_dir}/.ssh/authorized_keys
grep -Fx "${dev_user_ssh_public_key_contents}" ${dev_user_authorized_keys_file} > /dev/null
if [ ${?} -ne 0 ]; then
	echo_color ${cyan} "Adding the new dev-sys user SSH public key to ${dev_user_authorized_keys_file} ..."
	echo "${dev_user_ssh_public_key_contents}" >> ${dev_user_authorized_keys_file}
fi
add_localhost_to_known_hosts_for_user $(whoami)

echo_color ${cyan} "Running ${dev_sys_script} as '${DEV_SYS_USER}' ..."
ssh -t ${DEV_SYS_USER}@127.0.0.1 -i ${dev_user_ssh_private_key_file} ${dev_sys_script}

exit 0

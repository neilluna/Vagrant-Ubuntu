#!/usr/bin/env bash

script_version=0.1.0

script_name=$(basename ${BASH_SOURCE[0]})
script_dir=$(dirname ${BASH_SOURCE[0]})
script_path=${BASH_SOURCE[0]}

function echo_usage()
{
	echo "${script_name} - Version ${script_version}"
	echo ""
	echo "Provision a VirtualBox virtual machine."
	echo ""
	echo "Usage: ${script_name} [options]"
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

# Echo an informational message.
# Usage: echo_info message
function echo_info()
{
	message=${1}
	echo -e "${cyan}${message}${reset}"
}

# Echo a warning message.
# Usage: echo_warning message
function echo_warning()
{
	message=${1}
	echo -e "${yellow}${message}${reset}"
}

# Echo an error message.
# Usage: echo_error message
function echo_error()
{
	message=${1}
	echo -e "${red}${message}${reset}"
}

# Echo an error message and exit.
# Usage: echo_error_and_exit message
function echo_error_and_exit()
{
	echo_error "${1}"
	exit 1
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
# If created, then set the mode, user, and group of the new directory.
# Usage: create_dir_with_mode_user_group mode user group dir
function create_dir_with_mode_user_group()
{
	mode=${1}
	user=${2}
	group=${3}
	dir=${4}
	[ -d ${dir} ] && return
	echo_info "Creating ${dir} ..."
	sudo mkdir -p ${dir}
	sudo chmod ${mode} ${dir}
	sudo chown ${user}:${group} ${dir}
}

# Check if a program exists and is executable by this user.
# Echoes an error message and exits the script if the program does not exist or is not executable by this user.
# Usage: check_program program
function check_program()
{
	program=${1}
	full_path=$(which ${program})
	if [ -z "${full_path}" ] || [ ! -x "${full_path}" ]; then
		echo_error_and_exit "Cannot execute '${program}'."
	fi
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
			echo_warning "'${*}' failed. Will retry in ${retry_wait} seconds."
			sleep ${retry_wait}
			echo_info "Retrying '${*}' (${retry} of ${max_retries}) ..."
			${*} && break
			retry=$[$retry + 1]
		done
		if [ ${retry} -gt ${max_retries} ]; then
			echo_error_and_exit "'${*}' failed after $[$max_retries + 1] attempts."
		fi
	fi
}

# Provision directory and file modes.
# Keeps things very private.
# Along with other things, these modes are also used for private keys and credentials.
ASSET_DIR_MODE=u+rwx,go-rwx
ASSET_FILE_MODE=u+rw-x,go-rwx
ASSET_SCRIPT_MODE=u+rwx,go-rwx

# Use these variables instead of the string "root". "root" can be renamed.
ROOT_UID=0
ROOT_GID=0

# Command-line switch variables.
verbose=no

# NOTE: This requires GNU getopt. On Mac OS X and FreeBSD, you have to install this separately.
ARGS=$(getopt -o h -l help,version -n ${script_name} -- "${@}")
if [ ${?} -ne 0 ]; then
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
if [ ${#} -gt 0 ]; then
	echo "${script_name}: Error: Invalid argument: ${1}" >&2
	echo_usage
	exit 1
fi

echo_info "Script: ${script_path}"
echo_info "Current user: $(whoami)"
echo_info "Home directory: ${HOME}"
echo_info "Current directory: $(pwd)"

dev_user_home_dir=$(eval echo ~${DEV_SYS_USER})
echo_info "DEV_SYS user: ${DEV_SYS_USER}"
echo_info "DEV_SYS group: ${DEV_SYS_GROUP}"
echo_info "DEV_SYS home directory: ${dev_user_home_dir}"

# Make installations non-interactive.
export DEBIAN_FRONTEND=noninteractive

# Do not buffer Python stdout.
export PYTHONUNBUFFERED=TRUE

# Create the dev-sys assets directory.
assets_dir=${dev_user_home_dir}/.dev-sys
create_dir_with_mode_user_group ${ASSET_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${assets_dir}

echo_info "Checking dependencies ..."
check_program ssh
check_program ssh-keygen
check_program ssh-keyscan

# Create the SSH directory.
dev_sys_ssh_dir=${dev_user_home_dir}/.ssh
create_dir_with_mode_user_group ${ASSET_DIR_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_dir}

# Create the SSH keys used to run commands as the dev-sys user.
dev_sys_ssh_key_basename=id_dev-sys
dev_sys_ssh_private_key_file=${assets_dir}/${dev_sys_ssh_key_basename}
dev_sys_ssh_public_key_file=${assets_dir}/${dev_sys_ssh_key_basename}.pub
if [ ! -f ${dev_sys_ssh_private_key_file} ]; then
	echo_info "Creating new SSH keys for use by dev-sys ..."
	ssh-keygen -C ${dev_sys_ssh_key_basename} -f ${dev_sys_ssh_private_key_file} -N ""
	set_mode_user_group ${ASSET_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_private_key_file}
	set_mode_user_group ${ASSET_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_public_key_file}
fi
dev_sys_ssh_public_key_contents=$(cat ${dev_sys_ssh_public_key_file})
dev_sys_ssh_authorized_keys_file=${dev_sys_ssh_dir}/authorized_keys
if [ ! -f ${dev_sys_ssh_authorized_keys_file} ]; then
	touch ${dev_sys_ssh_authorized_keys_file}
	set_mode_user_group ${ASSET_FILE_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_ssh_authorized_keys_file}
fi
grep -Fx "${dev_sys_ssh_public_key_contents}" ${dev_sys_ssh_authorized_keys_file} > /dev/null
if [ ${?} -ne 0 ]; then
	echo_info "Adding the dev-sys SSH public key to ${dev_sys_ssh_authorized_keys_file} ..."
	echo "${dev_sys_ssh_public_key_contents}" >> ${dev_sys_ssh_authorized_keys_file}
fi

# Adds 127.0.0.1 to the known_hosts file.
# This will avoid prompts when Ansible uses SSH to provison the local host.
dev_sys_ssh_known_hosts_file=${HOME}/.ssh/known_hosts
if [ ! -f ${dev_sys_ssh_known_hosts_file} ]; then
	echo_info "Creating ${dev_sys_ssh_known_hosts_file} ..."
	touch ${dev_sys_ssh_known_hosts_file}
	chmod u+rw-x,go+r-wx ${dev_sys_ssh_known_hosts_file}
fi
ssh-keygen -F 127.0.0.1 -f ${dev_sys_ssh_known_hosts_file} > /dev/null 2>&1
if [ ${?} -ne 0 ]; then
	echo_info "Adding the local host's SSH fingerprint to ${dev_sys_ssh_known_hosts_file} ..."
	ssh-keyscan -H 127.0.0.1 >> ${dev_sys_ssh_known_hosts_file} || exit 1
fi

echo_info "Checking SSH connectivity to the local host ..."
ssh ${DEV_SYS_USER}@127.0.0.1 -i ${dev_sys_ssh_private_key_file} echo Ok || exit 1

echo_info "Running apt-get update ..."
retry_if_fail sudo apt-get update --yes

echo_info "Running apt-get upgrade ..."
retry_if_fail sudo apt-get upgrade --yes

echo_info "Installing or updating software-properties-common ..."
retry_if_fail sudo apt-get install --yes software-properties-common

echo_info "Installing or updating git ..."
retry_if_fail sudo apt-get install --yes git

# If ANSIBLE_DEV_SYS_DIR is set, then assume that ansible-dev-sys is being managed by the host.
if [ ! -z "${ANSIBLE_DEV_SYS_DIR}" ]; then
	ANSIBLE_DEV_SYS_MANAGED_EXTERNALLY=true
else
	ANSIBLE_DEV_SYS_DIR=${assets_dir}/ansible-dev-sys
	ANSIBLE_DEV_SYS_MANAGED_EXTERNALLY=false
fi

# Save the ansible-dev-sys variables into a script for later use.
ansible_dev_sys_vars_script=${assets_dir}/ansible-dev-sys-vars.sh
echo_info "Creating ${ansible_dev_sys_vars_script} ..."
cat << EOF > ${ansible_dev_sys_vars_script}
#!/usr/bin/env bash
ANSIBLE_DEV_SYS_DIR=${ANSIBLE_DEV_SYS_DIR}
ANSIBLE_DEV_SYS_MANAGED_EXTERNALLY=${ANSIBLE_DEV_SYS_MANAGED_EXTERNALLY}
EOF
if [ ! -z "${ANSIBLE_DEV_SYS_VERSION}" ]; then
	echo "ANSIBLE_DEV_SYS_VERSION=${ANSIBLE_DEV_SYS_VERSION}" >> ${ansible_dev_sys_vars_script}
fi
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${ansible_dev_sys_vars_script}

# If BASH_ENVIRONMENT_DIR is set, then assume that bash-environment is being managed by the host.
if [ ! -z "${BASH_ENVIRONMENT_DIR}" ]; then
	BASH_ENVIRONMENT_MANAGED_EXTERNALLY=true
else
	BASH_ENVIRONMENT_DIR=${assets_dir}/bash-environment
	BASH_ENVIRONMENT_MANAGED_EXTERNALLY=false
fi

# Save the bash-environment variables into a script for later use.
bash_environment_vars_script=${assets_dir}/bash-environment-vars.sh
echo_info "Creating ${bash_environment_vars_script} ..."
cat << EOF > ${bash_environment_vars_script}
#!/usr/bin/env bash
BASH_ENVIRONMENT_DIR=${BASH_ENVIRONMENT_DIR}
BASH_ENVIRONMENT_MANAGED_EXTERNALLY=${BASH_ENVIRONMENT_MANAGED_EXTERNALLY}
EOF
if [ ! -z "${BASH_ENVIRONMENT_VERSION}" ]; then
	echo "BASH_ENVIRONMENT_VERSION=${BASH_ENVIRONMENT_VERSION}" >> ${bash_environment_vars_script}
fi
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${bash_environment_vars_script}

# If ansible-dev-sys does not exists, then temporarily clone it and get a copy of its dev-sys.sh.
if [ ! -d ${ANSIBLE_DEV_SYS_DIR} ]; then
	# Temporarily clone ansible-dev-sys.
	tmp_ansible_dev_sys_dir=${assets_dir}/tmp-ansible-dev-sys
	ansible_dev_sys_url=https://github.com/neilluna/ansible-dev-sys.git
	echo_info "Cloning ${ansible_dev_sys_url} to ${tmp_ansible_dev_sys_dir} ..."
	retry_if_fail git clone ${ansible_dev_sys_url} ${tmp_ansible_dev_sys_dir}
	if [ ! -z "${ANSIBLE_DEV_SYS_VERSION}" ]; then
		pushd ${tmp_ansible_dev_sys_dir} > /dev/null
		echo_info "Switching to branch ${ANSIBLE_DEV_SYS_VERSION} ..."
		git checkout ${ANSIBLE_DEV_SYS_VERSION} || exit 1
		popd > /dev/null
	fi

	# Get a temporary copy of dev-sys.sh from the temporary ansible-dev-sys, for use by this script.
	tmp_dev_sys_script=${tmp_ansible_dev_sys_dir}/dev-sys.sh
	vagrant_dev_sys_script=${assets_dir}/vagrant-dev-sys.sh
	echo_info "Copying ${tmp_dev_sys_script} to ${vagrant_dev_sys_script} ..."
	cp -f ${tmp_dev_sys_script} ${vagrant_dev_sys_script}
	dev_sys_script=${vagrant_dev_sys_script}

	# Remove the temporarily ansible-dev-sys.
	echo_info "Removing ${tmp_ansible_dev_sys_dir} ..."
	rm -rf ${tmp_ansible_dev_sys_dir}
else
	dev_sys_script=${ANSIBLE_DEV_SYS_DIR}/dev-sys.sh
fi
set_mode_user_group ${ASSET_SCRIPT_MODE} ${DEV_SYS_USER} ${DEV_SYS_GROUP} ${dev_sys_script}

# Run dev-sys.sh.
ssh_command="ssh ${DEV_SYS_USER}@127.0.0.1 -i ${dev_sys_ssh_private_key_file}"
ssh_command="${ssh_command} ${dev_sys_script}"
[ ! -z "${ANSIBLE_DEV_SYS_TAGS}" ] && ssh_command="${ssh_command} ${ANSIBLE_DEV_SYS_TAGS}"
echo_info "Running ${dev_sys_script} as ${DEV_SYS_USER} ..."
${ssh_command} || exit 1

if [ ! -z "${vagrant_dev_sys_script}" ]; then
	# Echo a leading newline to separate this echo from the output of ansible-dev-sys.
	echo_info "\nRemoving ${vagrant_dev_sys_script} ..."
	rm -f ${vagrant_dev_sys_script}
fi

exit 0

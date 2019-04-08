#!/bin/bash

# This script will one-way synchronize the project directory to or from a VM. If the project directory is synchronized
# to the VM, the 'set-permissions.sh' script will be run on the VM.

# This script should only be run on the host.

script_name=$(basename ${BASH_SOURCE[0]})

echo_usage() {
	echo "This script will one-way synchronize the project directory to or from a VM."
	echo
	echo "Usage: ${script_name} [-h] [-d] [-p] [-r] [-v] -t target-vm-name"
	echo
	echo "  -h  Show this help information."
	echo "  -d  Delete remote files which do not exist locally."
	echo "  -p  Run the 'set-permissions.sh' scripts on the VM after the sync."
	echo "  -r  Reverse. Sync is done from the VM to the host. Note: The"
	echo "      'set-permissions.sh' script will not be run."
	echo "  -t  The target VM name. This is required."
	echo "  -v  Verbose output."
	echo ""
	echo "      Note: Options -d and -r cannot both be specified."
}

opt_delete=no
opt_permissions=no
opt_reverse=no
opt_target=
opt_verbose=no

while getopts ":hdprt:v" opt; do
	case "${opt}" in
		h)
			echo_usage
			exit 0
			;;
		d)
			opt_delete=yes
			;;
		p)
			opt_permissions=yes
			;;
		r)
			opt_reverse=yes
			;;
		t)
			opt_target=${OPTARG}
			;;
		v)
			opt_verbose=yes
			;;
		\?)
			echo "${script_name}: Error: Invalid option: -${OPTARG}" >&2
			echo_usage
			exit 1
			;;
		:)
			echo "${script_name}: Error: Option -${OPTARG} requires an argument." >&2
			echo_usage
			exit 1
			;;
	esac
done

if [ ${opt_reverse} == yes -a ${opt_delete} == yes ]; then
	echo "${script_name}: Error: Options -d and -r cannot both be specified." >&2
	echo_usage
	exit 1
fi

if [ "${opt_target}" == "" ]; then
	echo "${script_name}: Error: Option -t is required." >&2
	echo_usage
	exit 1
fi

# Remove the temporary identity file and exit with the given return code.
cleanup_and_exit () {
	[ "${temp_identity_file}" != "" ] && rm -f ${temp_identity_file}
	exit ${1}
}

# Change to the project directory.
# This script assumes that the project directory is only one directory level up from this script's directory.
cd $(dirname ${BASH_SOURCE[0]})/..

echo Parsing: vagrant ssh-config ${opt_target}
temp_file=$(mktemp -t ${script_name}.XXXXXXXXXX)
vagrant ssh-config ${opt_target} > ${temp_file}
if [ ${?} -ne 0 ]; then
	rm -f ${temp_file}
	exit 1
fi
while read -r line; do
	line=$(echo ${line} | sed 's/\r$//')
	var=$(echo ${line} | cut -f1 -d' ')
	val=$(echo ${line} | cut -f2- -d' ' | sed 's/^"//' | sed 's/"$//')
	[[ ${var} =~ ^[A-Za-z] ]] && declare "ssh_config_${var}"="${val}"
done < ${temp_file}
rm -f ${temp_file}

# Compose the rsync options.
common_rsync_args="-lrtz --exclude-from=bin.host-only/synced-folder-exclude"
[ ${opt_verbose} == yes ] && common_rsync_args="${common_rsync_args} -Pv"
push_rsync_args="--chown=${ssh_config_User}:${ssh_config_User}"
[ ${opt_delete} == yes ] && push_rsync_args="${push_rsync_args} --delete"
pull_rsync_args=

# Fix the ssh_config_IdentityFile path for Windows.
temp_identity_file=
if [ ! -z "$(uname -s | grep -i cygwin)" ]; then
	ssh_config_IdentityFile=$(cygpath -ua ${ssh_config_IdentityFile})
	# Copy the identity file so that we can tighten its permissions for SSH use.
	temp_identity_file=$(mktemp ~/.ssh/${script_name}.XXXXXXXXXX)
	cat ${ssh_config_IdentityFile} >> ${temp_identity_file}
	chmod u+rw-x,go-rwx ${temp_identity_file}
	ssh_config_IdentityFile=${temp_identity_file}
elif [ ! -z "$(uname -s | grep -i mingw32)" ]; then
	echo "${script_name}: Error: The mingw32 environment is not supported." >&2
	exit 1
fi

export RSYNC_RSH="ssh \
  -i ${ssh_config_IdentityFile} \
  -p ${ssh_config_Port} \
  -o LogLevel=ERROR \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null"

user_at_host=${ssh_config_User}@${ssh_config_HostName}

# Now let's actually do the rsync
if [ ${opt_reverse} == no ]; then
	echo "Syncing host to ${opt_target} ..."
	rsync ${common_rsync_args} ${push_rsync_args} . ${user_at_host}:/vagrant || cleanup_and_exit 1
	if [ ${opt_permissions} == yes ]; then
		echo "Setting permissions on ${opt_target} ..."
		${RSYNC_RSH} ${user_at_host} 'chmod u+rwx,go+rx-w /vagrant/bin.vm-only/set-permissions.sh' || cleanup_and_exit 1
		${RSYNC_RSH} ${user_at_host} '/vagrant/bin.vm-only/set-permissions.sh' || cleanup_and_exit 1
	fi
else
	echo "Syncing ${opt_target} to host ..."
	rsync ${common_rsync_args} ${pull_rsync_args} ${user_at_host}:/vagrant/ . || cleanup_and_exit 1
fi

cleanup_and_exit 0

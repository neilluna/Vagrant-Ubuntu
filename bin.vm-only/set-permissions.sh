#!/usr/bin/env bash

set -e # Error out on any command not returning 0.
set -u # Error out on the use of any undefined variables.

# This script will set the file permissions on all files and directories in
# the project directory tree.

# This is done because Windows tools (Tortoise, SourceTree, cygwin, etc) are
# not consistent between each other about presenting and handling Linux file
# permissions on Windows. Therefore, Linux file permissions on Windows should
# not be trusted and should be ignored. File permissions should be explicitly
# set by this script to whatever is needed.

# If using git, It is best to turn filemode off within your repo using
# 'git config core.filemode false'.

# This script should only be run on the VM. It is called from both
# 'provision-vagrant.sh' and 'sync-vm.sh' on the VM's project directory.

echo_usage() { 
	echo "This script will set the file permissions on all files and"
	echo "directories in the project directory tree."
	echo
	echo "Usage: $(basename ${0}) [-h]"
	echo
	echo "   -h Show this help information."
} 

while getopts ":h" opt; do
	case "${opt}" in
		h)
			echo_usage ${0}
			exit 0
			;;
		\?)
			echo "${0}: Error: Invalid option: -${OPTARG}" >&2
			echo_usage ${0}
			exit 1
			;;
	esac
done

# Apply the excludes to the file list on stdin.
# chmod the files in the final list.
# Parameter is a chmod mode to apply to the files in the final list.
exclude_and_chmod() { 
	rm -f ${temp_dir}/names
	while read -r data; do
		echo "${data}" >> ${temp_dir}/names
	done
	while read -r line; do
		grep -Pv ${line} ${temp_dir}/names > ${temp_dir}/names.new
		mv -f ${temp_dir}/names.new ${temp_dir}/names
	done < ${temp_dir}/exclude
	while read -r line; do
		chmod ${1} "${line}"
	done < ${temp_dir}/names
} 

# Change to the Vagrant synced_folder directory.
cd /vagrant

temp_dir=$(mktemp -dt "$(basename ${0}).XXXXXXXXXX")

# Filter out blank lines and comments.
egrep -v '^[[:space:]]*(#.*)?$' bin.vm-only/set-permissions-exclude > ${temp_dir}/exclude

# Permission changers.
find . -type d ! -name '.'  | exclude_and_chmod u+rwx,go+rx-w
find . -type f              | exclude_and_chmod u+rw-x,go+r-wx
# find . -type f -name '*.py' | exclude_and_chmod u+rwx,go+rx-w
find . -type f -name '*.sh' | exclude_and_chmod u+rwx,go+rx-w

rm -rf ${temp_dir}

exit 0

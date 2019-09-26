#!/bin/bash
## {{ ansible_managed }}
set -ex
name=$2
profile=$(cobbler system dumpvars --name $2 | grep profile_name | cut -d ':' -f2)
export USER=root
export HOME=/root
ANSIBLE_CM_PATH=/root/ceph-cm-ansible
SECRETS_REPO_NAME={{ secrets_repo.name }}

# Bail if the ssh port isn't open, as will be the case when this is run 
# while the installer is still running. When this is triggered by 
# /etc/rc.local after a reboot, the port will be open and we'll continue
nmap -sT -oG - -p 22 $name | grep 22/open

mkdir -p /var/log/ansible

if [ $SECRETS_REPO_NAME != 'UNDEFINED' ]
then
    ANSIBLE_SECRETS_PATH=/root/$SECRETS_REPO_NAME
    pushd $ANSIBLE_SECRETS_PATH
    flock --close ./.lock git pull
    popd
fi
pushd $ANSIBLE_CM_PATH
flock --close ./.lock git pull
export ANSIBLE_SSH_PIPELINING=1
export ANSIBLE_HOST_KEY_CHECKING=False

# Set ansible_python_interpeter var if RHEL8
# https://docs.ansible.com/ansible/2.7/reference_appendices/python_3_support.html
os=$(cobbler system dumpvars --name $2 | grep os_version | awk '{ print $3 }')
if [ $os == "rhel8" -o $os == "centos8" ]; then
  # Nagios packages aren't available in the CentOS/RHEL8 yet so we'll skip those tasks
  ANSIBLE_EXTRAVAR="-e ansible_python_interpreter=/usr/bin/python3 --skip-tags nagios"
else
  ANSIBLE_EXTRAVAR=""
fi

# Tell ansible to create users, populate authorized_keys, and zap non-root disks
ansible-playbook $ANSIBLE_EXTRAVAR testnodes.yml -v --limit $name* --tags user,pubkeys,zap 2>&1 > /var/log/ansible/$name.log
# Now run the rest of the playbook. If it fails, at least we have access.
# Background it so that the request doesn't block for this part and end up 
# causing the client to retry, thus spawning this trigger multiple times

# Skip the rest of the testnodes playbook if stock profile requested
if [[ $profile == *"-stock" ]]
then
    exit 0
fi
ansible-playbook $ANSIBLE_EXTRAVAR testnodes.yml -v --limit $name* --skip-tags user,pubkeys,zap 2>&1 >> /var/log/ansible/$name.log &
popd

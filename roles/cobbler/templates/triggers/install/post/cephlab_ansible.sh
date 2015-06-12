#!/bin/bash
## {{ ansible_managed }}
set -ex
name=$2
export USER=root
export HOME=/root
ANSIBLE_CM_PATH=/root/ceph-cm-ansible

# Bail if the ssh port isn't open, as will be the case when this is run 
# while the installer is still running. When this is triggered by 
# /etc/rc.local after a reboot, the port will be open and we'll continue
nmap -sT -oG - -p 22 $name | grep 22/open

mkdir -p /var/log/ansible

pushd $ANSIBLE_CM_PATH
export ANSIBLE_SSH_PIPELINING=1
# Tell ansible to create users and populate authorized_keys
ansible-playbook testnodes.yml -v --limit $name* --tags user,pubkeys 2>&1 > /var/log/ansible/$name.log
# Now run the rest of the playbook. If it fails, at least we have access.
# Background it so that the request doesn't block for this part and end up 
# causing the client to retry, thus spawning this trigger multiple times
ansible-playbook testnodes.yml -v --limit $name* --skip-tags user,pubkeys 2>&1 >> /var/log/ansible/$name.log &
popd

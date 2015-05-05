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
nc -vz $name 22

mkdir -p /var/log/ansible

pushd $ANSIBLE_CM_PATH
export ANSIBLE_SSH_PIPELINING=1
# Tell ansible to create users and populate authorized_keys
ansible-playbook testnodes.yml -v --limit $name* --tags user,pubkeys 2>&1 > /var/log/ansible/$name.log
# Now run the rest of the playbook. If it fails, at least we have access.
ansible-playbook testnodes.yml -v --limit $name* --skip-tags user,pubkeys 2>&1 >> /var/log/ansible/$name.log
popd

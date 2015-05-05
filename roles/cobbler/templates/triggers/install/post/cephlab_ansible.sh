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

# Tell ansible to create users and populate authorized_keys
pushd $ANSIBLE_CM_PATH
ANSIBLE_SSH_PIPELINING=1 ansible-playbook testnodes.yml -vv --limit $name* --tags user,pubkeys 2>&1 | tee /var/log/ansible/$name.log
popd

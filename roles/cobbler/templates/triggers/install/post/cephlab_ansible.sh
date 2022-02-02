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

# Set up Stream repos
# We have to do it this way because
# 1) Stream ISOs don't work with Cobbler https://bugs.centos.org/view.php?id=18188
# 2) Since we use a non-stream profile then convert it to stream, we can't run any package related tasks
#    until the stream repo files are in place. e.g., The zap ansible tag has some package tasks that fail
#    unless we get the repos in place first.
if [[ $profile == *"8.stream"* ]]
then
    ansible-playbook tools/convert-to-centos-stream.yml -v --limit $name* 2>&1 >> /var/log/ansible/$name.log
elif [[ $profile == *"9.stream"* ]]
then
    # For some reason, we end up with no repos on the first boot without doing this.
    ansible-playbook testnodes.yml --tags repos -v --limit $name* 2>&1 >> /var/log/ansible/$name.log
fi

# Tell ansible to create users, populate authorized_keys, and zap non-root disks
ansible-playbook testnodes.yml -v --limit $name* --tags user,pubkeys,zap 2>&1 > /var/log/ansible/$name.log
# Now run the rest of the playbook. If it fails, at least we have access.
# Background it so that the request doesn't block for this part and end up 
# causing the client to retry, thus spawning this trigger multiple times

# Skip the rest of the testnodes playbook if stock profile requested
if [[ $profile == *"-stock" ]]
then
    exit 0
fi
ansible-playbook cephlab.yml -v --limit $name* --skip-tags user,pubkeys,zap 2>&1 >> /var/log/ansible/$name.log &
popd

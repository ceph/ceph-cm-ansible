#!/bin/bash
# Switches your ansible inventory between ceph-sepia-secrets or ceph-octo-secrets

val=$(ls -lah /etc/ansible/secrets | grep -c "octo")
if [ $val -eq 1 ]; then
        sudo rm /etc/ansible/secrets
        sudo ln -s ~/git/ceph/ceph-sepia-secrets/ansible/secrets /etc/ansible/secrets
        sudo rm /etc/ansible/hosts
        sudo ln -s ~/git/ceph/ceph-sepia-secrets/ansible/inventory /etc/ansible/hosts
        cat ~/.teuthology.yaml.sepia > ~/.teuthology.yaml
elif [ $val -eq 0 ]; then
        sudo rm /etc/ansible/secrets
        sudo ln -s ~/git/ceph/ceph-octo-secrets/ansible/secrets /etc/ansible/secrets
        sudo rm /etc/ansible/hosts
        sudo ln -s ~/git/ceph/ceph-octo-secrets/ansible/inventory /etc/ansible/hosts
        cat ~/.teuthology.yaml.octo > ~/.teuthology.yaml
fi

#!/bin/bash
# Modifies dhcp config file to add or remove a next-server and filename
# The fog next-server and filename are the default for all DHCP hosts so
# entering 'cobbler' for $2 adds its next-server and filename.
# Setting 'fog' for $2 just removes it so the host entry uses the global default.
#
# This script should live on your workstation somewhere executable.
#
# It also assumes you are using tools/switch-secrets to switch between
# octo an sepia ansible inventories

if [ $# -ne 2 ]; then
  echo "Usage: $(basename $0) hostname [cobbler|fog]"
  echo
  echo "Example: \`$(basename $0) mira042 cobbler\` would add Cobbler's next-server and filename to mira042's DHCP entry"
  echo
  exit 1
elif [ "$2" != "cobbler" ] && [ "$2" != "fog" ]; then
  echo "Unrecognized option $2.  Must use 'cobbler' or 'fog'"
  exit 1
else
  host=$(echo $1 | cut -d '.' -f1)
fi
ls -lah /etc/ansible/hosts | grep -q octo
if [ $? -eq 0 ]
then
  dhcp_server="magna001.ceph.redhat.com"
else
  dhcp_server="store01.front.sepia.ceph.com"
fi

set -x

ssh $dhcp_server "sudo /usr/local/sbin/set-next-server.sh $host $2 && sudo service dhcpd restart"

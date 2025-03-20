#!/bin/bash
# Modifies dhcp config file to add or remove a next-server and filename
# The fog next-server and filename are the default for all DHCP hosts so
# entering 'cobbler' for $2 adds its next-server and filename.
# Setting 'fog' for $2 just removes it so the host entry uses the global default.
#
# This script should live on the DHCP server somewhere executable
#
# NOTE: DHCP entries *must* be in the following format
# (dhcp-server role write entries like this)
#
# host foo-front {
#   hardware ethernet aa:bb:cc:11:22:33;
#   fixed-address 1.2.3.4;
# }

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

set -x

dhcpconfig="/etc/dhcp/dhcpd.front.conf"
timestamp=$(date +%s)
cobblerip="172.21.0.11"
cobblerfilename="/pxelinux.0"
fogip="172.21.0.72"
fogfilename="/undionly.kpxe"
macaddr=$(sed -n "/host ${host}-front/,/}/p" $dhcpconfig | grep 'hardware ethernet' | awk '{ print $3 }' | tr -d ';')
ipaddr=$(sed -n "/host ${host}-front/,/}/p" $dhcpconfig | grep 'fixed-address' | awk '{ print $2 }' | tr -d ';')
linenum=$(grep -n $host $dhcpconfig | grep -v "host-name" | cut -d ':' -f1)

if [ -z "$macaddr" ]; then
  echo "No MAC address found for $host"
  exit 1
elif [ -z "$ipaddr" ]; then
  echo "No IP address found for $host"
  exit 1
elif [ -z "$linenum" ]; then
  echo "Unable to determine line number for $host entry"
  exit 1
fi

# Back up dhcp config
cp $dhcpconfig ${dhcpconfig}_$timestamp.bak

# Delete
sed -i "/host ${host}-front {/,/}/d" $dhcpconfig

if [ "$2" == "cobbler" ]; then
  sed -i "${linenum} i \  host ${host}-front {\n\    hardware ethernet $macaddr;\n\    fixed-address $ipaddr;\n\    next-server $cobblerip;\n\    filename \"$cobblerfilename\";\n\  }" $dhcpconfig
elif [ "$2" == "fog" ]; then
  sed -i "${linenum} i \  host ${host}-front {\n\    hardware ethernet $macaddr;\n\    fixed-address $ipaddr;\n\    next-server $fogip;\n\    filename \"$fogfilename\";\n\  }" $dhcpconfig
fi

dhcpd -q -t -cf $dhcpconfig

if [ $? != 0 ]; then
  mv $dhcpconfig ${dhcpconfig}_$timestamp.broken
  mv ${dhcpconfig}_$timestamp.bak $dhcpconfig
  echo "New config failed config test.  Restored backup."
  exit 1
else
  rm ${dhcpconfig}_$timestamp.bak
#  service dhcpd restart
fi

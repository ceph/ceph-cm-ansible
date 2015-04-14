#!/bin/bash
## {{ ansible_managed }}

dontrun=$(grep -ic inet\ static /etc/network/interfaces)
if [ $dontrun -eq 0 ]
then
cidr=$(ip addr show dev eth0 | grep -iw inet | awk '{print $2}')
ip=$(echo $cidr | cut -d'/' -f1)
miracheck=$(uname -n | grep -ic mira)
armcheck=$(uname -m | grep -ic arm)
netmask=$(ipcalc $cidr | grep -i netmask | awk '{print $2}')
gateway=$(route -n | grep ^0.0 | awk '{print $2}')
broadcast=$(ipcalc $cidr | grep -i broad | awk '{print $2}')
octet1=$(echo $ip | cut -d'.' -f1)
octet2=$(echo $ip | cut -d'.' -f2)
octet3=$(echo $ip | cut -d'.' -f3)
octet4=$(echo $ip | cut -d'.' -f4)
octet3=$(($octet3 + 13))
if [ $armcheck -gt 0 ]
then
dev=eth1
else
dev=eth2
fi
if [ $miracheck -gt 0 ]
then
sed -i "s/iface eth0 inet dhcp/\
iface eth0 inet static\n\
    address $ip\n\
    netmask $netmask\n\
    gateway $gateway\n\
    broadcast $broadcast\n\
\n\
/g" /etc/network/interfaces
else
typicacheck=$(uname -n | grep -ic typica)
if [ $typicacheck -gt 0 ]
then
sed -i "s/iface eth0 inet dhcp/\
iface eth0 inet static\n\
    address $ip\n\
    netmask $netmask\n\
    gateway $gateway\n\
    broadcast $broadcast\n\
    up route add -net 10.99.118.0\/24 gw 172.20.133.1 dev eth0\n\
    up route add -net 10.214.128.0\/20 gw 172.20.133.1 dev eth0\n\
    up route add -net 10.214.0.0\/20 gw 172.20.133.1 dev eth0\n\
\n\
/g" /etc/network/interfaces
else
sed -i "s/iface eth0 inet dhcp/\
iface eth0 inet static\n\
    address $ip\n\
    netmask $netmask\n\
    gateway $gateway\n\
    broadcast $broadcast\n\
\n\
auto $dev\n\
iface $dev inet static\n\
    address $octet1.$octet2.$octet3.$octet4\n\
    netmask $netmask\
/g" /etc/network/interfaces
fi
fi
fi
touch /static-ip-setup

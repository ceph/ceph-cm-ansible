#!/bin/bash
# {{ ansible_managed }}

set -e
f=/etc/default/grub
#Mira are ttyS2
miracheck=$(uname -n | grep -ic mira || true)
typicacheck=$(uname -n | grep -ic typica || true)
# if it has a setting, make sure it's to ttyS1
if [ $miracheck -gt 0 ]
then
if grep -q '^GRUB_CMDLINE_LINUX=.*".*console=tty0 console=ttyS[012],115200' $f; then sed 's/console=ttyS[012]/console=ttyS2/' <$f >$f.chef; fi
else
if [ $typicacheck -gt 0 ]
then
if grep -q '^GRUB_CMDLINE_LINUX=.*".*console=tty0 console=ttyS[012],115200' $f; then sed 's/console=ttyS[012]/console=ttyS0/' <$f >$f.chef; fi
else
if grep -q '^GRUB_CMDLINE_LINUX=.*".*console=tty0 console=ttyS[01],115200' $f; then sed 's/console=ttyS[01]/console=ttyS1/' <$f >$f.chef; fi
fi
fi

# if it has no setting, add it
if [ $miracheck -gt 0 ]
then
if ! grep -q '^GRUB_CMDLINE_LINUX=.*".* console=tty0 console=ttyS[012],115200.*' $f; then sed 's/^GRUB_CMDLINE_LINUX="\(.*\)"$/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS2,115200"/' <$f >$f.chef; fi
else
if [ $typicacheck -gt 0 ]
then
if ! grep -q '^GRUB_CMDLINE_LINUX=.*".* console=tty0 console=ttyS[012],115200.*' $f; then sed 's/^GRUB_CMDLINE_LINUX="\(.*\)"$/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS0,115200"/' <$f >$f.chef; fi
else
if ! grep -q '^GRUB_CMDLINE_LINUX=.*".* console=tty0 console=ttyS[01],115200.*' $f; then sed 's/^GRUB_CMDLINE_LINUX="\(.*\)"$/GRUB_CMDLINE_LINUX="\1 console=tty0 console=ttyS1,115200"/' <$f >$f.chef; fi
fi
fi


# if we did something; move it into place.  update-grub done below.
if [ -f $f.chef ] ; then mv $f.chef $f; fi

#Remove quiet kernel output:
sed -i 's/quiet//g' $f
serialcheck=$(grep -ic serial $f || true)
if [ $serialcheck -eq 0 ]
then
if [ $miracheck -gt 0 ]
then
echo "" >> $f
echo "GRUB_TERMINAL=serial" >> $f
echo "GRUB_SERIAL_COMMAND=\"serial --unit=2 --speed=115200 --stop=1\"" >> $f
else
if [ $typicacheck -gt 0 ]
then
echo "" >> $f
echo "GRUB_TERMINAL=serial" >> $f
echo "GRUB_SERIAL_COMMAND=\"serial --unit=0 --speed=115200 --stop=1\"" >> $f
else
echo "" >> $f
echo "GRUB_TERMINAL=serial" >> $f
echo "GRUB_SERIAL_COMMAND=\"serial --unit=1 --speed=115200 --stop=1\"" >> $f
fi
fi
fi

#Don't hide grub menu

sed -i 's/^GRUB_HIDDEN_TIMEOUT.*//g' $f

#No PCI reallocation (breaks 10 gig on burnupi)
sed -i 's;" console=tty0;"pci=realloc=off console=tty0;g' $f

#set verbose kernel output via dmesg:
if ! grep -q dmesg /etc/rc.local; then sed -i 's/^exit 0/dmesg -n 7\nexit 0/g' /etc/rc.local; fi

# touch this file so we know not to run this script again
touch /kernel-logging-setup

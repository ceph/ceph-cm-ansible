#!/bin/bash
## {{ ansible_managed }}
set -ex
name=$1
profile=$2
echo "Reimaging $name with profile $profile"
# First turn netboot off so that cobbler removes any stale PXE data
cobbler system edit --name=$name netboot off
cobbler system edit --name=$name --profile $profile --netboot on && cobbler system reboot --name $name

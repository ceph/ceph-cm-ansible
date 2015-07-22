#!/bin/bash
## {{ ansible_managed }}
set -ex
name=$1
ipmitool -H $name.{{ ipmi_domain }} -I lanplus -U {{ power_user }} -P {{ power_pass }} sol activate

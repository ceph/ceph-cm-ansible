#!/bin/bash
## {{ ansible_managed }}
name=$1
cobbler system reboot --name $name

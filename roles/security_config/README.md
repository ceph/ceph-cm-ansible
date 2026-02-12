# Security Config Role

This Ansible role configures security features on target systems, including CrowdStrike Falcon sensor installation and Message of the Day (MOTD) banner management.

## Features

- **Falcon Sensor Installation**: Installs and configures the CrowdStrike Falcon EDR agent across multiple Linux distributions
- **MOTD Banner Configuration**: Manages system login banners with customizable security warnings

## Role Structure

roles/security_config/
├── README.md # This file
├── defaults/
│ └── main.yml # Default variables (falcon_cid, falcon_tags, falcon_repo, motd_banner)
└── tasks/
├── main.yml # Main task entry point (imports other tasks)
├── install_falcon.yml # Falcon sensor installation and configuration (tag: install_falcon)
└── motd.yml # MOTD banner management (tag: config_motd)

### Tasks

- `install_falcon.yml` (tag: `install_falcon`)
  - Installs and configures the CrowdStrike Falcon sensor:
    1. Normalizes platform name (rhel, ubuntu, suse)
    2. Validates OS support
    3. Determines package URL based on distribution, version, and architecture
    4. Downloads the sensor package
    5. Installs package via RPM (RHEL/SUSE) or DEB (Ubuntu)
    6. Configures Falcon with CID and tags
    7. Starts and enables the falcon-sensor service

- `motd.yml` (tag: `config_motd`)
  - Configures the system MOTD banner:
    1. Creates/manages `/etc/motd` file
    2. Inserts customizable banner using Ansible block markers
    3. Only runs if `motd_banner` variable is defined

### Role Variables

### Falcon Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `falcon_cid` | `YOURCID` | CrowdStrike Customer ID (required) |
| `falcon_tags` | See defaults | Comma-separated tags for sensor classification |
| `falcon_repo` | See defaults | Dictionary mapping OS family/version/arch to package URLs |

### MOTD Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `motd_banner` | Security warning message | Banner content for `/etc/motd` (optional) |

## Supported Platforms

### For Falcon Sensor
- **RHEL**: Versions 9, 10 (x86_64, aarch64)
- **CentOS**: Versions 9, 10 (x86_64, aarch64)
- **Rocky**: Versions 9, 10 (x86_64, aarch64)
- **Ubuntu**: Versions 22, 24 (x86_64, aarch64)
- **SUSE**: Version 15 (x86_64, aarch64)

### For MOTD
- Any Linux system with `/etc/motd` support

## Usage

### Run all security configurations
```bash
ansible-playbook security_config.yml
```
### Install Falcon sensor only
```bash
ansible-playbook security_config.yml --tags install_falcon
```
### Configure MOTD only
```bash
ansible-playbook security_config.yml --tags config_motd
```
### Run against specific hosts
```bash
ansible-playbook security_config.yml -i inventory/hosts -l webservers
```

### Configuration Example

Set variables in your inventory, group_vars, or host_vars:

# group_vars/all.yml or group_vars/webservers.yml
falcon_cid: "YOUR_ACTUAL_CID_HERE"
falcon_tags: "UT/PROD,CCODE/EXAMPLE,UPDATES/PROD,AV/YES,OWNER/SECOPS"

motd_banner: |
  ************************************************************
  * AUTHORIZED ACCESS ONLY                                  *
  * All activity is monitored and logged.                   *
  * Unauthorized access is prohibited.                      *
  ************************************************************

### Requirements

- Ansible 2.9+
- Target systems must have network access to Falcon package repository
- Root or sudo access required on target systems (via become: true)
- falcon_cid and falcon_tags must be configured before running the install_falcon task

### Notes

- The playbook runs with become: true, granting root/sudo privileges
- Falcon CID should be provided via group_vars or host_vars
- The MOTD task only executes if motd_banner is defined
- Platform detection uses ansible_os_family, ansible_distribution_major_version, and ansible_architecture
- Downloaded packages are temporarily stored in tmp during installation
- Use --tags flag to run specific task blocks independently
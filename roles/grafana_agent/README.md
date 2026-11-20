# Grafana Agent Ansible Role

## Overview

This Ansible role installs and configures the Grafana Agent on supported Linux systems, specifically Ubuntu (using `apt`) and RedHat-based distributions (using `yum` or `dnf`). The role handles repository setup, package installation, service management, and SELinux configuration (for RedHat systems). It also ensures that the Grafana Agent configuration file is deployed and that the service is started and enabled.

## Requirements

- **Ansible Version**: 2.16.3 or higher
- **Supported Operating Systems**:
  - Ubuntu (tested on 22.04 LTS)
  - RedHat-based distributions (e.g., CentOS, RHEL)
- **Python**: Python 3.6 or higher on the target hosts
- **Dependencies**:
  - For Ubuntu: `apt` package manager
  - For RedHat: `yum` or `dnf` package manager, and SELinux tools (`policycoreutils`, `checkpolicy`) for systems with SELinux enabled

## Role Variables

Variables are defined in `roles/grafana_agent/defaults/main.yml`. Below are the key variables:

- **`agent_mimir_url`**: URL for the Mimir endpoint to push metrics (default: `http://grafana.example.com:9009/api/v1/push`).
- **`agent_mimir_username`**: Username for Mimir authentication (default: `admin`).
- **`grafana_apt_repo_url`**: Grafana repository URL for Debian/Ubuntu systems (default: `https://apt.grafana.com`).
- **`grafana_apt_repo_key_url`**: URL for the Grafana GPG key for APT (default: `https://apt.grafana.com/gpg.key`).
- **`grafana_rpm_repo_url`**: Grafana repository URL for RPM-based systems (default: `https://rpm.grafana.com`).
- **`grafana_rpm_repo_key_url`**: URL for the Grafana GPG key for RPM (default: `https://rpm.grafana.com/gpg.key`).
- **`scrape_interval_global`**: Global scrape interval for Grafana Agent (default: `60s`).
- **`scrape_interval_node`**: Scrape interval for node exporter metrics (default: `30s`).
- **`useradd_selinux_packages`**: List of SELinux packages to install on RedHat systems (default: `['policycoreutils', 'checkpolicy']`).

Sensitive data, such as the Mimir password, should be stored in a separate encrypted file (e.g., `mimir_password.yml`) and included via the `secrets_path` variable.

## Usage

1. **Clone the Repository**:
   Ensure the role is part of your Ansible project under `roles/grafana_agent`.

2. **Set Up Secrets**:
   Create a `mimir_password.yml` file in your secrets directory (e.g., `secrets/mimir_password.yml`) with the necessary credentials:
   ```yaml
   agent_mimir_password: "<your-password>"
   ```

3. **Configure Inventory**:
   Define the target hosts in your Ansible inventory file (e.g., `/etc/ansible/hosts`).

4. **Run the Playbook**:
   Execute the playbook with the role included. Example:
   ```bash
   ansible-playbook grafana_agent.yml --limit="server01.example.com" -vvvv
   ```

   Example playbook (`grafana_agent.yml`):
   ```yaml
   - hosts: all
     roles:
       - grafana_agent
   ```

5. **Role Tasks**:
   The role performs the following tasks:
   - Includes sensitive variables from `mimir_password.yml`.
   - Gathers facts on listening ports to check for conflicts.
   - Installs SELinux dependencies and applies a custom SELinux policy (`customuseradd.te`) on RedHat systems.
   - Checks for port conflicts with Prometheus on port 9090.
   - Configures the Grafana APT or YUM/DNF repository based on the OS.
   - Installs the `grafana-agent` package.
   - Enables and starts the `grafana-agent` service.
   - Deploys the configuration file from the template `grafana-agent.yaml.j2` to `/etc/grafana-agent.yaml`.

## Notes

- **Port Conflict Check**: The role checks for services listening on port 9090, which is used by Grafana Agent. If a conflict is detected (e.g., Prometheus), the playbook fails with a message indicating the need to reconfigure the conflicting service.
- **SELinux**: SELinux tasks are only executed on RedHat-based systems where `ansible_os_family == "RedHat"`. A custom SELinux policy (`customuseradd.te`) is applied to handle specific permissions.
- **APT Repository**: For Ubuntu, the role sets up the Grafana repository in `/etc/apt/sources.list.d/grafana.list` and ensures the GPG key is correctly configured in `/etc/apt/keyrings/grafana.gpg`. Conflicting repository entries are removed to prevent `Signed-By` errors.
- **Configuration File**: The role uses a Jinja2 template (`grafana-agent.yaml.j2`) to generate the Grafana Agent configuration. Ensure this template exists in the `templates` directory and is properly configured for your environment.

## Troubleshooting

- **Conflicting APT Sources**: If you encounter errors like `Conflicting values set for option Signed-By`, check `/etc/apt/sources.list.d/` for duplicate Grafana repository entries and remove them manually or via the playbook's cleanup tasks.
- **SELinux Issues**: On RedHat systems, ensure the `customuseradd.te` file exists in the role's files directory and that SELinux tools are installed.
- **Port Conflicts**: If the playbook fails due to a port conflict on 9090, verify running services with `ss -tuln | grep 9090` and reconfigure or stop the conflicting service.

## Example Inventory

```ini
[servers]
server01.example.com ansible_user=cm
```

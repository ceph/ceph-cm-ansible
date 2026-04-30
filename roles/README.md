# Grafana Agent Role

This Ansible role installs, configures, and manages **Grafana Agent** (static mode) for scraping node metrics and forwarding them to a Mimir instance.

It supports both **Debian/Ubuntu** and **RedHat-family** systems (RHEL, Rocky Linux, AlmaLinux, etc.).

## What This Role Does

- Installs `prometheus-node-exporter` (Debian/Ubuntu) or `node_exporter` (RedHat via EPEL)
- Installs Grafana Agent and adds the official Grafana repository
- Deploys a configuration that scrapes node metrics from `localhost:9100`
- Forwards metrics to Mimir with basic authentication and TLS support
- Creates the WAL directory for Grafana Agent
- Applies SELinux adjustments on RedHat systems
- Fails early if Prometheus is listening on port 9090 (to prevent port conflicts)

## Supported Platforms

- Debian / Ubuntu
- Red Hat Enterprise Linux and derivatives (Rocky Linux, AlmaLinux, CentOS Stream)

## Prerequisites

- Ansible 2.10 or later
- The `community.general` collection (`ansible-galaxy collection install community.general`)
- A secrets repository that provides:
  - `mimir_password.yml` containing `mimir_username` and `mimir_password`
  - The following variables: `grafana_apt_repo_key_url`, `grafana_apt_repo_url`, `grafana_rpm_repo_url`, `grafana_rpm_repo_key_url`, `agent_mimir_url`, and `scrape_interval_global`

## Role Variables

Sensitive and environment-specific variables should be defined in the secrets repository.

### Required Variables

| Variable                        | Description |
|--------------------------------|-------------|
| `secrets_path`                 | Path to the secrets repository |
| `agent_mimir_url`              | Full `remote_write` URL pointing to your Mimir instance |
| `mimir_username`               | Username for Mimir basic auth |
| `mimir_password`               | Password for Mimir basic auth |
| `grafana_apt_repo_key_url`     | URL to the Grafana APT GPG key |
| `grafana_apt_repo_url`         | Grafana APT repository base URL |
| `grafana_rpm_repo_url`         | Grafana RPM repository base URL |
| `grafana_rpm_repo_key_url`     | URL to the Grafana RPM GPG key |
| `scrape_interval_global`       | Global scrape interval (defaults to `60s`) |

## Dependencies

This role depends on the `secrets` role, which provides the variable `secrets_path` pointing to the secrets repository.

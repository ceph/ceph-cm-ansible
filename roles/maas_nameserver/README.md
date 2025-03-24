# maas_nameserver Ansible Role

## Overview

The `maas_nameserver` role configures DNS domains and records in MAAS (Metal as a Service) based on an Ansible inventory. It manages DNS entries for hosts (e.g., Main interfaces, IPMI interfaces, VLAN interfaces) in specified domains, ensuring only desired records and domains exist while cleaning up unwanted ones. This role depends on a secrets file to load MAAS API credentials.

## Requirements

- Ansible: Version 2.9 or higher
- MAAS CLI: Installed on the target MAAS server
- Inventory: A valid Ansible inventory with `group_vars/all.yml` defining `dns_domains`

## Role Structure

```
roles/
  maas_nameserver/
    defaults/
      main.yml
    tasks/
      main.yml
    meta/
      main.yml
    README.md
```

## Dependencies

- **Secrets File**: A `maas.yml` file at `{{ secrets_path }}/maas.yml` provides MAAS API credentials (e.g., `maas_api_key`, `maas_api_url`). No separate secrets role is required; credentials are loaded via `include_vars`.

## Usage

1. **Prepare Inventory**

   Define your `maas` and target host groups:

   ```ini
   [maas]
   maas.internal.ceph.ibm.com ip=10.11.120.237

   [snipeit]
   snipe-it.internal.ceph.ibm.com ip=10.60.100.11

   [machine]
   machine001.internal.ceph.ibm.com ip=10.18.131.100 ipmi=10.18.139.100 vlan104=10.18.144.3
   ```

2. **Set Up Inventory Variables**

   Define `dns_domains` in `group_vars/all.yml`:

   ```yaml
   ---
   dns_domains:
     ceph: "internal.ceph.ibm.com"
     ipmi: "ipmi.ceph.ibm.com"
     vlan104: "vlan104.internal.ceph.ibm.com"
   ```

3. **Set Up Secrets**

   Create a secrets file at `{{ secrets_path }}/maas.yml`:

   ```yaml
   ---
   maas_profile: "admin" # also called the maas api username
   maas_api_key: "XXXXXXXXXXXXXXXX" # api key of the profile defined in maas_profile
   maas_api_url: "http://localhost:5240/MAAS/api/2.0/"
   ```

4. **Run the Playbook**

   ```bash
   ansible-playbook maas_nameserver.yml
   ```

## Variables

### defaults/main.yml

These are overridable defaults:

- `maas_api_url`: Default MAAS API endpoint (`http://localhost:5240/MAAS/api/2.0/`). Override in `secrets/maas.yml`.

- `maas_profile`: Default MAAS profile name (`admin`). Override in `secrets/maas.yml`.

- `default_domains`: Domains to preserve (default: `["maas"]`). The `maas` domain is used by MAAS for internal DNS records and is excluded from cleanup.

- `target_hosts`: List of hosts for DNS records. Defaults to an empty list (`[]`), in which case the role dynamically selects all hosts from inventory groups except those in `exclude_groups`. Override in `group_vars/maas.yml`:

  ```yaml
  target_hosts:
    - machine001.internal.ceph.ibm.com
    - machine002.internal.ceph.ibm.com
  ```

  Or via command line:

  ```bash
  ansible-playbook maas_nameserver.yml -e "target_hosts=['machine001.internal.ceph.ibm.com']"
  ```

- `exclude_groups`: List of inventory groups to exclude from `target_hosts` when `target_hosts` is empty. Defaults to `["maas", "all", "ungrouped"]`. The `all` and `ungrouped` groups must be included to prevent the automatic inclusion of all hosts (via the `all` group, which contains every host in the inventory) or ungrouped hosts (via the `ungrouped` group). Override in `group_vars/maas.yml`:

  ```yaml
  exclude_groups: ["maas", "all", "ungrouped", "other_group"]
  ```

### vars/main.yml

No mandatory, non-overridable variables are defined. Environment-specific variables like `dns_domains` must be set in `inventory/group_vars/all.yml`.

### secrets/maas.yml

Provides MAAS API credentials and optional overrides:

1. `maas_api_key`: MAAS API key for authentication.
2. `maas_api_url`: MAAS API endpoint (e.g., `http://127.0.0.1:5240/MAAS/api/2.0/`).

`maas_profile`: MAAS CLI profile name (e.g., `admin`).

1. `target_hosts` (optional): Override the default `target_hosts` list.
2. `exclude_groups` (optional): Override the default `exclude_groups` list.

**Example**:

```yaml
maas_api_key: "XXXXXXXXXXXXXXXX"
maas_api_url: "http://127.0.0.1:5240/MAAS/api/2.0/"
maas_profile: "admin"
# Optional overrides
target_hosts:
  - machine001.internal.ceph.ibm.com
exclude_groups:
  - maas
  - all
  - ungrouped
```

**Notes**:

- **Security**: Ensure file permissions are restricted (e.g., `chmod 600 maas.yml`).
- **Vault**: If encrypted, provide the vault password (e.g., via `--vault-password-file ~/.vault_pass.txt`).

## Behavior

- **DNS Records**: Creates A records for hosts based on `dns_domains` and inventory variables (e.g., `ip`, `ipmi`, `vlan104`). Example:
  - `machine001.internal.ceph.ibm.com` → `10.18.131.100`
  - `machine001.ipmi.ceph.ibm.com` → `10.18.139.100`
  - `machine001.vlan104.internal.ceph.ibm.com` → `10.18.144.3`
- **Cleanup**: Deletes DNS records and domains not in `dns_domains` or `default_domains`.
- **Idempotency**: Skips actions if the desired state is already met.

## Troubleshooting

- **Missing** `dns_domains`: Ensure `dns_domains` is defined in `inventory/group_vars/all.yml`. The playbook will fail if undefined.
- **Secrets Not Loading**: Verify `secrets_path` points to the correct directory and `maas.yml` contains valid credentials.
- **MAAS CLI Errors**: Confirm the MAAS CLI is installed on the target server and the API key is valid.
- **Failed Deletions**: Check playbook output for errors during DNS record or domain deletions (e.g., permissions, network issues, or records that do not exist).
- **Unwanted DNS Records**: If DNS records are created for unintended hosts, verify `exclude_groups` includes `all` and `ungrouped` to prevent the inclusion of all inventory hosts or ungrouped hosts. Check for overrides in `secrets/maas.yml` or extra vars that modify `target_hosts` or `exclude_groups`.

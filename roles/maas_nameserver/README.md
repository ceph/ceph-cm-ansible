# README for `maas_nameserver` Ansible Role

## Overview
The `maas_nameserver` role configures DNS domains and records in MAAS (Metal as a Service) based on an Ansible inventory. It manages DNS entries for Ceph nodes and their IPMI interfaces, ensuring only desired records and domains exist while cleaning up unwanted ones. This role depends on a `secrets` role to load encrypted MAAS API credentials using Ansible Vault.

## Requirements
- **Ansible**: Version 2.9 or higher
- **MAAS CLI**: Installed on the target MAAS server
- **Secrets Role**: A companion `secrets` role to load encrypted credentials

## Role Structure
```
roles/
  maas_nameserver/
    defaults/
      main.yml
    meta/
      main.yml
    tasks/
      main.yml
    vars/
      main.yml
    README.md
```

## Dependencies
- **`secrets` Role**: Defined in `meta/main.yml`, this role loads encrypted MAAS API credentials from a configurable path. Ensure the `secrets` role is available in your `roles/` directory.

## Usage
1. **Place the Role**: Ensure the `maas_nameserver` and `secrets` roles are in your `roles/` directory.
2. **Prepare Inventory**: Define your `maas` and your target hosts groups (e.g., in `/etc/ansible/hosts/tucson`):
   ```ini
   [ceph]
   ceph001.internal.ceph.tucson.com ip=10.18.131.1 ipmi=10.18.139.1
   ceph002.internal.ceph.tucson.com ip=10.18.131.2 ipmi=10.18.139.2
   ceph003.internal.ceph.tucson.com ip=10.18.131.3 ipmi=10.18.139.3

   [maas]
   ceph-vm-14.internal.ceph.tucson.com ip=9.11.120.237
   ```
3. **Set Up Secrets**: Encrypt your MAAS credentials in a secrets file (see "Secrets File" section below).
4. **Run the Playbook**:
   ```bash
   ansible-playbook maas-dns-playbook.yml
   ```

## Variables

### `defaults/main.yml`
These are overridable defaults:
- `maas_api_url`: Default MAAS API endpoint (`http://localhost:5240/MAAS/api/2.0/`). Typically overridden by the secrets file.
- `maas_profile`: Default MAAS profile name (`admin`). Overridden by the secrets file.
- `allowed_domains`: List of domains to preserve (default: `["maas"]`).

### `vars/main.yml`
These are role-specific variables, not intended for override:
- `dns_domains`:
  - `ceph`: Dynamically derived from the first Ceph host’s domain (e.g., `internal.ceph.tucson.com`).
  - `ipmi`: Static IPMI domain (`ipmi.ceph.tucson.com`).

## Secrets File
The `maas_nameserver` role depends on the `secrets` role to load encrypted MAAS API credentials. The secrets file is expected at `{{ secrets_path }}/maas.yml`, where `secrets_path` defaults to `/etc/ansible/secrets`.

### Example Secrets File
Create and encrypt the file (e.g., `/etc/ansible/secrets/maas.yml`):
```yaml
---
maas_api_url: "http://X.X.X.X:5240/MAAS/api/2.0/"
maas_api_key: "XXXXXXXXXXXXXXXX"
maas_profile: "admin"
```

**Notes**:
- **Location**: Store this file in a secure directory (e.g., `/etc/ansible/secrets` or a private repo like `~/secrets/ceph-secrets`). Adjust `secrets_path` if using a custom location.
- **Security**: Ensure the file is readable only by the Ansible user (e.g., `chmod 600`).
- **Variables**:
  - `maas_api_url`: The MAAS API endpoint.
  - `maas_api_key`: The API key for authentication.
  - `maas_profile`: The profile name used with the MAAS CLI.
- **Vault Password**: Store the password securely (e.g., in `~/.vault_pass.txt` with `chmod 600`) or provide it at runtime.

## Behavior
- **DNS Records**: Creates A records for Ceph nodes (`ip`) and IPMI interfaces (`ipmi`) in `internal.ceph.tucson.com` and `ipmi.ceph.tucson.com`, respectively.
- **Cleanup**: Removes unwanted DNS records and domains not matching the desired state or `allowed_domains`.
- **Idempotency**: Skips actions if the desired state is already met.

## Example Output
Running the playbook should produce output similar to:
```
TASK [maas_nameserver : Debug desired FQDNs] ******************************************
ok: [ceph-vm-14.internal.ceph.tucson.com] => {
    "msg": "Desired FQDNs: ['ceph001.internal.ceph.tucson.com', 'ceph002.internal.ceph.tucson.com', 'ceph003.internal.ceph.tucson.com', 'ceph001.ipmi.ceph.tucson.com', 'ceph002.ipmi.ceph.tucson.com', 'ceph003.ipmi.ceph.tucson.com']"
}
```

## Troubleshooting
- **Secrets Not Loading**: Verify `secrets_path` points to the correct directory and the file is encrypted correctly. Check vault password access.
- **MAAS CLI Errors**: Ensure the MAAS CLI is installed and the API credentials are valid.

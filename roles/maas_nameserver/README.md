# maas_nameserver Ansible Role

## Overview

The `maas_nameserver` role configures DNS domains and records in MAAS (Metal as a Service) based on an Ansible inventory. It manages DNS entries for hosts (e.g., main interfaces, IPMI interfaces) in specified domains, ensuring only desired records and domains exist while cleaning up unwanted ones. This role depends on a secrets file to load MAAS API credentials.

## Requirements

- Ansible: Version 2.9 or higher
- MAAS CLI: Installed on the target MAAS server
- Python: Version 3.6 or higher (for `maas.maas` collection)
- Inventory: A valid Ansible inventory with `group_vars/all.yml` defining `dns_domains`
- MAAS API Access: Valid credentials in a secrets file
- Network: Stable connectivity to the MAAS server

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

- **Secrets File**: A `maas.yml` file at `{{ secrets_path }}/maas.yml` provides MAAS API credentials (`maas_cluster_instance` with `customer_key`, `token_key`, and `token_secret`). The `host` is set dynamically at runtime.
- **maas.maas Collection**: Automatically installed by the role if not present.

## Usage

1. **Prepare Inventory**

   Define your `maas` group and target hosts in your inventory file (e.g., `inventory/hosts`):

   ```ini
   [maas]
   maas-server.example.com ansible_host=192.168.1.10

   [servers]
   server01.example.com mac=00:1a:2b:3c:4d:5e ip=192.168.1.11 ipmi=192.168.2.11 bmc=00:1a:2b:3c:4d:5f
   server02.example.com mac=00:1a:2b:3c:4d:60 ip=192.168.1.12 ipmi=192.168.2.12 bmc=00:1a:2b:3c:4d:61
   ```

2. **Set Up Inventory Variables**

   Define `dns_domains` in `group_vars/all.yml` to specify the domains for A/AAAA records derived from inventory hosts (e.g., `ip` and `ipmi` variables):

   ```yaml
   ---
   dns_domains:
     ip: "example.com"
     ipmi: "ipmi.example.com"
   ```

   Optionally, define `dns_records` in `group_vars/dns_records.yml` to configure additional DNS records. This file is used for:
   - **Hosts outside the Ansible inventory**: Records for external services or devices not managed in the inventory (e.g., third-party servers, wildcard records).
   - **Non-A/AAAA record types**: Records such as MX, SRV, TXT, or CNAME, which require specific attributes (e.g., priority, target, port) not derived from inventory variables like `ip` or `ipmi`.

   Example `group_vars/dns_records.yml`:

   ```yaml
   ---
   dns_records:
     - name: "api"
       domain: "ocp1.example.com"
       type: "A/AAAA"
       ip: "192.168.1.101"
     - name: "*"
       domain: "apps.ocp1.example.com"
       type: "A/AAAA"
       ip: "192.168.1.102"
     - name: "mail"
       domain: "example.com"
       type: "MX"
       priority: 10
       target: "mailserver.example.com"
     - name: "_sip._tcp"
       domain: "example.com"
       type: "SRV"
       priority: 10
       weight: 60
       port: 5060
       target: "sipserver.example.com"
   ```

3. **Set Up Secrets**

   Create a secrets file at `{{ secrets_path }}/maas.yml` (e.g., `secrets/maas.yml`):

   ```yaml
   ---
   maas_cluster_instance:
     customer_key: "your_customer_key"
     token_key: "your_token_key"
     token_secret: "your_token_secret"
   ```

   **Note**: The `host` field is not included in `maas_cluster_instance` as it is set dynamically using `maas_api_url` from `defaults/main.yml` and the `maas` group in the inventory. Restrict file permissions (e.g., `chmod 600 secrets/maas.yml`) and consider using Ansible Vault for encryption.

4. **Run the Playbook**

   ```bash
   ansible-playbook maas_nameserver.yml
   ```

   For verbose output to troubleshoot:

   ```bash
   ansible-playbook maas_nameserver.yml -v
   ```

## Variables

### defaults/main.yml

Overridable defaults:

- `maas_server_ip`: Derived from the first host in the `maas` group (`{{ groups.get('maas', []) | first | default('undefined_maas_server') }}`).
- `maas_api_url`: MAAS API endpoint (`http://{{ maas_server_ip }}:5240/MAAS`).
- `dns_ttl`: Default TTL for DNS records (`3600` seconds).
- `excluded_groups`: Groups to exclude from inventory processing (`["all", "ungrouped"]`).
- `excluded_domains`: Domains to preserve from cleanup (`["maas", "front.sepia.example.com"]`).
- `supported_record_types`: Allowed DNS record types (`["A/AAAA", "CNAME", "MX", "NS", "SRV", "SSHFP", "TXT"]`).

Example `defaults/main.yml`:

```yaml
---
maas_server_ip: "{{ groups.get('maas', []) | first | default('undefined_maas_server') }}"
maas_api_url: "http://{{ maas_server_ip }}:5240/MAAS"
dns_ttl: 3600
excluded_groups: ["all", "ungrouped"]
excluded_domains: ["maas", "front.sepia.example.com"]
supported_record_types: ["A/AAAA", "CNAME", "MX", "NS", "SRV", "SSHFP", "TXT"]
```

### vars/main.yml

No mandatory, non-overridable variables are defined. Environment-specific variables like `dns_domains` must be set in `inventory/group_vars/all.yml`.

### secrets/maas.yml

Provides MAAS API credentials:

- `maas_cluster_instance.customer_key`: MAAS API customer key.
- `maas_cluster_instance.token_key`: MAAS API token key.
- `maas_cluster_instance.token_secret`: MAAS API token secret.

**Example**:

```yaml
---
maas_cluster_instance:
  customer_key: "your_customer_key"
  token_key: "your_token_key"
  token_secret: "your_token_secret"
```

## Behavior

- **DNS Records**: Creates A/AAAA records for hosts based on `dns_domains` and inventory variables (e.g., `ip`, `ipmi`). Example:
  - `server01.example.com` → `192.168.1.11`
  - `server01.ipmi.example.com` → `192.168.2.11`
  - Additional records from `dns_records` (e.g., `api.ocp1.example.com` → `192.168.1.101`, MX/SRV records).
- **Cleanup**: Deletes DNS records and domains not in `dns_domains` or `excluded_domains`, skipping default MAAS domains, with retries to handle transient network issues.
- **NS Records**: Skipped due to module limitations; a notification is displayed for skipped NS records, which must be created manually via MAAS CLI or UI.
- **Idempotency**: Skips actions if the desired state is already met.
- **Retries**: All tasks creating or deleting DNS records or domains include retries (`retries: 3`, `delay: 5`) to handle transient network issues (e.g., `TimeoutError`).
- **Result Display**: Displays results for created or updated DNS domains, inventory host DNS records, and static DNS records from `dns_records`.

## Troubleshooting

- **Network Issues**: If you see `[Errno -2] Name or service not known` or `TimeoutError`, verify the MAAS server hostname (e.g., `maas-server.example.com`) resolves correctly and the server is responsive:
  ```bash
  ping maas-server.example.com
  curl http://maas-server.example.com:5240/MAAS/api/2.0/version/
  ```
  Add to `/etc/hosts` if needed (e.g., `192.168.1.10 maas-server.example.com`). Check network stability or MAAS server load if timeouts persist.

- **Missing dns_domains**: Ensure `dns_domains` is defined in `group_vars/all.yml`.

- **Missing dns_records**: Ensure `dns_records` is defined in `group_vars/dns_records.yml` for non-inventory hosts or non-A/AAAA records, if needed.

- **Secrets Not Loading**: Verify `secrets_path` points to the correct directory and `maas.yml` contains valid credentials. If using Ansible Vault, provide the vault password:
  ```bash
  ansible-playbook maas_nameserver.yml --vault-password-file ~/.vault_pass.txt
  ```

- **MAAS API Errors**: Confirm the MAAS CLI is installed and the API credentials are valid. Test with:
  ```bash
  maas login <profile> http://maas-server.example.com:5240/MAAS <api-key>
  maas <profile> domains read
  ```

- **Unwanted DNS Records**: Verify `excluded_groups` includes `all` and `ungrouped` in `defaults/main.yml` to prevent unintended host inclusion.

- **NS Record Skipped**: Manually create NS records in MAAS UI or CLI:
  ```bash
  maas login <profile> http://maas-server.example.com:5240/MAAS <api-key>
  maas <profile> dnsresource create domain=example.com name=ns1 type=NS data=ns1.example.com ttl=3600
  ```

- **Slow Execution or Timeouts**: Enable profiling to identify bottlenecks:
  ```bash
  ansible-playbook maas_nameserver.yml -v
  ```
  Adjust `ansible.cfg` for higher parallelism:
  ```ini
  [defaults]
  forks = 20
  ```

## Performance Optimizations

- **Inventory Filtering**: Only hosts with `ip` or `ipmi` variables are processed, reducing unnecessary iterations.
- **Retries for Reliability**: All tasks that create or delete DNS records or domains use retries (`retries: 3`, `delay: 5`) to handle transient network issues, improving robustness for large inventories (e.g., 48 hosts).
- **Minimal Debug Output**: Includes only essential debug output for NS record skip notifications and results of DNS domain and record creation to provide feedback without excessive overhead.

For further optimization, consider enabling fact caching in `ansible.cfg` to reduce API calls in subsequent runs:
```ini
[defaults]
fact_caching = jsonfile
fact_caching_timeout = 86400
fact_caching_connection = /tmp/ansible_cache
```

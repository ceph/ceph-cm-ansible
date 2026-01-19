Perfect — here is the **cleaned and corrected README.md** with exactly your requested changes applied:

* ✅ Removed point **7 (air-gapped / bastion-based environments)**
* ✅ Removed the **Maintainers** section
* ✅ Replaced real hostnames with **generic examples** (`bob`, `mac`)
* ✅ Keeps GitHub-friendly rendering
* ✅ Keeps the hostname → label example inline (as you wanted)

You can copy this **as-is** into `roles/teleport_ssh_node/README.md`:

---

````md
# teleport_ssh_node

Ansible role to **install, configure, and join a Linux host as a Teleport SSH node**
to an existing Teleport cluster.

It supports:
- Ubuntu / Debian
- RHEL / CentOS / Rocky
- Teleport 15.x (version pinned)
- Idempotent re-runs
- Safe hostname handling
- Label-based node discovery

---

## What this role does

1. Sets the system hostname to the node FQDN
2. Installs Teleport **pinned to a specific version**
3. Creates `/etc/teleport.yaml` from template
4. Joins the node to the Teleport cluster using a join token
5. Enables and starts the teleport service
6. Registers the node with:
   - Correct `nodename`
   - `role` label derived from hostname

---

## Requirements

### On the control node
- Ansible 2.16+
- SSH access to target nodes
- Valid Teleport join token
- Network access to the Teleport proxy

### On the target node
- Systemd
- Python 3
- Outbound access to the Teleport proxy

---

## Role Variables

### Required

| Variable | Description |
|--------|------------|
| `teleport_join_token` | Teleport node join token |
| `teleport_ca_pin` | CA pin for secure joining |
| `teleport_proxy` | Proxy address (host:port) |

---

### Optional

| Variable | Default | Description |
|--------|---------|------------|
| `teleport_version` | `15.5.4` | Teleport version (pinned) |
| `teleport_config_path` | `/etc/teleport.yaml` | Config file path |
| `teleport_data_dir` | `/var/lib/teleport` | Data directory |

---

## Hostname handling and labels

The role automatically derives the Teleport node identity from the host itself.

For a host with FQDN:

```text
bob.example.com
````

The generated configuration will include:

```yaml
teleport:
  nodename: bob.example.com

ssh_service:
  labels:
    role: bob
```

This ensures stable node identity, clean RBAC matching, and predictable resource
names in Teleport without requiring manual label management.

---

## Example Playbook

```yaml
- hosts: mac
  become: true
  vars_prompt:
    - name: teleport_join_token
      prompt: "Enter Teleport join token"
      private: false
  roles:
    - teleport_ssh_node
```

---

## Example Run

```bash
ansible-playbook join-teleport.yml \
  -i inventory \
  --limit bob.example.com
```

---

## Teleport configuration

The role generates `/etc/teleport.yaml` with:

* pinned Teleport version
* CA pin validation
* proxy configuration
* SSH service only (no auth/proxy)
* hostname-based nodename and labels
* safe defaults for production use

---

## Supported Operating Systems

| OS              | Supported |
| --------------- | --------- |
| RHEL 8/9        | ✅         |
| Rocky 8/9       | ✅         |
| CentOS Stream 9 | ✅         |
| Ubuntu 20.04+   | ✅         |
| Debian 11+      | ✅         |

---

## Idempotency

The role is safe to run multiple times:

* No duplicate joins
* No reinstallation if version is pinned
* Config updates trigger safe restart
* Service state enforced

---

## License

Apache-2.0

```

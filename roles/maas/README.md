# Ansible Playbook: MAAS Installation and Configuration

This Ansible playbook automates the installation and initial configuration of [MAAS (Metal as a Service)](https://maas.io/) on Ubuntu-based systems.

## Features

- Installs MAAS packages
- Initializes MAAS with a default user with High Availability
- Configures networking (Domains, Spaces, Fabrics, VLANs, Subnets, IP ranges, DHCP, DNS, etc.) via the MAAS REST API
- Adds Machines from inventory into MAAS

## Requirements

- Ansible 2.10+
- Ubuntu 20.04 or later on the target system(s)
- Sudo access on target host
- Internet access (for downloading MAAS packages and images)
- At least 2 Nodes to deploy MAAS with High Availability

## Inventory

Define your inventory in `hosts.ini` with the following structure:

```ini
[maas_region_rack_server]
test1 ip=172.x.x.x ipmi=10.0.8.x mac=08:00:27:ed:43:x

[maas_rack_server]
test2 ip=172.x.x.x ipmi=10.0.8.x mac=08:00:27:ed:43:x

[maas_db_server]
test1 ip=172.x.x.x ipmi=10.0.8.x mac=08:00:27:ed:43:x

[maas:children]
maas_region_rack_server
maas_rack_server
maas_db_server

You can do this installation with 3 or 2 nodes depending on your needs.
If you want to use a dedicated DB server you can just put it in the maas_db_server group, use a different server in maas_region_rack_server and another in maas_rack_server.
Or if you want to simplify and you dont mind to use your maas server as DB server too, you can use the same node in maas_db_server and in maas_region_rack_server, as they are different services and use different ports they can be installed on the same node. This way you use only 2 nodes for the installation the db+region+rack server and the secondary rack for high availability.

The systems you want to add into MAAS should be on a group called [testnodes] with the same structure.

## Variables

You can configure the playbook via group_vars/maas.yml in the secret repo or defaults/main.yml. Common variables include:
maas_admin_username: "admin"
maas_admin_password: "adminpass"
maas_admin_email: "admin@example.com"
maas_db_name: "maasdb"
maas_db_user: "maas"
maas_db_password: "maaspassword"
maas_version: "3.7"
postgres_version: "16"
maas_install_method: "apt" #This playbook can install MAAS with snap or with apt packages, you can select the install method with this variable. Consider that the behavior of MAAS changes depending of the install method you select.
maas_home_dir: "/home/ubuntu/maas" #In order to be able to modify default files whe you install MAAS with SNAP you need to unsquash the snap filesystem inside another directory, this variable defines that directory, so it is only relevant when you select snap as maas_install_method.
global_kernel_opt: "console=tty0 console=ttyS1,115200" #This are the global kernel options that MAAS will put on all deployed systems, there is a way to create kernel parameters with tags for individual group of servers but at this moment this playbook does not configure those.

NTP variables include:
maas_ntp_servers: "ntp.ubuntu.com"  # NTP servers, specified as IP addresses or hostnames delimited by commas and/or spaces, to be used as time references for MAAS itself, the machines MAAS deploys, and devices that make use of MAAS's DHCP services. MAAS uses ntp.ubuntu.com by default. You can put a single server or multiple servers.
maas_ntp_external_only: "false" # Configure all region controller hosts, rack controller hosts, and subsequently deployed machines to refer directly to the configured external NTP servers. Otherwise only region controller hosts will be configured to use those external NTP servers, rack contoller hosts will in turn refer to the regions' NTP servers, and deployed machines will refer to the racks' NTP servers. The value of this variable can be true or false.

DNS variables include:
dns_domains: # This is the list of domains you want to create, in this case we have 2 domains, but you can list here all the domains you need.
  - ceph: Static primary domain (e.g., `front.sepia.ceph.com`).
  - ipmi: Static IPMI domain (`ipmi.sepia.ceph.com`).
default_domains: List of domains to preserve/ignore (default: `["maas"]`). The default domain is a DNS domain that is used by maas when you deploy a machine it is used by maas for internal dns records so we choose to exclude it from our ansible role.

DHCP variables include:
dhcp_maas_global:
  - ddns-update-style: none
  - default-lease-time: 43200
  - max-lease-time: 172800
  - one-lease-per-client: "true"

This list will be used to populate the global DHCP snippet. You can add additional keys and values. Just make sure they follow the syntax required for dhcpd.conf.
The global configuration is optional, so you can just remove the elements of the list if you do not need them.

dhcp_maas_subnets: #This is a list of dictionaries, you can list here all the subnets you want to configure and use any name you want in this case we use front and back but you can include here any other or change the names.
  front:
    cidr: 10.0.8.0/24
    ipvar: ip
    macvar: mac
    start_ip: 10.0.8.10
    end_ip: 10.0.8.20
    ip_range_type: dynamic
    classes:
      virtual: "match if substring(hardware, 0, 4) = 01:52:54:00"
      lxc: "match if substring(hardware, 0, 4) = 01:52:54:ff"
    pools:
      virtual:
        range: 172.21.10.20 172.21.10.250
      unknown_clients:
        range:
          - 172.21.11.0 172.21.11.19
          - 172.21.13.170 172.21.13.250
      lxc:
        range: 172.21.14.1 172.21.14.200
  back:
    cidr: 172.21.16.0/20
    ipvar: back
    macvar: backmac
    start_ip: 172.21.16.10
    end_ip: 172.21.16.20
    ip_range_type: dynamic

This is large dictionary that gets parsed out into individual snippet files. Each top-level key (front and back in the example) will get its own snippet file created. please consider that this task only configures the subnets but it does not create them, so in order for this task to work you should have your network interfaces with a subnet already created.

Under each subnet, cidr, ipvar, and macvar are required. ipvar and macvar tell the Jinja2 template which IP address and MAC address should be used for each host in each subnet snippet, the value of these variables should be the name of the variable that holds the ip address and mac address, respectively (for hosts that have more than one interface). That is, you might have "ipfront=1.2.3.4 ipback=5.6.7.8", and for the front subnet, 'ipvar' would be set to 'ipfront', and for the back network, 'ipvar' would be set to 'ipback', if those variables are not defined in the inventory then that host will not be included into the subnet configuration.

Here's a line from our Ansible inventory host file

smithi001.front.sepia.ceph.com mac=0C:C4:7A:BD:15:E8 ip=172.21.15.1 ipmi=172.21.47.1 bmc=0C:C4:7A:6E:21:A7

This will result in a static lease for smithi001-front with IP 172.21.15.1 and MAC 0C:C4:7A:BD:15:E8 in front_hosts snippet and a smithi001-ipmi entry with IP 172.21.47.1 with MAC 0C:C4:7A:6E:21:A7 in ipmi_hosts snippet.

start_ip, end_ip and ip_range_type are required too in order to create an IP range. MAAS needs a range in order to enable DHCP on the subnet. In this case the ip_range_type is configured as dynamic, it could be dynamic or reserved.

The classes are optional, they are groups of DHCP clients defined by specific criteria, allowing the possibility to apply custom DHCP options or behaviors to those groups. This enables more granular control over how DHCP services are delivered to different client types, like assigning specific IP addresses or configuring other network parameters based on device type or other characteristics. In this case we have virtual and lxc but you can include here any group you want with any name. In our specific case we are including into these groups hosts that match with an specific mac address criteria.

The pools are optional too, they are ranges of IP addresses that a DHCP server uses to automatically assign to DHCP clients on a network. These addresses are dynamically allocated, meaning they are leased to clients for a specific duration and can be reclaimed when no longer in use. DHCP pools allow for efficient IP address management and are essential for networks where devices are frequently added or moved. In the example above we are using pools to assign IPs to the classes we just defined and to the unknown_clients which are servers that are not defined into the DHCP config file.

Networking variables include:

The networking configuration is driven entirely by the `maas_networking` data structure (MUST be defined in `group_vars/all.yml`). It is consumed by `tasks/networking.yml`, which then includes the smaller, single-purpose task files under `tasks/networking/`. The role talks to MAAS over its REST API (using the OAuth header built by `_auth_header.yml`), and is idempotent: it reads what already exists and only creates or updates what is missing or different.

The top-level shape is a list of fabrics, each with its own list of VLANs, and each VLAN with its own list of subnets:

maas_networking:
  - fabric: pok                      # Fabric name (created if missing)
    vlans:
      - vid: 1338                    # 802.1Q VLAN id (required)
        name: new-front              # Required. Must match ^[a-z0-9-]+$ (lowercase, digits, dashes)
        description: "..."           # Optional, stored on the VLAN
        mtu: 1500                    # Optional, applied during VLAN update
        dhcp_on: false               # Optional. If true, MAAS DHCP is enabled for the VLAN
        primary_rack_controller: ""  # Optional per-VLAN override of the global primary rack controller
        subnets:
          - cidr: 10.20.192.0/20     # Required
            domain: front.sepia.ceph.com   # Optional. Collected and created as MAAS Domains
            inventory_prefixes: ["front"]  # Hint to match ansible inventory hosts/IPs during host creation
            managed: false           # Optional. Should MAAS allocate IPs on this subnet?
            space: "pok"             # Optional. Created as a MAAS Space and bound to the VLAN
            gateway: 10.20.192.1     # Optional. Maps to MAAS subnet `gateway_ip`
            dns_servers: []          # Optional list. Falls back to maas_global_dns_servers when empty
            ip_ranges:               # Optional list of reserved/dynamic ranges
              - type: reserved       # 'reserved' or 'dynamic'
                start_ip: 10.20.192.1
                end_ip: 10.20.207.253
              - type: dynamic
                start_ip: 10.20.207.254
                end_ip: 10.20.207.254

Supporting variables:

maas_global_dns_servers: Optional list of DNS server IPs. Used as a fallback for any subnet whose `dns_servers` list is empty or unset.

maas_global_primary_rack_controller: Optional. Hostname of the controller to use as primary rack for any VLAN that does not declare its own `primary_rack_controller`. If neither the global value nor a per-VLAN value is set, the role will fail early during validation rather than silently leave VLANs without a rack controller.

maas_overwrite_ipranges: Optional, defaults to `false`. When `true`, overlapping IP ranges discovered in MAAS will be deleted before the desired range is created. When `false` (the default) the play will fail with the conflicting range ids/spans so the user can resolve it manually.

What `tasks/networking.yml` does, in order:

1. Validates the inventory before making any API calls. It fails fast if any DHCP-enabled VLAN is missing a `dynamic` ip_range, if any VLAN name violates the `^[a-z0-9-]+$` rule, or if `maas_global_primary_rack_controller` is unset and any VLAN omits `primary_rack_controller`.
2. Reads the existing MAAS Domains and creates any new domains found in `maas_networking[*].vlans[*].subnets[*].domain` (`networking/domain_create.yml`).
3. Reads the existing MAAS Spaces and creates any new spaces found in the subnet definitions (`networking/space_create.yml`).
4. Reads the existing Fabrics and creates any missing fabrics named in `maas_networking[*].fabric` (`networking/fabric_create.yml`).
5. Reads each fabric's VLANs (`networking/fabric_vlans_read_from_maas.yml`) and builds a `_vlan_index` keyed by fabric and VID (`networking/vlan_build_index.yml`). Missing VLANs are created with their `vid`, `name`, `description`, `mtu`, and `space`, but not yet with `dhcp_on` (`networking/vlan_create.yml`). The index is then rebuilt to pick up newly-created VLANs.
6. For every (fabric, vlan, subnet) triple, applies the subnet (`networking/subnet_apply.yml`): creates it if missing or updates it in place, sets `gateway_ip` and `managed`, applies DNS servers (subnet-level first, then `maas_global_dns_servers`), and reconciles its IP ranges (`networking/subnet_range_create.yml`). The range task skips exact matches, refuses to create a `dynamic` range on an unmanaged subnet, and either fails on overlaps or replaces them depending on `maas_overwrite_ipranges`.
7. Finally, updates each VLAN's mutable properties — `name`, `mtu`, `space`, `primary_rack`, and `dhcp_on` — only after IP ranges exist, since MAAS will reject `dhcp_on=true` on a VLAN with no dynamic range (`networking/vlan_update.yml`).

Machines variables include:

`tasks/machines.yml` reconciles MAAS's view of physical machines against the Ansible inventory group `[maas_machines]`. Inputs come from a mix of group-level variables (suitable defaults for an entire fleet) and per-host inventory variables (anything that's host-specific, like MAC addresses and per-host overrides). The role talks to MAAS over its REST API and is idempotent: it builds a plan from the current state, then creates / updates / deletes only the deltas.

Per-host variables (typically defined in `group_vars/<group>.yml` or `host_vars/<host>.yml`):

maas_arch: amd64/generic     # Optional. MAAS architecture string. Defaults to global maas_arch, then 'amd64/generic'.
maas_domain: front.sepia.ceph.com   # Optional. MAAS domain to assign on create. Defaults to global maas_domain.
maas_boot_mac_var: if_25Gb_mac      # Name of the inventory var that holds the boot interface's MAC.
maas_boot_ip_var:  if_25Gb_ip       # Name of the inventory var that holds the boot interface's IP.
maas_interfaces:                    # List of physical interfaces to reconcile.
  - prefix: if_25Gb                 # Required. Inventory variable prefix; the role reads <prefix>_mac (and <prefix>_ip) from hostvars.
    native_vid: 1338                # Optional. VID to set as the parent's native VLAN.
    tagged_vids: [1339]             # Optional list. Tagged VLAN subinterfaces to create on this parent (e.g. ipmi).
    mtu: 9000                       # Optional. Sets MTU on the parent if it differs from MAAS's current value.
    desired_mode: AUTO              # Optional. Per-iface override for subnet linking mode (DHCP/AUTO/STATIC/LINK_UP).
maas_bonds:                         # Optional. List of bonds to ensure on this host.
  - name: bond0
    interfaces: [if_25Gb_a, if_25Gb_b]   # Inventory var names whose values are MACs (or literal MACs / iface names).
    mode: 802.3ad
    mtu: 9000
    native_vid: 1338                # Optional. Native VLAN of the bond.
    tagged_vids: [1339]             # Optional. Tagged VLAN subinterfaces to create on the bond.
    link_speed: 25000               # Optional. Only updated while the bond's link is connected.

Per-host inventory line example. The role pairs each `maas_interfaces[*].prefix` with `<prefix>_mac` (and optionally `<prefix>_ip`) from the host's inventory facts:

    smithi001 if_25Gb_mac=0C:C4:7A:BD:15:E8 if_25Gb_ip=10.20.192.1 ipmi=10.20.208.1

Inventory groups consumed by the machines flow:

    [maas_machines]            : the set of hosts that should exist in MAAS.
    [maas_region_rack_server]  : MAAS region/rack controllers — never created or deleted.
    [maas_db_server]           : MAAS DB host(s)            — never created or deleted.
    [maas_dont_delete]         : escape hatch — listed here means "leave alone".

Supporting role-level variables:

maas_delete_hosts: false           # Optional, default false. When true, hosts in MAAS that aren't in [maas_machines] (and aren't excluded) get included via machines/delete.yml. NOTE: machines/delete.yml is currently a debug-only dry-run; flipping this flag does not actually delete anything until that task issues a real DELETE.
maas_allow_create_physical: true   # Optional, default true. When a desired interface MAC is not present on the MAAS node, the role POSTs ?op=create_physical to add it (only relevant for VMs / freshly-commissioned bare metal where MAAS doesn't know the NIC yet).
maas_iface_mode_default: DHCP      # Optional, default 'DHCP'. Subnet-linking mode used when an iface doesn't specify desired_mode. MAAS accepts DHCP, AUTO, STATIC, and LINK_UP.
maas_power_boot_type: efi          # Optional, default 'efi'. Sent as power_parameters_power_boot_type when create.yml ships IPMI creds with a new machine.

IPMI credentials are loaded from the secrets repo and never inlined in the inventory. `set_ipmi_creds.yml` searches, in order: `{{ secrets_path }}/host_vars/<short>.yml`, `{{ secrets_path }}/group_vars/<base_group>.yml` (where `<base_group>` is the short name with trailing digits stripped — e.g. `smithi001` → `smithi`), and finally `{{ secrets_path }}/ipmi.yml`. The first file found supplies `power_user` and `power_pass`. All URI tasks that touch those values use `no_log: true` so they don't leak into Ansible's run output.

What `tasks/machines.yml` does, in order:

1. Initialize `_maas_api`, build a fresh OAuth header (`_auth_header.yml`), and read every machine from MAAS (`machines/_read_machines.yml`).
2. Build per-FQDN and per-short-name lookup maps over the MAAS payload (`machines/_build_indexes.yml`): `maas_by_hostname`, `maas_host_to_macs`, `maas_host_to_ifaces`, `maas_host_to_status`, `maas_short_to_id`, `maas_by_short`, `inventory_by_short`. Fail fast if MAAS contains duplicate short hostnames.
3. Plan the create / update / delete sets (`machines/_plan_sets.yml`): `_create_short` is short names in the inventory but not in MAAS; `_delete_short` is the reverse; `_update_short` is the intersection. Hosts in `[maas_region_rack_server]`, `[maas_db_server]`, and `[maas_dont_delete]` are excluded from all three sets. `_plan_ipmi` is the union of create + update — the set we'd want to push IPMI credentials for.
4. CREATE: for each name in `_create_short`, `machines/create.yml` POSTs a skeleton machine. If IPMI creds and an `ipmi` host var are available, it ships them in the create body (so MAAS can commission the node); otherwise it creates the machine in `Deployed` state to suppress commissioning. The "Rebuild MAAS machine indexes" handler is notified.
5. `meta: flush_handlers` — re-reads `/machines/` and rebuilds the indexes so the update pass below sees the freshly-created hosts.
6. UPDATE: re-runs the planner and then, for each name in `_update_short` whose status is not `Deployed`, includes `machines/update.yml`. That file refreshes interface facts (`machines/_refresh_iface_facts.yml`), optionally marks the node `Broken` if it's not already in a state that allows interface edits (`machines/_mark_broken.yml`), reconciles each entry in `maas_interfaces` (`machines/_apply_one_iface.yml`) and each entry in `maas_bonds` (`machines/_ensure_bond.yml`), then groups MAAS subnets by VLAN id and links each iface whose MAC matches the inventory to a subnet on its VLAN (`machines/_apply_subnet.yml`).
7. IPMI: for every host in `_plan_ipmi` that has a MAAS `system_id`, `machines/set_ipmi_creds.yml` loads credentials from the secrets repo and PUTs them onto the machine (idempotent — MAAS rejects duplicates with 200/empty diff).
8. DELETE: when `maas_delete_hosts: true`, loops over `_delete_short` via `machines/delete.yml`. Currently a dry-run.
9. CLEANUP: any node we marked `Broken` earlier is moved back to its prior state via `machines/cleanup.yml` (POST `op=mark_fixed` after a GET to confirm it's still `Broken`).

Per-iface helpers (called from `update.yml`):

`machines/_apply_one_iface.yml` — resolves the parent physical interface by its inventory MAC (`<prefix>_mac`), creates it if missing (when `maas_allow_create_physical=true`), updates the parent's MTU and native VLAN, and creates any missing tagged VLAN subinterfaces listed in `iface.tagged_vids`. If the parent appears as a VLAN subinterface in MAAS, the role walks back to the underlying physical interface before issuing the native-VLAN PUT (MAAS rejects native-VLAN updates on a VLAN-typed interface).

`machines/_ensure_bond.yml` — finds an existing bond by name, falls back to matching by parent-MAC set if the name doesn't match, creates the bond via `?op=create_bond` when needed, then updates `bond_mode` / `mtu` / `link_speed` and reconciles each parent's native VLAN (`machines/_set_parent_native.yml`) and any missing tagged subinterfaces (`machines/_create_vlan_on_parent.yml`).

`machines/_apply_subnet.yml` — for each interface MAC the role recognizes from inventory, finds candidate subnets on its VLAN; if no link exists it creates one against the first candidate with the desired mode; if a link exists with the wrong mode it unlinks and relinks; if the link is already correct it skips silently.

`machines/_ensure_boot_iface.yml` — sets the node's boot interface to the inventory-defined boot MAC (`maas_boot_mac_var`). Currently invoked on demand only; `update.yml` does not include it by default.

**NOTE:** Running the entirety of the `machines` tag can take 6+ hours.  Optimization can probably done to not continuously hit the `/machines` API endpoint but getting this ansible merged was prioritized over continued optimization.

Users variables include:

keys_repo: "https://github.com/ceph/keys"
keys_branch: main
keys_repo_path: "~/.cache/src/keys"

These variables just specify the repository, path and branch where the public SSH keys are stored, MAAS needs this to be able to create users and include their SSH keys too.

## Usage

1. Clone the repository:

git clone https://github.com/ceph/ceph-cm-ansible.git
cd ceph-cm-ansible

2. Update inventory and variables.

3. Run the playbook:

ansible-playbook maas.yml

## Role Structure

maas
├── defaults
│   └── main.yml
├── meta
│   └── main.yml
├── README.md
├── tasks
│   ├── add_users.yml
│   ├── config_dhcpd_subnet.yml
│   ├── config_dns.yml
│   ├── config_maas.yml
│   ├── config_ntp.yml
│   ├── initialize_region_rack.yml
│   ├── initialize_secondary_rack.yml
│   ├── install_maasdb.yml
│   ├── machines.yml
│   ├── machines
│   │   ├── _apply_one_iface.yml
│   │   ├── _apply_subnet.yml
│   │   ├── _build_indexes.yml
│   │   ├── _create_vlan_on_parent.yml
│   │   ├── _ensure_bond.yml
│   │   ├── _ensure_boot_iface.yml
│   │   ├── _mark_broken.yml
│   │   ├── _plan_sets.yml
│   │   ├── _read_machines.yml
│   │   ├── _refresh_iface_facts.yml
│   │   ├── _set_parent_native.yml
│   │   ├── cleanup.yml
│   │   ├── create.yml
│   │   ├── delete.yml
│   │   ├── set_ipmi_creds.yml
│   │   └── update.yml
│   ├── main.yml
│   ├── networking.yml
│   └── networking
│       ├── domain_create.yml
│       ├── fabric_create.yml
│       ├── fabric_vlans_read_from_maas.yml
│       ├── space_create.yml
│       ├── subnet_apply.yml
│       ├── subnet_range_create.yml
│       ├── vlan_build_index.yml
│       ├── vlan_create.yml
│       └── vlan_update.yml
└── templates
    ├── arm_uefi.j2
    ├── dhcpd.classes.snippet.j2
    ├── dhcpd.global.snippet.j2
    ├── dhcpd.hosts.snippet.j2
    └── dhcpd.pools.snippet.j2


## Tags

- install_maas #Install MAAS and postgreSQL only and initializes the region+rack server and the secondary rack.
- add-machines #Add Machines to MAAS only if they are not already present.
- config_dhcp #Configures DHCP options only if there are any change in the DHCP variables.
- config_dns #Configure DNS domains and add the DNS Records that are not currently into a domain.
- config_maas #Configure curtin_scripts files and modify some default files in MAAS to address issues during depoyment, also it configures the global kernel parameters.
- networking #Run only the MAAS networking reconciliation tasks (Domains, Spaces, Fabrics, VLANs, Subnets, IP ranges) driven by the `maas_networking` variable.
- machines #Run only the MAAS machines reconciliation (create / update interfaces & bonds / link subnets / set IPMI / cleanup) driven by the inventory group `[maas_machines]` plus per-host `maas_*` variables.
- create_machines #Subset of `machines`: only the create pass (skeleton machine entries for hosts not yet in MAAS).
- update_machines #Subset of `machines`: only the update pass (interfaces, bonds, subnet links).
- ipmi #Subset of `machines`: only the IPMI credential push (read MAAS, plan, set creds).

# Ansible Playbook: MAAS Installation and Configuration

This Ansible playbook automates the installation and initial configuration of [MAAS (Metal as a Service)](https://maas.io/) on Ubuntu-based systems.

## Features

- Installs MAAS packages
- Initializes MAAS with a default user with High Availability
- Configures networking (DHCP, DNS, etc.)
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
│   ├── add_machines.yml
│   ├── add_users.yml
│   ├── config_dhcpd_subnet.yml
│   ├── config_dns.yml
│   ├── config_maas.yml
│   ├── config_ntp.yml
│   ├── initialize_region_rack.yml
│   ├── initialize_secondary_rack.yml
│   ├── install_maasdb.yml
│   └── main.yml
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

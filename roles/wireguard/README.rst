wireguard
=========

This role can be used to set up a WireGuard gateway (e.g., soko01) as well as
maintain the peer (user) list provided a secrets repo is configured.

It does the following:

- Installs and updates necessary packages
- Enables IPv4 forwarding
- Maintains the WireGuard config and peer list
- Makes sure the ``wg-quick@$interface`` service is running and enabled

Hosts should be added to the ``wireguard`` group in the inventory and the
playbook run with::

    ansible-playbook wireguard.yml

To only update the peer list::

    ansible-playbook wireguard.yml --tags users

To preview peer changes without applying them::

    ansible-playbook wireguard.yml --tags users --check --diff -e wireguard_force_diff=true

The server's private key is stored in a separate file
(``$wireguard_conf_dir/$wireguard_interface.key``, loaded via ``PostUp``)
rather than in the config itself.  Because the config contains peer
preshared keys, logging/diff output is suppressed unless
``wireguard_force_diff=true`` is passed.

The candidate config is validated with ``wg-quick strip`` before being
installed, and peer changes are applied to the running interface with
``wg syncconf`` so existing tunnels are not interrupted.

Prerequisites
+++++++++++++

- Ubuntu (any release with WireGuard in the kernel, i.e. 20.04+)

Variables
+++++++++

The WireGuard interface name.  This determines the config file name
(``$wireguard_conf_dir/$wireguard_interface.conf``) and the systemd service
(``wg-quick@$wireguard_interface``).  Defined in
``roles/wireguard/defaults/main.yml``::

    wireguard_interface: wg0

The directory in which the WireGuard config should be saved.  Defined in
``roles/wireguard/defaults/main.yml``::

    wireguard_conf_dir: /etc/wireguard

The UDP port WireGuard listens on.  Defined in
``roles/wireguard/defaults/main.yml``::

    wireguard_port: 51820

Whether to enable IPv4 forwarding.  Defined in
``roles/wireguard/defaults/main.yml``::

    wireguard_ip_forward: true

The server's tunnel address.  Defined in the secrets repo::

    wireguard_address: []
    # Example: wireguard_address: "192.168.100.1/24"

The server's private key (``wg genkey``).  Written to
``$wireguard_conf_dir/$wireguard_interface.key``.  Defined in the secrets
repo and should be an ansible-vault encrypted value::

    wireguard_private_key: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      ...

An optional MTU for the interface.  Defined in the secrets repo::

    wireguard_mtu: []
    # Example: wireguard_mtu: 1380

Optional lists of commands to run when the interface comes up or goes down
(e.g., firewall/NAT rules, traffic shaping).  Each entry becomes its own
``PreUp``/``PostUp``/``PreDown``/``PostDown`` line and they are executed in
order.  Defined in the secrets repo::

    wireguard_preup: []
    wireguard_postup: []
    wireguard_predown: []
    wireguard_postdown: []

Peers come from two places, both defined in the secrets repo.
``preshared_key``, ``endpoint``, and ``persistent_keepalive`` are optional
per peer/device.

Per-user peers are defined on the ``admin_users``/``lab_users`` entries in
the inventory ``group_vars`` as a ``wireguard`` list of devices.  The
``name`` on the user entry must match the username in keys.git::

    lab_users:
      - name: someuser
        wireguard:
          - name: "someuser's laptop"
            public_key: "base64pubkey="
            preshared_key: "base64psk="
            allowed_ips: "192.168.100.2/32"
          - name: "someuser's desktop"
            public_key: "base64pubkey="
            allowed_ips: "192.168.100.3/32"
        email: "someuser@example.com"

Peers not tied to a user account (other hosts, external users) go in the
standalone list::

    wireguard_peers: []

    # Example:
    wireguard_peers:
      - name: some-host
        public_key: "base64pubkey="
        allowed_ips: "192.168.100.4/32"

Tags
++++

packages
    Install *and update* packages

users
    Update the WireGuard config/peer list and sync it to the running
    interface without interrupting existing tunnels

**NOTE:** Changes to ``[Interface]`` settings (``Address``, ``ListenPort``)
are not applied by ``wg syncconf``; restart the service manually with
``systemctl restart wg-quick@$interface`` to apply those (this drops
existing tunnels).

Dependencies
++++++++++++

This role depends on the following roles:

secrets
    Provides a var, ``secrets_path``, containing the path of the secrets
    repository, a tree of ansible variable files.  This role expects a
    ``wireguard.yml`` in that tree.

nsupdate-web
============

This role sets up `nsupdate-web <https://github.com/zmc/nsupdate-web>`_ for updating dynamic DNS records.

To use the role, you must first have:

- A DNS server supporting `RFC 2136 <https://tools.ietf.org/html/rfc2136>`_. We use `bind <https://www.isc.org/downloads/bind/>`_ and the `nameserver` role to help configure ours.
- Key files stored in the location pointed to by `keys_dir`

You must set the following vars. Here are examples::

    nsupdate_web_server: "ns1.front.sepia.ceph.com"
    pubkey_name: "Kfront.sepia.ceph.com.+157+12548.key"


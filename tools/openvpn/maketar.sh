#!/bin/bash
#
# make a tarball for distribution of this configuration and
# secret generator
#
tar cfz sepia-vpn-client.tar.gz sepia/ca.crt sepia/client.conf sepia/new-client sepia/tlsauth

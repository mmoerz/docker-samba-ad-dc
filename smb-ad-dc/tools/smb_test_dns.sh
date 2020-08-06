#!/bin/bash

host -t SRV _ldap._tcp.$SAMBA_DC_REALM
host -t SRV _kerberos._udp.$SAMBA_DC_REALM
host $SAMBA_DC_HOSTNAME$SAMBA_DC_REALM

sudo samba_dnsupdate --verbose --all-names

#!/bin/bash

host -t SRV _ldap._tcp.$SAMBA_AD_REALM
host -t SRV _kerberos._udp.$SAMBA_AD_REALM
host $REMOTE_DC.$SAMBA_AD_REALM

# test all names and retry to register them
#samba_dnsupdate --use-samba-tool --verbose --all-names

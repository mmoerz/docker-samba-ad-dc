#!/bin/bash
set -e
RED='\033[0;31m'
NC='\033[0m' #no color
YEL='\033[1;33m'
GR='\033[1;32m'

ENVVARS="SAMBA_DC_DOMAIN SAMBA_DC_REALM SAMBA_DC_ADMIN_PASSWD"

SAMBA_PROVISION_TYPE=${SAMBA_PROVISION_TYPE:-SERVER}
SAMBA_PROVISION_TYPE=${SAMBA_PROVISION_TYPE^^}
REMOTE_DC=${REMOTE_DC:-NONE}
SAMBA_DC_REALM=${SAMBA_DC_REALM:-XDOM.EXAMPLE.LOCAL}
SAMBA_DC_REALM=${SAMBA_DC_REALM^^}
LOWERCASE_DOMAIN=${SAMBA_DC_REALM,,}
SAMBA_DC_DOMAIN=${LOWERCASE_DOMAIN%%.*}
SAMBA_DC_ADMIN_PASSWD=${SAMBA_DC_ADMIN_PASSWD:-youshouldchangethis}
SAMBA_DNS_BACKEND=${SAMBA_DNS_BACKEND:-SAMBA_INTERNAL}
SAMBA_DNS_FORWARDER=${SAMBA_DNS_FORWARDER:-NONE}
SAMBA_NOCOMPLEXPWD=${SAMBA_NOCOMPLEXPWD:-false}
SAMBA_DC_HOSTNAME=${SAMBA_DC_HOSTNAME:-noname}
SAMBA_DC_HOSTIP=${SAMBA_DC_HOSTIP:-NONE}

HOSTIP_OPTION=""
if [ "${SAMBA_DC_HOSTIP}" != "NONE" ]; then
	HOSTIP_OPTION="--host-ip=$SAMBA_DC_HOSTIP"
fi

perl -E 'say "=" x 100'
echo -e "${YEL}SAMBA_PROVISION_TYPE:\t\t${NC}${SAMBA_PROVISION_TYPE}"
echo -e "${YEL}REMOTE_DC:\t\t${NC}${REMOTE_DC}"
echo -e "${YEL}SAMBA_DC_REALM:\t\t${NC}${SAMBA_DC_REALM}"
echo -e "${YEL}SAMBA_DC_DOMAIN:\t${NC}${SAMBA_DC_DOMAIN}"
echo -e "${YEL}SAMBA_DC_ADMIN_PASSWD:\t${NC}${SAMBA_DC_ADMIN_PASSWD}"
echo -e "${YEL}SAMBA_DNS_BACKEND:\t${NC}${SAMBA_DNS_BACKEND}"
echo -e "${YEL}SAMBA_DNS_FORWARDER:\t${NC}${SAMBA_DNS_FORWARDER}"
echo -e "${YEL}SAMBA_NOCOMPLEXPWD:\t${NC}${SAMBA_NOCOMPLEXPWD}"
echo -e "${YEL}SAMBA_DC_HOSTNAME:\t\t${NC}${SAMBA_DC_HOSTNAME}"
echo -e "${YEL}SAMBA_DC_HOSTIP:\t\t${NC}${SAMBA_DC_HOSTIP}"

function patch_resolv {
cat > /etc/resolv.conf <<EOF
nameserver $1
search ${SAMBA_DC_REALM,,}
options ndots:0
EOF
}

if [ ! -f /etc/samba/smb.conf ]; then
    if [ ${SAMBA_PROVISION_TYPE} == "SERVER" ] ; then
        echo -e "samba-tool domain provision --domain=${SAMBA_DC_DOMAIN} \
            --adminpass=${SAMBA_DC_ADMIN_PASSWD} \
            --server-role=dc \
            --realm=${SAMBA_DC_REALM} \n \
            --dns-backend=${SAMBA_DNS_BACKEND} \
            --host-name=${SAMBA_DC_HOSTNAME} \
            --use-rfc2307 \
            ${HOSTIP_OPTION}"
        samba-tool domain provision --domain="${SAMBA_DC_DOMAIN}" \
            --adminpass="${SAMBA_DC_ADMIN_PASSWD}" \
            --server-role=dc \
            --realm="${SAMBA_DC_REALM}" \
            --dns-backend="${SAMBA_DNS_BACKEND}" \
            --host-name="${SAMBA_DC_HOSTNAME}" \
            --use-rfc2307 \
            ${HOSTIP_OPTION}
#            --option="allow dns updates = disabled"
        sleep 5
        if [ "${SAMBA_NOCOMPLEXPWD,,}" = "true" ]; then
            echo "samba-tool domain passwordsettings set --complexity=off"
            samba-tool domain passwordsettings set --complexity=off
            samba-tool domain passwordsettings set --history-length=0
            samba-tool domain passwordsettings set --min-pwd-age=0
            samba-tool domain passwordsettings set --max-pwd-age=0
        fi
    else
	 # time should be checked prior!!!
         # join preparations
	 patch_resolv $REMOTE_DC
	 cat > /etc/krb5.conf <<EOF
[libdefaults]
    dns_lookup_realm = false
    dns_lookup_kdc = true
    default_realm = ${SAMBA_DC_REALM}
EOF
         # test if dns and kerberos connection work
         #apt-get install expect
	 #cat > /root/kinit_test.expect <<EOF
##!/bin/expect
#
#set pwd "${SAMBA_DC_ADMIN_PASSWD}"
#
#spawn /usr/bin/kinit administrator
#
#expect "assword for administrator@${SAMBA_DC_REALM}: "
#send "\$pwd"
#EOF
#	 /usr/bin/expect /root/kinit_test.expect
	 echo "${SAMBA_DC_ADMIN_PASSWD}" | kinit administrator
	 klist
	 RC=$?
	 # now join the domain
	 if [ $RC -eq 0 ]; then
             echo -e "${GR} ************************************"
             echo -e "${GR} JOINING DOMAIN ${SAMBA_DC_REALM} now" 
             echo -e "${GR} ************************************"
	     samba-tool domain join ${SAMBA_DC_REALM} DC -k yes
         fi
    fi

    if [ "${SAMBA_DNS_FORWARDER}" != "NONE" ]; then
        sed -i "/\[global\]/a \
            \\\tdns forwarder = ${SAMBA_DNSFORWARDER}\
            " /etc/samba/smb.conf
    fi
    # link kerberos config (so that it may be modified)
    rm /etc/krb5.conf
    ln -s /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi

patch_resolv 127.0.0.1

if [ "$1" = 'samba' ]; then
    exec samba -i < /dev/null
fi

exec "$@"

#!/bin/bash
set -e
RED='\033[0;31m'
NC='\033[0m' #no color
YEL='\033[1;33m'

ENVVARS="SAMBA_DC_DOMAIN SAMBA_DC_REALM SAMBA_DC_ADMIN_PASSWD"

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
echo -e "${YEL}SAMBA_DC_REALM:\t\t${NC}${SAMBA_DC_REALM}"
echo -e "${YEL}SAMBA_DC_DOMAIN:\t${NC}${SAMBA_DC_DOMAIN}"
echo -e "${YEL}SAMBA_DC_ADMIN_PASSWD:\t${NC}${SAMBA_DC_ADMIN_PASSWD}"
echo -e "${YEL}SAMBA_DNS_BACKEND:\t${NC}${SAMBA_DNS_BACKEND}"
echo -e "${YEL}SAMBA_DNS_FORWARDER:\t${NC}${SAMBA_DNS_FORWARDER}"
echo -e "${YEL}SAMBA_NOCOMPLEXPWD:\t${NC}${SAMBA_NOCOMPLEXPWD}"
echo -e "${YEL}SAMBA_DC_HOSTNAME:\t\t${NC}${SAMBA_DC_HOSTNAME}"
echo -e "${YEL}SAMBA_DC_HOSTIP:\t\t${NC}${SAMBA_DC_HOSTIP}"

if [ ! -f /etc/samba/smb.conf ]; then
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
#        --option="allow dns updates = disabled"
    sleep 5
    if [ "${SAMBA_NOCOMPLEXPWD,,}" = "true" ]; then
        echo "samba-tool domain passwordsettings set --complexity=off"
	samba-tool domain passwordsettings set --complexity=off
	samba-tool domain passwordsettings set --history-length=0
	samba-tool domain passwordsettings set --min-pwd-age=0
	samba-tool domain passwordsettings set --max-pwd-age=0
    fi
    if [ "${SAMBA_DNS_FORWARDER}" != "NONE" ]; then
        sed -i "/\[global\]/a \
            \\\tdns forwarder = ${SAMBA_DNSFORWARDER}\
            " /etc/samba/smb.conf
    fi
    # copy kerberos config
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi
# fix dns resolv
cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1
search ${SAMBA_DC_REALM,,}
options ndots:0
EOF


if [ "$1" = 'samba' ]; then
    exec samba -i < /dev/null
fi

exec "$@"

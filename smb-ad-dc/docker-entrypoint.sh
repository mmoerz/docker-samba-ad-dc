#!/bin/bash
set -e
RED='\033[0;31m'
NC='\033[0m' #no color
YEL='\033[1;33m'
GR='\033[1;32m'

ENVVARS="SAMBA_DOMAIN SAMBA_AD_REALM SAMBA_AD_ADMIN_PASSWD"

SAMBA_PROVISION_TYPE=${SAMBA_PROVISION_TYPE:-SERVER}
SAMBA_PROVISION_TYPE=${SAMBA_PROVISION_TYPE^^}
REMOTE_DC=${REMOTE_DC:-NONE}
SAMBA_AD_REALM=${SAMBA_AD_REALM:-XDOM.EXAMPLE.LOCAL}
SAMBA_AD_REALM=${SAMBA_AD_REALM^^}
LOWERCASE_DOMAIN=${SAMBA_AD_REALM,,}
SAMBA_DOMAIN=${LOWERCASE_DOMAIN%%.*}
SAMBA_AD_ADMIN_PASSWD=${SAMBA_AD_ADMIN_PASSWD:-youshouldchangethis}
SAMBA_DNS_BACKEND=${SAMBA_DNS_BACKEND:-SAMBA_INTERNAL}
SAMBA_DNS_FORWARDER=${SAMBA_DNS_FORWARDER:-NONE}
SAMBA_NOCOMPLEXPWD=${SAMBA_NOCOMPLEXPWD:-false}
SAMBA_HOSTNAME=${SAMBA_HOSTNAME:-noname}
SAMBA_HOSTIP=${SAMBA_HOSTIP:-NONE}

HOSTIP_OPTION=""
if [ "${SAMBA_HOSTIP}" != "NONE" ]; then
	HOSTIP_OPTION="--host-ip=$SAMBA_HOSTIP"
fi

set +e
md5sum -c <<EOF
25979b7571c1cf2e79ae9a0f9e676c8a  /etc/samba/smb.conf
EOF
if [ $? -eq 0 ]; then
	echo -e "${GR}default alpine smb.conf found, deleting"
	rm /etc/samba/smb.conf
fi
set -e

perl -E 'say "=" x 100'
echo -e "${YEL}PARAM1: $1"
echo 
echo -e "${YEL}SAMBA_PROVISION_TYPE:\t\t${NC}${SAMBA_PROVISION_TYPE}"
echo -e "${YEL}REMOTE_DC:\t\t${NC}${REMOTE_DC}"
echo -e "${YEL}SAMBA_AD_REALM:\t\t${NC}${SAMBA_AD_REALM}"
echo -e "${YEL}SAMBA_DOMAIN:\t${NC}${SAMBA_DOMAIN}"
echo -e "${YEL}SAMBA_AD_ADMIN_PASSWD:\t${NC}${SAMBA_AD_ADMIN_PASSWD}"
echo -e "${YEL}SAMBA_DNS_BACKEND:\t${NC}${SAMBA_DNS_BACKEND}"
echo -e "${YEL}SAMBA_DNS_FORWARDER:\t${NC}${SAMBA_DNS_FORWARDER}"
echo -e "${YEL}SAMBA_NOCOMPLEXPWD:\t${NC}${SAMBA_NOCOMPLEXPWD}"
echo -e "${YEL}SAMBA_HOSTNAME:\t\t${NC}${SAMBA_HOSTNAME}"
echo -e "${YEL}SAMBA_HOSTIP:\t\t${NC}${SAMBA_HOSTIP}"

function patch_resolv {
cat > /etc/resolv.conf <<EOF
nameserver $1
search ${SAMBA_AD_REALM,,}
options ndots:0
EOF
}

function create_fileserver_smbconf {
cat > /etc/samba/smb.conf <<EOF
[global]
	security = ADS
	workgroup = ${SAMBA_DOMAIN}
	realm = ${SAMBA_AD_REALM}

	log file = /var/log/samba/%m.log
	log level = 1

	idmap config * : backend = autorid
	idmap config * : range = 10000 - 999999

	username map = /etc/samba/user.map

[sysvol]
	path = /var/lib/samba/sysvol
	read only = No

EOF
cat > /etc/samba/user.map <<EOF
!root = ${SAMBA_DOMAIN}\Administrator
EOF
if [ ! -d /var/lib/samba/private ]; then
	mkdir -p /var/lib/samba/private
fi
}

function fix_etchosts {
	sed -e "s/\(.*\)${SAMBA_HOSTNAME}/\1${SAMBA_HOSTNAME}\.${LOWERCASE_DOMAIN} ${SAMBA_HOSTNAME}/" \
		/etc/hosts > /etc/hosts.bak
	cp /etc/hosts.bak /etc/hosts
}

if [ ! -f /etc/samba/smb.conf ]; then
    if [ ${SAMBA_PROVISION_TYPE} == "SERVER" ] ; then
        echo -e "samba-tool domain provision --domain=${SAMBA_DOMAIN} \
            --adminpass=${SAMBA_AD_ADMIN_PASSWD} \
            --server-role=dc \
            --realm=${SAMBA_AD_REALM} \n \
            --dns-backend=${SAMBA_DNS_BACKEND} \
            --host-name=${SAMBA_HOSTNAME} \
            --use-rfc2307 \
            ${HOSTIP_OPTION}"
        samba-tool domain provision --domain="${SAMBA_DOMAIN}" \
            --adminpass="${SAMBA_AD_ADMIN_PASSWD}" \
            --server-role=dc \
            --realm="${SAMBA_AD_REALM}" \
            --dns-backend="${SAMBA_DNS_BACKEND}" \
            --host-name="${SAMBA_HOSTNAME}" \
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
        echo -e "Provisioning Member"
	 # time should be checked prior!!!
         # join preparations
	 patch_resolv $REMOTE_DC
	 cat > /etc/krb5.conf <<EOF
[libdefaults]
    dns_lookup_realm = false
    dns_lookup_kdc = true
    default_realm = ${SAMBA_AD_REALM}
EOF
         # test if dns and kerberos connection work
         #apt-get install expect
	 #cat > /root/kinit_test.expect <<EOF
##!/bin/expect
#
#set pwd "${SAMBA_AD_ADMIN_PASSWD}"
#
#spawn /usr/bin/kinit administrator
#
#expect "assword for administrator@${SAMBA_DC_REALM}: "
#send "\$pwd"
#EOF
#	 /usr/bin/expect /root/kinit_test.expect
	 echo "${SAMBA_AD_ADMIN_PASSWD}" | kinit administrator
	 klist
	 RC=$?
	 # now join the domain
    	 if [ "${SAMBA_PROVISION_TYPE}" == "2ndDC" ]; then
	     if [ $RC -eq 0 ]; then
             	echo -e "${GR} ******************************************"
             	echo -e "${GR} JOINING DOMAIN ${SAMBA_AD_REALM} as DC now" 
             	echo -e "${GR} ******************************************"
	        samba-tool domain join ${SAMBA_AD_REALM} DC -k yes
             fi
	 fi
    	 if [ "${SAMBA_PROVISION_TYPE}" == "MEMBER" ]; then
	     if [ $RC -eq 0 ]; then
             	echo -e "${GR} **********************************************"
             	echo -e "${GR} JOINING DOMAIN ${SAMBA_AD_REALM} as Member now" 
             	echo -e "${GR} **********************************************"
		create_fileserver_smbconf 
	        samba-tool domain join ${SAMBA_AD_REALM} MEMBER -k yes
             fi
	 fi
    fi

    if [ "${SAMBA_DNS_FORWARDER}" != "NONE" ]; then
        sed -i "/\[global\]/a \
            \\\tdns forwarder = ${SAMBA_DNS_FORWARDER}\
            " /etc/samba/smb.conf
    fi
else 
	echo -e "${GR} /etc/samba/smb.conf exists, no provisioning"
fi
if [ ! -e /etc/samba/smb.conf ]; then
	echo -e "${RED} /etc/samba/smb.conf was not created"
fi

# link kerberos config (so that it may be modified)
if [ -f /var/lib/samba/private/krb5.conf ]; then
	echo -e "replacing krb5.conf with samba version"
	rm -f /etc/krb5.conf
	ln -s /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi
# extend lookup to use winbind
sed -i -e "s/\(passwd:.*\)/\1 winbind/" \
    -e "s/\(group:.*\)/\1 winbind/" /etc/nsswitch.conf


if [ "${SAMBA_PROVISION_TYPE}" != "MEMBER" ]; then
	patch_resolv 127.0.0.1
else
	fix_etchosts
	patch_resolv ${REMOTE_DC}
fi

if [ "$1" = 'samba' ]; then
    exec samba -i < /dev/null
fi
if [ "$1" = 'samba-member' ]; then
    exec /usr/bin/supervisord -n < /dev/null
fi

exec "$@"

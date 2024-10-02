#!/bin/bash
set -e
RED='\033[0;31m'
NC='\033[0m' #no color
YEL='\033[1;33m'
GR='\033[1;32m'

#ENVVARS="SAMBA_DOMAIN SAMBA_AD_REALM SAMBA_AD_ADMIN_PASSWD"

# as it seems, hostname is not a good idea to configure script based
# use docker mechanism to do that
#
HOSTNAME=$(hostname)
#
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
#SAMBA_HOSTNAME=${SAMBA_HOSTNAME:-noname}
SAMBA_HOSTIP=${SAMBA_HOSTIP:-NONE}
SAMBA_DEBUG=${SAMBA_DEBUG:-0}
SAMBA_DEBUG=$(("${SAMBA_DEBUG}"))
SAMBA_RESOLVCONF=${SAMBA_RESOLVCONF:-READONLY^^}

HOSTIP_OPTION=""
if [ "${SAMBA_HOSTIP}" != "NONE" ]; then
	HOSTIP_OPTION="--host-ip=$SAMBA_HOSTIP"
fi

set +e
# alpine 3.17 25979b7571c1cf2e79ae9a0f9e676c8a
#md5sum -c <<EOF
#078fdd0eb6e940e070ba7d1b6bbc2d45  /etc/samba/smb.conf
#EOF
# alpine 3.19 
md5sum -c <<EOF
8b59f36f371f92600fed2c4b3a95764d  /etc/samba/smb.conf
EOF

if [ $? -eq 0 ]; then
  echo -e "${GR}default alpine smb.conf found, deleting"
  rm /etc/samba/smb.conf
elif [ $SAMBA_DEBUG -gt 0 ]; then
  if [ -f /etc/samba/smb.conf ] ; then
 	  echo -e "${YEL}user generated smb.conf detected, keeping it."
    # if debug enabled, output md5sum (for replacing new default md5sum)
    md5sum /etc/samba/smb.conf
  else
 	  echo -e "${YEL}smb.conf not found."
  fi
fi
set -e

perl -E 'say "=" x 80'
echo -e "${YEL}PARAM1: $1"
echo
echo -e "${YEL}SAMBA_DEBUG:\t${SAMBA_DEBUG}"
echo -e "${GR}SYSTEM SETTINGS"
echo -e "${YEL}HOSTNAME:\t${NC}$HOSTNAME"
echo -e 
echo -e "${YEL}SAMBA_PROVISION_TYPE:\t${NC}${SAMBA_PROVISION_TYPE}"
echo -e "${YEL}REMOTE_DC:\t\t${NC}${REMOTE_DC}"
echo -e "${YEL}SAMBA_AD_REALM:\t\t${NC}${SAMBA_AD_REALM}"
echo -e "${YEL}SAMBA_DOMAIN:\t\t${NC}${SAMBA_DOMAIN}"
echo -e "${YEL}SAMBA_AD_ADMIN_PASSWD:\t${NC}${SAMBA_AD_ADMIN_PASSWD}"
echo -e "${YEL}SAMBA_DNS_BACKEND:\t${NC}${SAMBA_DNS_BACKEND}"
echo -e "${YEL}SAMBA_DNS_FORWARDER:\t${NC}${SAMBA_DNS_FORWARDER}"
echo -e "${YEL}SAMBA_NOCOMPLEXPWD:\t${NC}${SAMBA_NOCOMPLEXPWD}"
# maybe pick that up automatically as well?
echo -e "${YEL}SAMBA_HOSTIP:\t\t${NC}${SAMBA_HOSTIP}"
echo -e "${YEL}SAMBA_RESOLVCONF:\t\t${NC}${SAMBA_RESOLVCONF}"

##### BEGIN of function definitions

function patch_resolv {
  NEWNAMESERVER=$1
  echo -e "${RED}==== old resolv.conf"
cat /etc/resolv.conf
  echo -e "${RED}==== END old resolv.conf"

  if [ "X$1" == "XNONE" ] ; then
    echo -e "${GR}ignoring NONE"
    return
  fi
  if [ "X${SAMBA_RESOLVCONF}" == "XREADONLY" ] ; then
    echo -e "${GR}/etc/resolv.conf is provided by docker"
    return
  elif [ "X${SAMBA_RESOLVCONF}" == "XLOCALHOST" ] ; then
    echo -e "${GR} using localhost for resolv.conf"
    NEWNAMESERVER="127.0.0.1"
  elif [ "X${SAMBA_RESOLVCONF}" == "XHOSTIP" ] ; then
    echo -e "${GR} using HOSTIP for resolv.conf"
    NEWNAMESERVER=${SAMBA_HOSTIP}
  fi

  echo -e "${RED}overwriting resolv.conf"
  echo -e "${YEL}setting nameserver ${NEWNAMESERVER}"
cat > /etc/resolv.conf <<EOF
nameserver ${NEWNAMESERVER}
search ${SAMBA_AD_REALM,,}
options ndots:0
EOF
}

function create_default_krb5_conf {
  echo "writing /etc/krb5.conf"
  cat > /etc/krb5.conf <<EOF
[libdefaults]
    dns_lookup_realm = false
    dns_lookup_kdc = true
    default_realm = ${SAMBA_AD_REALM}
EOF
}

function create_fileserver_smbconf {
  echo "creating fileserver smb.conf"
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
  # krbtab - see with klist -k
  dedicated keytab file = /etc/krb5.keytab
  kerberos method = secrets and keytab
  winbind refresh tickets = Yes

[sysvol]
	path = /var/lib/samba/sysvol
	read only = No

EOF
  echo "creating /etc/samba/user.map"
cat > /etc/samba/user.map <<EOF
!root = ${SAMBA_DOMAIN}\Administrator
EOF
if [ ! -d /var/lib/samba/private ]; then
	mkdir -p /var/lib/samba/private
fi
}

function fix_etchosts {
	echo -e "rewriting hosts file inplace"
	fhelp=`grep ${LOWERCASE_DOMAIN} /etc/hosts | wc -l`
	if [ "$fhelp" == "0" ] ; then
	  (rc=$(sed -e "s/\(.*\)${HOSTNAME}/\1${HOSTNAME}\.${LOWERCASE_DOMAIN} ${HOSTNAME}/" /etc/hosts); \
       	  echo "$rc" > /etc/hosts)
	  [ "$?" == "0" ] && echo -e "${GR}rewrite successfull"
	else
		echo -e "${GR} already replaced"
	fi
}

# only checks hosts file for fqdn
function check_etchosts {
  echo -ne "checking /etc/hosts entries: "
	fhelp=`grep ${LOWERCASE_DOMAIN} /etc/hosts | wc -l`
	if [ "$fhelp" == "0" ] ; then
    echo -e "${RED}missing fqdn for server in hosts file"
  else
    echo -e "${GR} fqdn for server in hosts file"
  fi
  if [ ${SAMBA_DEBUG} -gt 0 ] ; then
    echo ==== /etc/hosts
    grep ${LOWERCASE_DOMAIN} /etc/hosts
    echo ==== /etc/hosts
    HOSTNAME=`hostname`
    HOSTNAMED=`hostname -d`
    echo ${HOSTNAME} ${HOSTNAMED}
  fi
}

##### END of function defs 

##### script starts here

# check hosts file for fqdn
check_etchosts

if [ ! -f /etc/samba/smb.conf ]; then
    if [ ${SAMBA_PROVISION_TYPE} == "SERVER" ] ; then
        echo -e "samba-tool domain provision --domain=${SAMBA_DOMAIN} \
            --adminpass=${SAMBA_AD_ADMIN_PASSWD} \
            --server-role=dc \
            --realm=${SAMBA_AD_REALM} \n \
            --dns-backend=${SAMBA_DNS_BACKEND} \
            --host-name=${HOSTNAME} \
            --use-rfc2307 \
            ${HOSTIP_OPTION}"
        samba-tool domain provision --domain="${SAMBA_DOMAIN}" \
            --adminpass="${SAMBA_AD_ADMIN_PASSWD}" \
            --server-role=dc \
            --realm="${SAMBA_AD_REALM}" \
            --dns-backend="${SAMBA_DNS_BACKEND}" \
            --host-name="${HOSTNAME}" \
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
      echo -e "hopefully the time is set correctly"
      # time should be checked prior!!!
      # join preparations
      patch_resolv $REMOTE_DC
      create_default_krb5_conf
        
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
      # fix missing ldbs
      if [ ! -f /var/lib/samba/private/secrets.ldb ] ; then
        echo "trying to restore /var/lib/samba"
        if [ -f /root/var_lib_samba.tgz ] ; then
          cd / ; tar -xzf /root/var_lib_samba.tgz ;
          echo "/var/lib/samba restored"
        fi
      fi

      echo "setting up kinit"
      echo "${SAMBA_AD_ADMIN_PASSWD}" | kinit administrator 
      #-c KRB5CCNAME
      klist 
      #-c KRB5CCNAME
      RC=$?
      echo "klist: ${RC}"
      # now join the domain
      if [ "${SAMBA_PROVISION_TYPE}" == "2NDDC" ]; then
        if [ $RC -eq 0 ]; then
          echo -e "${GR} ******************************************"
          echo -e "${GR} JOINING DOMAIN ${SAMBA_AD_REALM} as DC now" 
          echo -e "${GR} ******************************************"
          samba-tool domain join ${SAMBA_AD_REALM} DC --use-kerberos 
            #--use-krb5-ccache=KRB5CCNAME
        fi
      fi
      if [ "${SAMBA_PROVISION_TYPE}" == "MEMBER" ]; then
        if [ $RC -eq 0 ]; then
          echo -e "${GR} **********************************************"
          echo -e "${GR} JOINING DOMAIN ${SAMBA_AD_REALM} as Member now" 
          echo -e "${GR} **********************************************"
          # hmm that is the other difference
          create_fileserver_smbconf 

          # restore 
          # bugfix for samba - THX!!
          if [ ! -f /var/lib/samba/private/secrets.ldb ] ; then
          ldbadd -H /var/lib/samba/private/secrets.ldb </dev/null
          fi
          if [ ! -f /var/lib/samba/private/sam.ldb ] ; then
          ldbadd -H /var/lib/samba/private/sam.ldb </dev/null
          fi

          check_etchosts
          fix_etchosts
          echo -e "${GR} joining ${SAMBA_AD_REALM} as member"
          # -N nopass (otherwise it freaks and asks for a pwd)
          samba-tool domain join ${SAMBA_AD_REALM} MEMBER \
            -N \
            --use-kerberos=required 
            #--use-krb5-ccache=KRB5CCNAME
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

# create kerberos config (so that it may be modified)
if [ -f /var/lib/samba/private/krb5.conf ]; then
	echo -e "replacing krb5.conf with samba version"
  mv /etc/krb5.conf /etc/krb5.conf.orig
	# according to provisioning script symlinking is bad, so copy
	cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
fi
# extend lookup to use winbind
sed -i -e "s/\(passwd:.*\)/\1 winbind/" \
    -e "s/\(group:.*\)/\1 winbind/" /etc/nsswitch.conf


if [ "${SAMBA_PROVISION_TYPE}" != "MEMBER" ]; then
	patch_resolv 127.0.0.1
else
  check_etchosts
	fix_etchosts
  # maybe this is a problem on a 2nd dc
	patch_resolv ${REMOTE_DC}
  create_default_krb5_conf
fi

cat <<EOF
Ignore TSIG errors !
According to google group post this happens with internal samba dns
server and can be safely ignored (2015)

/usr/sbin/samba_dnsupdate: ; TSIG error with server: tsig verify failure

https://groups.google.com/g/linux.samba/c/LguyNFTdCPM
EOF


#if [ "$1" = 'samba' ]; then
#if [ "$1" = 'samba-member' ]; then
case "${SAMBA_PROVISION_TYPE}" in
  "SERVER" | "2NDDC")
    exec samba -i < /dev/null
    ;;
  "MEMBER")
    CONFFILE=/etc/supervisor/supervisord.conf
    if [ -f ${CONFFILE} ]; then 
      echo "file >${CONFFILE}< exists" 
    else 
      CONFFILE=/etc/supervisord.conf 
    fi
    exec /usr/bin/supervisord -n -c ${CONFFILE} < /dev/null 
    ;;
  *)
    echo -e ${RED} Unknown Provisioning type: ${SAMBA_PROVISION_TYPE} detected
    ;;
esac

exec "$@"

FROM ubuntu:focal
MAINTAINER natoka <natoka AT natoka dot de>

#
# TODO: volume for private, shares missing
#
VOLUME ["/var/lib/samba", "/etc/samba", "/var/log/samba"]
ENV DEBIAN_FRONTEND noninteractive

#COPY smb.conf /etc/samba/smb.conf

# PKG: acl for getfacl & setfacl
# winbindd is a must for ac dc
RUN apt-get clean && apt-get update && \
    apt-get install -y attr acl samba smbclient samba-vfs-modules winbind libnss-winbind libpam-winbind
RUN apt-get install -y ldap-utils ldb-tools cifs-utils smbldap-tools 
RUN apt-get install -y vim
RUN apt-get install -y openssl && \
    apt-get autoclean && \
    rm -rf /var/cache/apt/archives/*

COPY facl-test.sh /root/facl-test.sh
COPY docker-entrypoint.sh /root/docker-entrypoint.sh
COPY sysvol_reset.sh /root/sysvol_reset.sh
COPY sysvol_extreset.sh /root/sysvol_extreset.sh
RUN chmod +x /root/*.sh

ENTRYPOINT ["/root/docker-entrypoint.sh"]
CMD ["samba"]



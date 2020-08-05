FROM ubuntu:focal
MAINTAINER natoka <natoka AT natoka dot de>

#
# TODO: volume for private
#
VOLUME ["/var/lib/samba", "/etc/samba", "/var/log/samba", "/srv/shares"]
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

# create directory for shares not needed is a volume!
#RUN mkdir -f /srv/shares

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY tools /root/tools
RUN chmod +x /root/tools/*.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["samba"]

FROM mmoerz/docker-samba-ad-dc:4.20 
MAINTAINER Michael Moerz <michael AT moerz dot co dot at .>

ARG version
ARG build_date

#
# TODO: volume for private
#
VOLUME ["/var/lib/samba", "/etc/samba", "/etc/cups/", "/var/log/samba", "/srv/shares"]
ENV DEBIAN_FRONTEND noninteractive
ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/var/run/dbus/system_bus_socket"

#COPY smb.conf /etc/samba/smb.conf

# PKG: acl for getfacl & setfacl
# winbindd is a must for ac dc
RUN apt-get clean && apt-get update && \
    apt-get install -y cups-server-common \
         cups cups-client \
         dbus avahi-daemon
# tools for debugging
#RUN apt-get install -y vim bind9-host krb5-user iputils-ping iproute2
RUN apt-get autoclean && \
    rm -rf /var/cache/apt/archives/*

# create directory for shares not needed is a volume!
#RUN mkdir -f /srv/shares

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY tools /root/tools
RUN chmod +x /root/tools/*.sh
# backup /var/lib/samba
RUN tar -czf /root/etc_cups.tgz /etc/cups
COPY dbus.conf /etc/dbus-1/system.d/dbus.conf

LABEL org.label-schema.build-date=$build_date org.label-schema.vcs-url="https://github.com/mmoerz/docker-samba-ad-ac" org.label-schema.vcs-ref=$version org.label-schema.schema-version="1.0"

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["samba"]

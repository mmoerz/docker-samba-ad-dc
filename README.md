# docker-samba-ad-dc

[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

ubuntu based docker container for samba active directory server

This was inspired by other older docker containers that either don't work or use completely outdated versions of samba. To fullfill my own requirements, I wrote this from scratch.

# Limitations

The container *needs* a macvtap based network. You may try other network types, however you have been warned, it will most likely not work without problems.

## Running

Setup your own samba.env file with your choice of options by copying the example.

``cp samba.env.example samba.env``

Then start the container. It will immediatly provision the domain and start samba afterwards.

### Environment Variables explained

The environment variables are passed on to the domain provising of samba-tool. For in-depth information see [Samba Documentation](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Parameter_Explanation)

* SAMBA_DC_HOSTNAME=dc 

if you change this, you will need to change the hostname in the dockerfile as well

* SAMBA_DC_HOSTIP=
should be left empty (is a leftover from trying to make it work with host network)

* SAMBA_DC_ADMIN_PASSWD=replacePassword
Yeah for real, please change this to something secure.

* SAMBA_DC_REALM=my.domain
replace with your active directory domain name

* SAMBA_DNS_BACKEND=SAMBA_INTERNAL
should be left alone

* SAMBA_DNS_FORWARDER=192.168.1.254
Sets the dns server that dns queries are forwarded to.

* SAMBA_NOCOMPLEXPWD=true
If true then sets the password complexity to off, expiry and password history is turned off as well, otherwise password complexity is left alone. 

## Volumes

As the docker file defines, and the docker-compose file configures, those are the volumes:

/etc/samba
/var/lib/samba
/var/log/samba
/srv/shares

## Building

You can either use the following command to build the docker image for the samba ad dc:

``build.sh``

or simple use docker-compose

``docker-compose build``

There are other docker-compose files present that will most likely not work as expected.


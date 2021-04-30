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

The environment variables are passed on to the domain provising of samba-tool.
For in-depth information see the fine [Samba Wiki](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Parameter_Explanation) on
[samba-tool](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Provisioning_a_Samba_Active_Directory).

``` SAMBA_DC_HOSTNAME=dc ``` | Hostname of the containerized domain controller. If you change this, you will need to change the hostname in the dockerfile as well.

``` SAMBA_DC_HOSTIP= ``` | should be left alone (is a leftover from trying to make it work with host network)

```SAMBA_DC_ADMIN_PASSWD=replacePassword``` | Yeah for real, please change this to something secure.

```SAMBA_DC_REALM=my.domain``` | replace with your active directory domain name

```SAMBA_DNS_BACKEND=SAMBA_INTERNAL``` | should be left alone

```SAMBA_DNS_FORWARDER=192.168.1.254``` | Sets the dns server that dns queries are forwarded to.

```SAMBA_NOCOMPLEXPWD=true``` | If true then sets the password complexity to off, expiry and password history is turned off as well, otherwise password complexity is left alone. 

## Volumes

As the docker file defines, and the docker-compose file configures, those are the volumes:

volume      | purpose
/etc/samba | config files
/var/lib/samba | sysvolume
/var/log/samba | logfiles
/srv/shares | shares and their files

You can point those to the paths of your liking, e.g:

```
      - /srv/docker/samba/etc:/etc/samba:rw
      - /srv/docker/samba/sys:/var/lib/samba:rw
      - /srv/docker/samba/log:/var/log/samba:rw
      - /srv/docker/samba/shares:/srv/shares:rw
```

## Joining a domain as a dc

Be warned, this are my own notes and may or may not work:

###
* hot backup idmap


* rsync sysvol
[SysVol replication](https://wiki.samba.org/index.php/SysVol_replication_(DFS-R))

### fsmo transfer / seizure
Ideas shamelessly copied from 
[Samba documentation - fsmo](https://wiki.samba.org/index.php/Transferring_and_Seizing_FSMO_Roles#Transferring_an_FSMO_Role)
```samba-tool fsmo show```

```samba-tool fsmo transfer --role=...```

### check things 

```samba-tool fsmo show```

### demote old dc
!!! On the old dc run the following command

```
samba-tool domain demote -Uadministrator
```
Shameless copy from
[Samba documentation](https://wiki.samba.org/index.php/Demoting_a_Samba_AD_DC)

## Building

You can either use the following command to build the docker image for the samba ad dc:

``build.sh``

or simple use docker-compose

``docker-compose build``

There are other docker-compose files present that will most likely not work as expected.


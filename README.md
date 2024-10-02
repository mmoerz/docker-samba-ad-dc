# docker-samba-ad-dc

[![Project Status: Active](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)

alpine based docker container for samba active directory server.

This was inspired by other older docker containers that either don't work or
use completely outdated versions of samba. 
To fullfill my own set of requirements, I wrote this from scratch.

# Limitations

The container *needs* a macvtap based network. You may try other network 
types, however you have been warned, it will most likely not work without problems.

## Preflight

Well since there is only the *macvtap* route (for me at least) there
is no need for an overly complex docker-compose.yml. This makes setting up
easier. Just copy (or link) your choice of docker-copose.yml and set the
values inside.

Since we roll with a *macvtap* setup, you need to setup a user-defined
network for it in docker that is called 'samba-network'. You can use the
script `create-network.sh` or run:

```
docker network create -d macvlan \
    --subnet=<SUBNET> \
    --gateway=<GATEWAY>  \
    --ip-range=<SUBNET> \
    -o parent=<network-interface> samba-network
```
replace the <> values accordingly. This only needs to be done once on a docker
host, because it will persist (until deleted).


Setup your own samba.env file with your choice of options by copying the 
example and editing the values.

``cp samba.env.example samba.env``

Setup volumes by switching to the directory where you want to place the
volume directories for the samba containers. Then execute ``create-volume.sh``.

Setup network by editing the file create-network.sh and maybe replacing ``br0``
with your choice of device to bind the network to.

## Starting the addc

Start the container of the activedomain controller. 

``docker-compose start samba``

It will immediatly provision the domain and start samba afterwards.

### Environment Variables explained

The environment variables are passed on to the domain provising of samba-tool.
For in-depth information see the fine [Samba Wiki](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Parameter_Explanation) on
[samba-tool](https://wiki.samba.org/index.php/Setting_up_Samba_as_an_Active_Directory_Domain_Controller#Provisioning_a_Samba_Active_Directory).

parameter | purpose
--------- | --------
``` SAMBA_PROVISION_TYPE ``` | SERVER for an AD server, 2ndDC for a secondary AD server that joins an existing domain. MEMBER for joining the (file) server to an existing domain.
``` REMOTE_DC ``` | must be set for 2ndDC and MEMBER provisioning
``` SAMBA_AD_REALM=my.domain``` | replace with your active directory domain name
``` SAMBA_DOMAIN ``` | domain name (must match AD Realm accordingly!)
``` SAMBA_AD_ADMIN_PASSWD=replacePasswd ``` | Yeah for real, please change this to something secure.
``` SAMBA_DNS_BACKEND=SAMBA_INTERNAL``` | should be left alone
``` SAMBA_DNS_FORWARDER=192.168.1.254``` | Sets the dns server that dns queries are forwarded to.
``` SAMBA_NOCOMPLEXPWD=true``` | If true then sets the password complexity to off, expiry and password history is turned off as well, otherwise password complexity is left alone. 
``` SAMBA_HOSTNAME=dc ``` | Hostname of the containerized domain controller. If you change this, you will need to change the hostname in the dockerfile as well.
``` SAMBA_HOSTIP= ``` | should be left alone (is a leftover from trying to make it work with host network)
`` SAMBA_DEBUG | default is 0, if not zero entrypoint script will give a more verbose output
``GATEWAY`` | as the name suggest the gateway of the samba domain network
``SUBNET`` | the network in xxx.xxx.xxx.xxx/yy syntax

## Volumes

As the docker file defines, and the docker-compose file configures, those are the volumes:

volume      | purpose
----------- | -------
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

## Creating an AD DC server

necessary changes to .env file:

parameter | purpose
--------- | --------
SAMBA_PROVISION_TYPE=SERVER | SERVER for standalone domain controller 

change hostname in docker-compose.yml, setting the hostname for the container and fixing the extra_hosts entry accordingly

## Joining a domain as a dc

Be warned, this are my own notes and may or may not work!

add to .env file:

parameter | purpose
--------- | --------
SAMBA_PROVISION_TYPE=2NDDC | provisioning type: SERVER for standalone domain controller or MEMBER for joining an existing domain


### additional ressources and information
#### /root/tools
is a tool directory in the container image. it contains several helper scripts.

TODO: describe the different script's purposes

#### links
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


# Install Notes

[Arch](InstallArch.md)
[Clearlinux](InstallClrl.md)

## On Clearlinux
### bundles
```
swupd bundle-add acl
```
### Docker compose installation
(shamelessly stolen from original documentation - look there for updates ...)

```
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}

mkdir -p $DOCKER_CONFIG/cli-plugins

curl -SL https://github.com/docker/compose/releases/download/v2.14.0/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose

chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

docker compose version
```


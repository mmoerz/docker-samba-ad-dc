#!/bin/bash
# This is a pre-flight scritp to setup the network 
#

docker network create -d macvlan \
    --subnet=192.168.1.0/24 \
    --gateway=192.168.1.1  \
    --ip-range=192.168.1.0/24 \
    -o parent=br0 samba-network


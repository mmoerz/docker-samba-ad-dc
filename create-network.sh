#!/bin/bash
# This is a pre-flight scritp to setup the network 
#
source ./samba.env

# echo 
docker network create -d macvlan \
    --subnet=$SUBNET \
    --gateway=$GATEWAY  \
    --ip-range=$SUBNET \
    -o parent=br0 samba-network


#!/bin/bash
# This is a pre-flight scritp to setup the network 
#
source functions

INTERFACE=$(ip link list | sed -ne 's/[0-9]\+:\s\(br[0-9]\+\)/\1/p')

if [ "X$INTERFACE" = "X" ]; then
  INTERFACE=$(ip link list | sed -ne 's/[0-9]\+:\s\(enp[0-9]\+s[0-9]\+\).*/\1/p')
fi

if [ "X$INTERFACE" = "X" ]; then
  echo "missing interface for network"
cat <<EOF
USAGE: $0 [interface]
       interface to bind the macvlan network to
EOF
fi

MACVLAN="-d macvlan"
#MACVLAN=""
echo "Network inferace: >$INTERFACE<"
# echo 
podman network create $MACVLAN \
    --subnet=$SUBNET \
    --gateway=$GATEWAY  \
    --ip-range=$SUBNET \
    -o parent=$INTERFACE samba-network

sudo podman network inspect samba-network | \
  jq .[] 
  #> /etc/containers/networks/samba-network.json



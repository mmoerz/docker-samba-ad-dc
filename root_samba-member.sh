#!/bin/bash

DOCKER_ID=$(docker container list | grep "mmoerz/docker-samba-ad-dc" | grep "member" | cut -d' ' -f1)

docker exec -it $DOCKER_ID /bin/bash

#!/bin/bash

DOCKER_ID=$(docker container list | grep samba4-ad-dc | cut -d' ' -f1)

docker exec -it $DOCKER_ID /bin/bash

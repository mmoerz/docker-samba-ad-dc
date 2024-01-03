#!/bin/bash

BASENAME=$(basename $(pwd))
echo $BASENAME
DOCKER_ID=$(docker container list | grep "$BASENAME" | grep -v "member" | cut -d' ' -f1)

docker exec -it $DOCKER_ID /bin/bash

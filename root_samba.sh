#!/bin/bash

BASENAME=$(basename $(pwd))

if [ $(grep "samba:" docker-compose.yml) != "" ]; then
  echo "dc1 found"
  BASENAME=${BASENAME}-samba
fi

echo $BASENAME
DOCKER_ID=$(docker container list | grep "$BASENAME" | grep -v "member" | cut -d' ' -f1)

echo ">$DOCKER_ID<"
docker exec -it "$DOCKER_ID" /bin/bash

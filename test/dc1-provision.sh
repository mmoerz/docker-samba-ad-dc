#!/bin/bash

pushd ../.
SCRIPTDIR=`pwd`
HOST=dc1
DATADIR=/srv/samba
DIR=$DATADIR/$HOST

if [ -d $DIR ] ; then
  echo "config directories for $HOST present"
  if [ "X$1" == "X--rm" ]; then

    if [ "X$2" == "X--force" ] ; then
      echo "deleting config for $HOST"
      sudo rm -rf $DIR
    else
      echo "deleting config for $HOST"
      sudo rm -ri $DIR
    fi
    # recreate directories
    pushd $DATADIR
    pwd
    echo "creating dirs"
    sudo ${SCRIPTDIR}/create-volume.sh addc $HOST 
    popd

  else 
    echo "config directory is preserved"
  fi
fi

pwd
docker-compose up samba
popd

#!/bin/bash

usage() {
cat <<EOF
USAGE: $0 [addc|member] name 
	creates directories and registers them for docker use

  addc    directory structure for an AD Server
  member  directory for a simple file server
EOF
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi 

createDirsAndRegisterWithDocker() {
	DIRBASE=$1
	DIRS=$2
	for dcd in $DIRS; do
    echo "creating dir $DIRBASE/$dcd"
		mkdir -p $DIRBASE/$dcd
    #echo "binding $DIRBASE/$dcd to samba_${DIRBASE}_${dcd/\///}"
    echo -n "binding $DIRBASE/$dcd to:"
		docker volume create --driver local \
		--opt type=none \
		--opt device=`pwd`/$DIRBASE/$dcd \
		--opt o=bind samba_${DIRBASE}_${dcd/\//}
    echo .
	done
}

if [ "X$1" == "--help" ]; then
  usage
elif [ "X$1" == "Xaddc" ]; then
  # dc1 directories
  BASE="${2:-dc1}"
  echo hostname: $BASE 
  createDirsAndRegisterWithDocker "$2" "etc var/lib var/log"
elif [ "X$1" == "Xmember" ]; then
  # fileserver directories
  createDirsAndRegisterWithDocker "$2" "etc var/lib var/log supervisord shares"
elif [ "X$1" == "Xcups" ]; then
  # fileserver directories
  createDirsAndRegisterWithDocker "$2" "etc var/lib var/log supervisord shares"
else
  echo "Unknown Option: >$1<"
  echo "Use --help to see options"
  exit 1
fi
exit 0


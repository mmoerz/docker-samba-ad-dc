#!/bin/bash

if [ $# -ne 1 ]; then
cat <<EOF
USAGE: $0 make
	creates directories and registers them for docker use
EOF
exit 1
fi 

createDirsAndRegisterWithDocker() {
	DIRBASE=$1
	DIRS=$2
	for dcd in $DIRS; do
		mkdir -p $DIRBASE/$dcd
		docker volume create --driver local \
		--opt type=none \
		--opt device=`pwd`/$DIRBASE/$dcd \
		--opt o=bind samba_${DIRBASE}_${dcd/\//}
	done
}

# dc1 directories
createDirsAndRegisterWithDocker "dc1" "etc var/lib var/log"
# fileserver directories
createDirsAndRegisterWithDocker "fs1" "etc var/lib var/log supervisord shares"

exit 0


#!/bin/bash
FILES="/etc/samba/facl-test.txt /var/lib/samba/facl-test.txt /root/facl-test.txt"

for testfile in $FILES; do
	echo "*****************"
	echo $testfile
	touch $testfile
	setfacl -m u:www-data:rw $testfile
	getfacl $testfile
	rm $testfile
done

#!/bin/bash

kinit administrator
RC=$?
if [ $RC -ne 0 ] ; then
   echo "kinit failed"
	exit $RC
fi

klist

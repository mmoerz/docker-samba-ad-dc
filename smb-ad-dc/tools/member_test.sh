#!/bin/bash
wbinfo --domain-users
wbinfo --domain-groups

echo join test
net ads testjoin

echo test krbtab - should list a long list
klist -k
echo test krbtab if not see
echo https://wiki.samba.org/index.php/Samba_Member_Server_Troubleshooting

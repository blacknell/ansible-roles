#!/bin/bash

# simple script which uses a timeout for a sudo command to check if the password was prompted
# if so, then don't attempt privileged fail2ban command

`timeout -k 0.2s 0.2s sudo /bin/chmod --help >&/dev/null 2>&1` >/dev/null 2>&1
if [ $? -eq 0 ] ; then sudo fail2ban-client status sshd ; fi

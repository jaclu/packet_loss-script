#!/bin/bash

#==========================================
#
# Copyright: Jacob.Lundqvist@gmail.com
# License: GPL
# Version: 1.0.1  2019-11-28
#
#==========================================


#
# number of checks
#
check_count=360

#
# number of pings in each check
# ie how often you will get updated
#
ping_count=30

#
# what to ping

host=8.8.8.8


#==========================================
#
# End of user configuration part
#
#==========================================



# Kill this script on Ctrl-C, dont let ping swallow it
trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT


#
# This will run $ping_count pings to $host and then report packet loss
# Then loop for $check_count iterations
#
while [ $check_count -gt 0 ] ; do
      ping -c $ping_count $host | grep loss | awk '{ print $7 "\t" $8 " " $9 }'
      check_count=$[$check_count-1]
done

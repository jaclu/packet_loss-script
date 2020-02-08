#!/bin/bash

#==========================================
#
# Copyright: Jacob.Lundqvist@gmail.com
# License: GPL
# Version: 1.2.0  2020-02-08
#
#==========================================

#
# number of pings in each check
# ie how often you will get updated
#
check_count=300

#
# what to ping
#
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
#
while true; do
    read packet_loss percent_loss < <(
        ping -c $ping_count $host | grep loss |
            awk '{print $1-$4, $7}'
    )    
    printf "%s (%s) packet loss per %ss\t" $packet_loss $percent_loss $ping_count
    date
done

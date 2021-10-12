#!/bin/sh
#
# Copyright (c) 2020,2021: Jacob.Lundqvist@gmail.com 2021-10-02
# License: MIT
#
# Part of https://github.com/jaclu/helpfull_scripts
#
#  Version: 1.4.1 2021-10-02
#      Switched shell from bash to /bin/sh
#      now prints total ping count and losses upon Ctrl-C termination
#      Fixed emacs ruined indents again, need to check my emacs config...
#  1.4.0  2020-08-11
#      Added support for multi route testing
#
#  Displays packet loss over time, see below for more usage hints
#

#
#  number of pings in each check
#  ie how often you will get updated
#  can be overridden by param1
#
ping_count=300

#
# what to ping
#
host=8.8.4.4


#
#  In the default case where you just want to see average packet loss
#  over time, nothing further needs to be done but starting this script.
#
#  I tend to use 8.8.8.8 (google DNS as my general ping check
#  Here I use 8.8.4.4 (Google secondary DNS).
#  This way I can route 8.8.4.4 through a troubled link whilst
#  Using a prefered link as my default route. In order to get better
#  net service for most of my network needs and still be able to track
#  this specific node through the troubled connection.
#
#  If you have two access points and want to keep track of "the other",
#  I woulld< suggest the following:
#
#  In MacOs:
#
#  1. In most cases you need to diable vpn, since they tend to
#     disregard specific routes, and insist on routing everything
#     except the local network through the vpn.
#  2. System Preferences - Network - cogwheel at the bottom of the
#     left frame - Set Service Order...
#     This list essentially decides wich connection will be given the
#     role of default route, if multiple connections are available.
#     Make sure the service you prefer as the default route is at
#     the top of the list, or at the very least above the troubled link
#  3. Hit OK to close the popup
#  4. Hit Apply to save the settings to the network routing layer.
#  5. In a terminal route 8.8.4.4 through the troubled link.
#     For me it tends to be my Ziggo router, in the example bleow
#     having the IP# 192.168.178.1
#
#    sudo route add -gateway 192.168.178.1 -host 8.8.4.4
#
#  6. From now all traffic to 8.8.4.4 follows this route,
#     and can be used to monitor the packet loss of that link
#     Without forcing you to use it as a deault route
#  7. You can still moniotor packetloss on yor primary
#     route by doing something like:  ping 8.8.8.8
#  8. If you changed the order in "Set Service order" above,
#     remmebr to rearange the order back to your normally prefered
#     state once you are done Testing using a multi path setup!



#==========================================
#
#  End of user configuration part
#
#==========================================



#
#  Override ping_count with param 1
#
if [ $# = 1 ] ; then
    ping_count=$1
    # case "${1#[+-]}" in
    case "$ping_count" in
        (*[!0123456789]*)
            echo "ERROR param 1 not int value!"
            exit 1
            ;;
    esac
    if [ "$ping_count" -lt 2 ]; then
        echo "***  $ping_count is not a meaningfull value, changed to 2  ***"
        ping_count=2
    fi
elif [ $# -gt 1 ] ; then
    echo "*** Only supports one param - to overide default amount" \
        "of pings per test."
    exit 1
fi


#  Kill this script on Ctrl-C, dont let ping swallow it
trap '
    echo
    echo "performed $(( iterations * ping_count )) pings, total packet loss: $ack_loss"
    trap - INT # restore default INT handler
    kill -s INT "$$"
' INT

echo "This will report packet loss to $host every $ping_count seconds" \
     "with a timestamp"
if [ $# -ne 1 ] ; then
    echo "optional param 1 overrides default ($ping_count) interval"
fi


#
#  This will run $ping_count pings to $host and then report packet loss
#
iterations=0
while true; do
    iterations=$(( iterations + 1 ))
    output="$( ping -c $ping_count -t $ping_count $host 2> /dev/null |
               grep loss)"
    this_time_packet_loss=$(echo "$output" | awk '{print $1-$4}')
    this_time_percent_loss=$(echo "$output" | awk '{print $7}')
    ack_loss=$((ack_loss + this_time_packet_loss))
    avg_loss=$(
        awk -v ack_loss=$ack_loss -v count=$iterations \
            -v ping_count=$ping_count \
            'BEGIN { print 100 * (ack_loss/(count * ping_count)) }' )

    printf "%6s avg:%3.0f%%   %ss - " "$this_time_percent_loss" "$avg_loss" \
           "$ping_count"
    date
done

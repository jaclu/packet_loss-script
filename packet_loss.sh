#!/bin/sh
__version="1.5.3 2021-11-14"
#
# Copyright (c) 2020,2021: Jacob.Lundqvist@gmail.com
# License: MIT
#
# Part of https://github.com/jaclu/helpfull_scripts
#
#  Version: $__version
#       Added check if ping is the busybox version,
#       without timeout param and deals with it.
#       Removed timeout calculations, didn't make sense.
#   1.5.2 2021-11-14
#       Ensure host is responding when starting.
#       Shortened output lines, so they can run in a 28 col terminal.
#       Corrected printout after Ctrl-C to point out what is included.
#       Changed min allowed count into 1.
#   1.5.1 2021-11-11
#       Uses timeout of ping_count * 1.5 rounded for ping
#       Does requested amount of pings again.
#   1.5.0 2021-11-10
#       Added 2nd param host.
#       increased min ping_count since low numbers tende
#       to give false negatives.
#       Does one more ping than ping count, since first ping is
#       sent at time 0, to line up timestamps with ping count
#       I.E 5 will display status every 5s and so on.
#       reduced output to fit a smaller width
#   1.4.1 2021-10-02
#       Switched shell from bash to /bin/sh
#       now prints total ping count and losses upon Ctrl-C termination
#       Fixed emacs ruined indents again, need to check my emacs config...
#   1.4.0  2020-08-11
#       Added support for multi route testing
#
#  Displays packet loss over time, see below for more usage hints
#

#
#  number of pings in each check
#  ie how often you will get updated
#  can be overridden by param1
#
ping_count=60

#
# what to ping (can be overriden by param2)
#
host=8.8.4.4


#==========================================
#
#  End of user configuration part
#
#==========================================


echo "$(basename $0) version: $__version"


#
#  Override ping_count with param 1
#
if [ $# -gt 2 ] ; then
    echo "ERROR: Only params supported - pingcount and host."
    exit 1
fi

if [ -n  "$1" ] ; then
    ping_count="$1"
    case "$ping_count" in

        (*[!0123456789]*)
            echo "ERROR param 1 not a valid integer value!"
            exit 1
            ;;

    esac
    if [ "$ping_count" -lt 1 ]; then
        echo "WARNING: $ping_count is not a meaningfull value, changed to 1  ***"
        ping_count=1
    fi
fi


#
#   Override default host with param 2
#
if [ -n "$2" ]; then
    host="$2"
fi


#
#  Check if this ping supports timeout.
#
if [ -z "$(ls -l $(which ping)|grep busybox)" ]; then
    time_out_supported=1
    ping_cmd="ping -t 1"
else
    #
    # busybox ping does not support ping timeout...
    #
    time_out_supported=0
    ping_cmd="ping"
    echo
    echo "WARNING: This ping does not support a timeout param!"
    echo
    echo "  This means that each time when at first the host is not responding,"
    echo "  there will be an initial 10 second timeout."
    echo "  Concecutive failed pings will only take one second."
    echo "  If the host reglarly fails to respond the accumulated first 10 seconds"
    echo "  will add-up and skew the printouts"
    echo
fi


#
#  Check if host is initially responding.
#
$ping_cmd -c 1 "$host" > /dev/null
if [ "$?" -ne 0 ]; then
    echo
    echo "WARNING: host: $host is not responding!"
    echo
fi


echo "This will ping once per second and report packet loss with"
printf "$host every $ping_count packets"

if [ "$time_out_supported" -eq 1 ]; then
    ping_cmd="ping -t $ping_count"
    echo ", timing out after $ping_count seconds."
else
    echo "."
fi
echo

#
#  Kill this script on Ctrl-C, dont let ping swallow it
#
trap '
    echo
    echo "Stats up to last printout:"
    echo "  performed $(( iterations * ping_count )) pings, " \
         "total packet loss: $ack_loss"
    trap - INT # restore default INT handler
    kill -s INT "$$"
' INT


iterations=0
while true; do
    #
    #  This will run $ping_count pings to $host and then report packet loss.
    #  This will be repated until Ctrl-C
    #
    output="$( $ping_cmd -c $ping_count $host 2> /dev/null |
               grep loss)"
    iterations=$(( iterations + 1 ))
    this_time_packet_loss=$(echo "$output" | awk '{print $1-$4}')
    this_time_percent_loss=$(echo "$output" | awk '{print $7}')
    ack_loss=$((ack_loss + this_time_packet_loss))
    avg_loss=$(
        awk -v ack_loss=$ack_loss -v count=$iterations \
            -v ping_count=$ping_count \
            'BEGIN { print 100 * (ack_loss/(count * ping_count)) }' )

    printf "%6s avg:%3.0f%% %s " "$this_time_percent_loss" "$avg_loss" \
           "$ping_count"
    date +%H:%M:%S
done

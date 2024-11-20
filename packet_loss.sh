#!/bin/bash
__version="1.6.0 2021-12-18"
#
# Copyright (c) 2020,2021: Jacob.Lundqvist@gmail.com
# License: MIT
#
# Part of https://github.com/jaclu/helpfull_scripts
#
#  Version: $__version
#       Added handling of different types of ping with various
#       locations of percentage loss in output.
#   1.5.3 2021-11-14
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
hosts="1.1.1.1" # 1.0.0.1

# Interfaces to test connectivity
# Add multiple interfaces separated by spaces (e.g., "eth0 eth0.52 eth0.55")
interfaces="eth0" # eth0.52 eth0.55 eth0.56


#==========================================
#
#  End of user configuration part
#
#==========================================


echo "$(basename "$0") version: $__version"


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
#
#  2021-12-18 How can such a common and basic command as ping have different
#  paramas on MacOS & linux?? I could have done this checking uname and let
#  OS decide, but if there are other systems with other pings,
#  lets just do it the hard way.
#

# Argh, even the position for % packet loss is not constant...
packet_loss_param_no="7"

# triggering an eror printing valid params...
timeout_help="$(ping -h 2> /dev/stdout| grep timeout)"

if [ "${timeout_help#*-t}" != "$timeout_help" ]; then
    timeout_flag="t"
elif [ "${timeout_help#*-W}" != "$timeout_help" ]; then
    timeout_flag="W"
    packet_loss_param_no="6"
else
    timeout_flag=""
fi

if [ -n "$timeout_flag" ]; then
    ping_tst_cmd="ping -$timeout_flag 1"
    ping_cmd="ping -$timeout_flag $ping_count"
else
    ping_tst_cmd="ping"
    ping_cmd="ping"
    echo
    echo "WARNING: This ping does not support timeouts, so when a host is not responding"
    echo "         an extra 10 seconds will be spent timing out"
    echo
fi
# to avoid redundant typing common params are given once here
ping_cmd="$ping_cmd -c $ping_count $host"


#
#  Check if host is initially responding.
#
for current_host in $hosts; do
    if ! $ping_tst_cmd -c 1 "$current_host" > /dev/null; then
        echo
        echo "WARNING: Host $current_host is not responding!"
        echo
    fi
done


#
#  Explaining task at hand
#
echo "This will ping once per second and report packet loss with"
printf '%s every %s packets' "$host" "$ping_count"

if [ -n "$timeout_flag" ]; then
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

#==========================================
#
#  Main loop for multiple hosts
#
#==========================================

# Initialize packet loss counters and jitter for each interface
declare -A ack_loss
declare -A total_dropped_packets
declare -A previous_output
declare -A jitter
declare -A avg_jitter
declare -A prev_rtt

for interface in $interfaces; do
    ack_loss[$interface]=0
    total_dropped_packets[$interface]=0
    previous_output[$interface]=""
    jitter[$interface]=0
    avg_jitter[$interface]=0
    prev_rtt[$interface]=""
done

# Infinite loop to alternate between hosts
while true; do
    # Loop through all provided hosts, one cycle per host
    for current_host in $hosts; do
        output=""
        pids=()

        for interface in $interfaces; do
            # Set the ping command for the current interface and host
            ping_cmd="ping -I $interface -c $ping_count $current_host"

            # Run the ping command in the background and store the process ID
            $ping_cmd > /tmp/ping_${interface}_${current_host//./_}.log &
            pids+=($!)
        done

        # Wait for all pings to complete
        for pid in "${pids[@]}"; do
            wait $pid
        done

        # Process the output for each interface
        for interface in $interfaces; do
            log_file="/tmp/ping_${interface}_${current_host//./_}.log"
            ping_output=$(grep loss "$log_file")
            rtt_values=$(grep "time=" "$log_file" | awk -F'time=' '{print $2}' | awk '{print $1}')

            # Skip processing if log is empty or invalid
            if [ -z "$ping_output" ]; then
                echo "Warning: No valid output for $interface on $current_host."
                continue
            fi

            # Extract packet statistics
            this_time_packet_loss=$(echo "$ping_output" | awk '{print $1-$4}')
            this_time_percent_loss=$(echo "$ping_output" | awk -v a="$packet_loss_param_no" '{print $a}')
            total_dropped_packets[$interface]=$((total_dropped_packets[$interface] + this_time_packet_loss))
            ack_loss[$interface]=$((ack_loss[$interface] + this_time_packet_loss))

            # Avoid division by zero for avg_loss calculation
            if [ $ping_count -gt 0 ]; then
                avg_loss=$(awk -v ack="${ack_loss[$interface]}" -v total=$((ping_count)) 'BEGIN { print 100 * (ack / total) }')
            else
                avg_loss=0
            fi

            # Calculate jitter for this run
            total_jitter=0
            jitter_count=0

            for rtt in $rtt_values; do
                if [ -n "${prev_rtt[$interface]}" ]; then
                    jitter_value=$(awk -v curr="$rtt" -v prev="${prev_rtt[$interface]}" 'BEGIN { print (curr > prev ? curr - prev : prev - curr) }')
                    total_jitter=$(awk -v t="$total_jitter" -v j="$jitter_value" 'BEGIN { print t + j }')
                    jitter_count=$((jitter_count + 1))
                fi
                prev_rtt[$interface]="$rtt" # Update the last RTT for this interface
            done

            if [ $jitter_count -gt 0 ]; then
                jitter[$interface]=$(awk -v total="$total_jitter" -v count="$jitter_count" 'BEGIN { print total / count }')
            else
                jitter[$interface]=0
            fi

            # Calculate cumulative average jitter
            avg_jitter[$interface]=$(awk -v curr_avg="${avg_jitter[$interface]}" -v curr_jitter="${jitter[$interface]}" -v count=1 'BEGIN { print (curr_avg + curr_jitter) / 2 }')

            # Prepare current output for this interface
            current_output=$(printf "%-10s %-10s %4s avg:%3.0f%% dropped:%d jitter:%0.1fms avg_jitter:%0.1fms %s\n" \
                             "$interface" "$current_host" "$this_time_percent_loss" "$avg_loss" "$this_time_packet_loss" \
                             "${jitter[$interface]}" "${avg_jitter[$interface]}" "$(date +%H:%M:%S)")

            # Only print if the output has changed for this interface
            if [ "$current_output" != "${previous_output[$interface]}" ]; then
                output+="${current_output}\n"
                previous_output[$interface]=$current_output
            fi
        done

        # Print consolidated output if there's any change
        if [ -n "$output" ]; then
            echo -e "$output"
            echo   # Add an extra blank line between updates for readability
        fi
    done
done



#!/bin/bash

# PID 1 STATE 3 PPID 4 tty 7? uTIME 14 sTIME 15 PRI 18 NICE 19

get_ppid(){
    echo $(awk '{print $4}' /proc/${PID}/stat)
}

get_tty(){
    echo $(awk '{print $7}' /proc/${PID}/stat)
}

# https://unix.stackexchange.com/questions/7870/how-to-check-how-long-a-process-has-been-running
get_time(){
    #https://stackoverflow.com/questions/3875801/convert-jiffies-to-seconds
    SYS_CLK_TCK=$(getconf CLK_TCK)
    SUMTIME=$(awk '{print $14+$15}' "/proc/${PID}/stat")
    PSTIME="$(($SUMTIME / $SYS_CLK_TCK / 60)):$(($SUMTIME / $SYS_CLK_TCK % 60))"
    echo "$PSTIME"
 }

get_state(){
    echo $(awk '{print $3}' /proc/${PID}/stat)
}

get_cmd(){
    CMDLINE="$(cat /proc/${PID}/cmdline | tr "\0" " ")"
    if [ -z "$CMDLINE" ] ; then
    CMDLINE=$(awk '{print $2}' /proc/${PID}/stat | tr "()" "[]");
    fi
    echo $CMDLINE
}

printf "%5s %5s %-10s %-6s %4s %-s\n" PID PPID TTY STAT TIME COMMAND
PIDLIST=$(ls /proc/ | grep -P '^\d+$' | sort -n)
for PID in $PIDLIST; do
    if [ -e /proc/$PID ]; then 
       
        printf "%5s %5s %-10s %-6s %4s %s\n" $PID $(get_ppid) $(get_tty) $(get_state) $(get_time) "$(get_cmd)" ;
    fi ;
done

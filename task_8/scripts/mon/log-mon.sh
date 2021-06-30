#!/bin/bash

ALERTMSG=$1
LOG=$2
DATE=$(date)
#LINENUM=/tmp/linenum
LINENUM=$3

if [ ! -f $LINENUM ]; then
    echo '1' > $LINENUM
fi


if tail -n +$(cat $LINENUM) $LOG | grep $ALERTMSG &> /dev/null
then
   #logger "$DATE: Alert occured!"
   echo $DATE: Alert occured! | systemd-cat -p info -t log-mon
else
   exit 0
fi

echo $(wc -l $LOG | cut -d " " -f 1) > $LINENUM

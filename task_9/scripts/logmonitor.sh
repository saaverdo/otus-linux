#!/bin/bash

LOGFILE=$1
LOGFILE=${LOGFILE:-/vagrant/access.log}
LASTRUN=/tmp/lastrun
LOCKFILE=/tmp/logmon.lock
#REPORTFILE=/vagrant/report.txt
IP=$2
IP=${IP:-10}
ADDR=$3
ADDR=${ADDR:-8}
MAILTO="root"
TODAY=$(date +%F_%T)

write_last_params(){
    echo $(tail -n 1 $LOGFILE | awk '{gsub(/\[/,""); print $4}') $(wc -l $LOGFILE | cut -d " " -f 1) $TODAY > $LASTRUN
}

start_check(){
    if [ ! -f $LOGFILE ]; then
    echo "No file to parse"
    exit 1 ;
    fi
    # if not exist $LASTRUN file = first start. 
    if [ ! -f $LASTRUN ]; then
    LASTTIME=''
    LASTLINE=0
    LASTRUNTIME='' ; 
    else 
    read LASTTIME LASTLINE LASTRUNTIME < $LASTRUN ;
      # check if log file not been truncated
      if ! (grep $LASTTIME $LOGFILE) > /dev/null 2>&1 ; then 
      LASTTIME=''
      LASTLINE=0 ; 
      fi
    fi
}

cns(){
    # Cut-aNd-Sort 
    sort | uniq -c | sort -rn | head -n $1
}

send_mail(){
    mail -s "access.log report from ${TODAY}" $MAILTO
}


generate_report(){
    # header
    echo "----------------------------------------------------"
    echo "=     Report period: ${LASTRUNTIME} - ${TODAY}     ="
    echo "----------------------------------------------------"
    echo " "
    # ip
    echo "TOP ${IP} IP адресов с наибольшим количеством запросов: "
    echo "----------------------------------------------------"
    tail -n +${LASTLINE} $LOGFILE | cut -f 1 -d ' ' | cns $IP | awk '{print $1, "запросов с IP-адреса", $2}'
    echo " "
    # requested pages
    echo "TOP ${ADDR} запрашиваемых адресов на сервере: "
    echo "----------------------------------------------------"
    tail -n +${LASTLINE} $LOGFILE | awk '/\".*HTTP.*\"/ {print $7}' | cns $ADDR | awk '{print $1, "раз запрашивалась страница", $2}'
    echo " "
    # all errors - no requirenemt to count them!
    echo "Все ошибки c момента последнего запуска: "
    echo "----------------------------------------------------"
    tail -n +${LASTLINE} $LOGFILE | grep -oP '^\d+.+\[.+\] ".*" (\d+)' | rev | cut -f 1 -d ' ' | rev | cns -0 | awk '/[45]..$/ {print $2}'| paste -s -d ' ' 
    echo " "
    # all codes
    echo "Cписок всех кодов возврата и их количество: "
    echo "----------------------------------------------------"
    tail -n +${LASTLINE} $LOGFILE | grep -oP '^\d+.+\[.+\] ".*" (\d+)' | rev | cut -f 1 -d ' ' | rev | cns -0 | awk '{print "код", $2, "был возвращён", $1, "раз"}'
    echo " "
    echo "===================================================="

}

clear_on_exit() {
  # удаление временных и lock-файлов в случае завершения работы
  rm -f $LOCKFILE
  #rm -f $REPORTFILE
  exit $?
}

if ( set -o noclobber
  echo "$$" > "$LOCKFILE") 2>/dev/null; 
then
  trap 'clear_on_exit' INT TERM EXIT
  start_check
  generate_report | send_mail
  write_last_params
  clear_on_exit
  trap - INT TERM EXIT
else
  echo "Failed to acquire lockfile: ${LOCKFILE}."
  echo "Held by $(cat ${LOCKFILE})"
  exit 1
fi

## ДЗ - 9   Bash

Пишем скрипт

##### написать скрипт для крона который раз в час присылает на заданную почту

> X IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта  
> Y запрашиваемых адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта 
> все ошибки c момента последнего запуска  
> список всех кодов возврата с указанием их кол-ва с момента последнего запуска   в письме должно быть прописан обрабатываемый временной диапазон и должна быть реализована защита от мультизапуска  

#### Prepare

Чтобы лог писался "порциями" воспользуюсь скриптом из предыдущего задания:
DISCLAIMER 
!!! аффтар не настоящий змеевод и ответственности за кровь из глаз не несёт !!!
Оформим мы этот скрипт как православный `systemd unit`

<details>
<summary>файл параметров unit'а `log-gen`</summary>
# Command-line options for log-gen service
LINES=10
SLOG=/vagrant/access-4560-644067.log
DLOG=/vagrant/access.log
</details>

<details>
<summary>файл `log-gen.service`</summary>
[Unit]
Description=log generator service
After=systemd-journald.service

[Service]
Type=simple
Restart=always
RestartSec=5
EnvironmentFile=/etc/sysconfig/log-gen
ExecStart=/usr/bin/python3 /usr/local/bin/log_gen.py $LINES $SLOG $DLOG
ExecReload=rm $LOG; /usr/bin/python3 /usr/local/bin/log_gen.py

[Install]
WantedBy=multi-user.target

</details>

<details>
<summary>файл `log-gen.timer`</summary>

[Unit]
Description=Run log generator script every 15 seconds

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=log-gen.service

[Install]
WantedBy=multi-user.target

</details>

<details>
<summary>файл `log_gen.py`</summary>

#!/usr/bin/env python3

from sys import argv
import subprocess
# ловим агрументы
try:
    LINE_SHIFT = int(argv[1])
    logfile = argv[2]
    outfile = argv[3]
except IndexError:    
    LINE_SHIFT = 5 # default value
    logfile = '/vagrant/syslog.log' # default value
    outfile = '/vagrant/stplog.log' # default value

# logfile - источник лога
# outfile - файл, который будет мониториться сервисом,  в него будет писаться лог порциями

# определим, с какого места читать источник лога
start = subprocess.run(['wc', '-c', outfile],stdout=subprocess.PIPE,
                                            stderr=subprocess.DEVNULL,
                                             encoding='utf-8')
start = 0 if start.returncode else start.stdout.split()[0]

try:
    with open(logfile) as f_i:
        with open(outfile, 'a') as f_o:
            f_i.seek(int(start))
            for i in range(LINE_SHIFT):
                f_o.write(f_i.readline())
except FileNotFoundError as msg:
    print(f"Error {msg}")

</details>

####  Приступаем

Для запуска нашего основного скрипта каждый час добавим в крон соответствующую запись:

  echo "0 * * * * root /vagrant/scripts/logmonitor.sh" >> /etc/crontab

для тестовых целей можно сделать запуск каждые 2 минуты:

  echo "*/2 * * * * root /vagrant/scripts/logmonitor.sh" >> /etc/crontab

Скрипт ожидает 3 параметра: 
 имя лог-файла, сколько IP и сколько запрошенных страниц отбирать в отчёт
По-умолчанию ожидается файл /vagrant/access.log, 10 IP-адресов и 8 страниц

<details>
<summary>заголовок скрипта</summary>

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

</details>

Основные действия в скрипте вынесены в отдельные функции для простоты 
Так, в функции `start_check` выполняется проверка существования лог-файла:

> if [ ! -f $LOGFILE ]; then  
>     echo "No file to parse"  
>     exit 1 ;  
>     fi  

Затем, если не обнаружен временный файл `/tmp/lastrun` c параметрами на момент последнего запуска скрипта,
LASTTIME - время из последней строчки лог-файла
LASTLINE - номер поcледней строки лог-файла
LASTRUNTIME - время последнего запуска скрипта
им присваиваются пустые значения. 
Один нюанс - т.к. мы используем `tail -n` он не поймёт пустого значения и для того чтобы он вывел файл полностью,
присваиваем значение `+0`
Также делаем проверку, не был ли обнулён файл лога после прошлого запуска.
Если в логе нет строки со временем из последней строчки во время предыдущего запуска, файл обнулялся и читать его мы будем полностью.

> if ! (grep $LASTTIME $LOGFILE) > /dev/null 2>&1 ; then  
> LASTTIME='' 
> LASTLINE=+0 ;  
> fi 

<details>
<summary>функция start_check()</summary>

start_check(){
    if [ ! -f $LOGFILE ]; then
    echo "No file to parse"
    exit 1 ;
    fi
    # if not exist $LASTRUN file = first start. 
    if [ ! -f $LASTRUN ]; then
    LASTTIME=''
    LASTLINE=+0
    LASTRUNTIME='' ; 
    else 
    read LASTTIME LASTLINE LASTRUNTIME < $LASTRUN ;
      # check if log file not been truncated
      if ! (grep $LASTTIME $LOGFILE) > /dev/null 2>&1 ; then 
      LASTTIME=''
      LASTLINE=+0 ; 
      fi
    fi
}

</details>

Для удобства часто повторяющийся кусок пайплайна вынесен в отдельную функцию `cns`

> cns(){  
>     # Cut-aNd-Sort   
>     sort | uniq -c | sort -rn | head -n $1  
> }  

Отбор данных вынесен в функцию `generate_report()`, что позволяет в итоге запустить основную часть простой командой 

  generate_report | send_mail

Читать лог будем командой `tail -n` - нам нужно получать информацию, которая добавилась с последнего запуска, поэтому `cat` не подходит.
Для поиска IP адресов подошёл простой `cut` т.к. это первое поле каждой строки

  tail -n $LASTLINE $LOGFILE | `cut -f 1 -d ' '` | sort | uniq -c | sort -rn | head -n $IP 

Запрашиваемые адреса - вопрос посложнее, т.к. есть ряд явно кривых запросов. поэтому будем ловить те, которые имеют вид `"GET /robots.txt HTTP/1.1"` и отсекать по регулярке с помощью `awk`

  tail -n $LASTLINE $LOGFILE | `awk '/\".*HTTP.*\"/ {print $7}' `

Для списка всех ошибок/кодов ответа возьмём `grep`, регуляркой найдём код (он идёт после первой пары кавычек) и перевернув `rev` полученную строку сделаем как с IP адресами - обрежем по первому полю, перевернём обратно - и скормим стандартному `sort | uniq ...` 

  cat $LOGFILE | `grep -oP '^\d+.+\[.+\] ".*" (\d+)'` | rev | cut -f 1 -d ' ' | rev | cns -0

С ошибками уже проще - берём предыдущую команду для всех кодов ответа и `awk` отберём те, которые начинаются с 4xx или 5xx.
И т.к их количество в задании не требовалось, выведем их одной строкой с помощью `paste`

  | awk '/[45]..$/ {print $2}'| paste -s -d ' ' 


<details>
<summary>функция generate_report()</summary>

generate_report(){
    # header
    echo "----------------------------------------------------"
    echo "=     Report period: ${LASTRUNTIME} - ${TODAY}     ="
    echo "----------------------------------------------------"
    echo " "
    # ip
    echo "TOP ${IP} IP адресов с наибольшим количеством запросов: "
    echo "----------------------------------------------------"
    tail -n $LASTLINE $LOGFILE | cut -f 1 -d ' ' | cns $IP | awk '{print $1, "запросов с IP-адреса", $2}'
    echo " "
    # requested pages
    echo "TOP ${ADDR} запрашиваемых адресов на сервере: "
    echo "----------------------------------------------------"
    cat $LOGFILE | awk '/\".*HTTP.*\"/ {print $7}' | cns $ADDR | awk '{print $1, "раз запрашивалась страница", $2}'
    echo " "
    # all errors - no requirenemt to count them!
    echo "Все ошибки c момента последнего запуска: "
    echo "----------------------------------------------------"
    cat $LOGFILE | grep -oP '^\d+.+\[.+\] ".*" (\d+)' | rev | cut -f 1 -d ' ' | rev | cns -0 | awk '/[45]..$/ {print $2}'| paste -s -d ' ' 
    echo " "
    # all codes
    echo "Cписок всех кодов возврата и их количество: "
    echo "----------------------------------------------------"
    cat $LOGFILE | grep -oP '^\d+.+\[.+\] ".*" (\d+)' | rev | cut -f 1 -d ' ' | rev | cns -0 | awk '{print "код", $2, "был возвращён", $1, "раз"}'
    echo " "
    echo "===================================================="

}

</details>

<details>
<summary>функция send_mail()</summary>

send_mail(){
    mail -s "access.log report from ${TODAY}" $MAILTO
}

</details>

Пример проверки почты:

>  [root@task9-bash vagrant]# mail  
>  Heirloom Mail version 12.5 7/5/10.  Type ? for help.  
>  "/var/spool/mail/root": 10 messages 5 new  
>      1 root                  Sun Jul  4 12:48  52/2483  "access.log report from 2021-07-04_12:48:01"  
>      2 root                  Sun Jul  4 12:50  68/3315  "access.log report from 2021-07-04_12:50:01"  
>      3 root                  Sun Jul  4 12:52  69/3341  "access.log report from 2021-07-04_12:52:01"  
>      4 root                  Sun Jul  4 12:54  70/3419  "access.log report from 2021-07-04_12:54:01"  
>  >N  5 root                  Sun Jul  4 12:56  66/3249  "access.log report from 2021-07-04_12:56:01"  
>   N  6 root                  Sun Jul  4 12:58  67/3324  "access.log report from 2021-07-04_12:58:01"  
>   N  7 root                  Sun Jul  4 13:00  68/3349  "access.log report from 2021-07-04_13:00:01"  
>   N  8 root                  Sun Jul  4 13:02  69/3408  "access.log report from 2021-07-04_13:02:01"  
>   N  9 root                  Sun Jul  4 13:04  69/3409  "access.log report from 2021-07-04_13:04:01"  
>  &   


<details>
<summary>и само письмо</summary>

Message 10:
From root@task9-bash.localdomain  Sun Jul  4 13:06:01 2021
Return-Path: <root@task9-bash.localdomain>
X-Original-To: root
Delivered-To: root@task9-bash.localdomain
Date: Sun, 04 Jul 2021 13:06:01 +0000
To: root@task9-bash.localdomain
Subject: access.log report from 2021-07-04_13:06:01
User-Agent: Heirloom mailx 12.5 7/5/10
Content-Type: text/plain; charset=utf-8
From: root@task9-bash.localdomain (root)
Status: R

----------------------------------------------------
=     Report period: 2021-07-04_13:04:01 - 2021-07-04_13:06:01     =
----------------------------------------------------
 
TOP 15 IP адресов с наибольшим количеством запросов: 
----------------------------------------------------
45 запросов с IP-адреса 93.158.167.130
39 запросов с IP-адреса 109.236.252.130
37 запросов с IP-адреса 212.57.117.19
33 запросов с IP-адреса 188.43.241.106
31 запросов с IP-адреса 87.250.233.68
24 запросов с IP-адреса 62.75.198.172
22 запросов с IP-адреса 148.251.223.21
20 запросов с IP-адреса 185.6.8.9
17 запросов с IP-адреса 217.118.66.161
16 запросов с IP-адреса 95.165.18.146
12 запросов с IP-адреса 95.108.181.93
12 запросов с IP-адреса 62.210.252.196
12 запросов с IP-адреса 185.142.236.35
12 запросов с IP-адреса 162.243.13.195
8 запросов с IP-адреса 163.179.32.118
 
TOP 10 запрашиваемых адресов на сервере: 
----------------------------------------------------
157 раз запрашивалась страница /
120 раз запрашивалась страница /wp-login.php
57 раз запрашивалась страница /xmlrpc.php
26 раз запрашивалась страница /robots.txt
12 раз запрашивалась страница /favicon.ico
9 раз запрашивалась страница /wp-includes/js/wp-embed.min.js?ver=5.0.4
7 раз запрашивалась страница /wp-admin/admin-post.php?page=301bulkoptions
7 раз запрашивалась страница /1
6 раз запрашивалась страница /wp-content/uploads/2016/10/robo5.jpg
6 раз запрашивалась страница /wp-content/uploads/2016/10/robo4.jpg
 
Все ошибки c момента последнего запуска: 
----------------------------------------------------
404 400 500 499 405 403

Cписок всех кодов возврата и их количество: 
----------------------------------------------------
код 200 был возвращён 498 раз
код 301 был возвращён 95 раз
код 404 был возвращён 51 раз
код 400 был возвращён 18 раз
код 500 был возвращён 3 раз
код 499 был возвращён 2 раз
код 405 был возвращён 1 раз
код 403 был возвращён 1 раз
код 304 был возвращён 1 раз
 
====================================================

</details>

Для контроля также можем запустить наш скрипт с полным файлом лога в качестве аргумента:

  /usr/local/bin/logmonitor.sh /vagrant/access-4560-644067.log


<details>
<summary>Результат работы скрипта с полным лог-файлом </summary>

Message 22:
From root@task9-bash.localdomain  Sun Jul  4 13:29:08 2021
Return-Path: <root@task9-bash.localdomain>
X-Original-To: root
Delivered-To: root@task9-bash.localdomain
Date: Sun, 04 Jul 2021 13:29:08 +0000
To: root@task9-bash.localdomain
Subject: access.log report from 2021-07-04_13:29:08
User-Agent: Heirloom mailx 12.5 7/5/10
Content-Type: text/plain; charset=utf-8
From: root@task9-bash.localdomain (root)
Status: R

----------------------------------------------------
=     Report period: 2021-07-04_13:28:01 - 2021-07-04_13:29:08     =
----------------------------------------------------
 
TOP 15 IP адресов с наибольшим количеством запросов: 
----------------------------------------------------
45 запросов с IP-адреса 93.158.167.130
39 запросов с IP-адреса 109.236.252.130
37 запросов с IP-адреса 212.57.117.19
33 запросов с IP-адреса 188.43.241.106
31 запросов с IP-адреса 87.250.233.68
24 запросов с IP-адреса 62.75.198.172
22 запросов с IP-адреса 148.251.223.21
20 запросов с IP-адреса 185.6.8.9
17 запросов с IP-адреса 217.118.66.161
16 запросов с IP-адреса 95.165.18.146
12 запросов с IP-адреса 95.108.181.93
12 запросов с IP-адреса 62.210.252.196
12 запросов с IP-адреса 185.142.236.35
12 запросов с IP-адреса 162.243.13.195
8 запросов с IP-адреса 163.179.32.118
 
TOP 10 запрашиваемых адресов на сервере: 
----------------------------------------------------
157 раз запрашивалась страница /
120 раз запрашивалась страница /wp-login.php
57 раз запрашивалась страница /xmlrpc.php
26 раз запрашивалась страница /robots.txt
12 раз запрашивалась страница /favicon.ico
9 раз запрашивалась страница /wp-includes/js/wp-embed.min.js?ver=5.0.4
7 раз запрашивалась страница /wp-admin/admin-post.php?page=301bulkoptions
7 раз запрашивалась страница /1
6 раз запрашивалась страница /wp-content/uploads/2016/10/robo5.jpg
6 раз запрашивалась страница /wp-content/uploads/2016/10/robo4.jpg
 
Все ошибки c момента последнего запуска: 
----------------------------------------------------
404 400 500 499 405 403

Cписок всех кодов возврата и их количество: 
----------------------------------------------------
код 200 был возвращён 498 раз
код 301 был возвращён 95 раз
код 404 был возвращён 51 раз
код 400 был возвращён 18 раз
код 500 был возвращён 3 раз
код 499 был возвращён 2 раз
код 405 был возвращён 1 раз
код 403 был возвращён 1 раз
код 304 был возвращён 1 раз
 
====================================================

</details>


#### The end)

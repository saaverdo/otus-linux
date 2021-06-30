## ДЗ - 8

Systemd

> Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше > усмотрение):  
>   
>     Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/> sysconfig);  
>     Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi);  
>     Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами;   
>     4*. Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.  



### I - Написать service, который будет раз в 30 секунд мониторить лог

#### log-gen.service
~~чтобы понять, как думает пингвин, надо стать пингвином~~
Чтобы мониторить лог, нам понадобится лог )))
Его также оформим генератор лога как service - `log-gen` 
Для этого набросаем питоновский скрипт (сорри, джексоны, на чём мог, на том и накалякал), который будет каждые 30 секунд (так задано в `log-gen.timer`) берёт очередные 10 (параметр $LINES - задаётся в файле параметров unit'а) строк из источника, syslog-файла с одного стенда (параметр $SLOG - задаётся в файле параметров unit'а) и дописывает их в лог-файл (параметр $DLOG - задаётся в файле параметров unit'а). Этот банкет, конечно, рано или поздно закончится, но не сразу, а если дописать логов в источник, он их таки допишет в лог-назначение к вящей радости и росту спама в `journald`.
Теперь всё это откровение запишем православным образом ~~на скрижа~~ в следующих файлах:

<details>
<summary>файл параметров unit'а `log-gen`</summary>
# Command-line options for log-gen service
LINES=10
SLOG=/vagrant/syslog.log
DLOG=/tmp/stplog.log
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


#### log-mon.service
Вспомним нашу задачу - мониторить лог на ключевое слово.
Лог есть - будем мониторить. И сервис для этого назовём `log-mon` (чтобы никто не догадался(с) )
Будем просто раз в 30 секунд (так ~~говорил Зара~~ задано в `log-gen.timer`) смотреть `tail`'ом файл лога (параметр $LOG) и скармливать его `grep`у на предмет наличия нашего стоп-слова ~~флюгегех~~(параметр $ALERT - в нашем случае "STP-W-PORTSTATUS"). А для пущей важности смотреть будем не весь лог, а со строки, которой он оканчивался во время предыдущего запуска монитора. Для этого нам послужит вспомогательный файл (параметр $LINENUM), в который мы после прохода `grep`'ом на предмет стоп-слова будем перезаписывать текущее к-во строк в лог-файле.
Однако, в случае нахождения упомянутого (в файле параметров unit'а, ессессно) стоп-слова сей факт будет радостно доведён до `journald` командой

    echo $DATE: Alert occured! | systemd-cat -p info -t log-mon

т.е. наше `echo` улетит ~~в трубу~~ к `systemd-cat` с уровнем важности `-p info` (нечего панику на пустом месте разводить) и идентификатором (`-t`) `log-mon` - чтобы проще было искать гордые вопли нашего скрипта-монитора "Хозяин, я его нашёл!!!".

Все вышеизложенные идеи не менее православным образом разместим в кошерных (с тоски зрения `systemd`) файлах:

<details>
<summary>файл параметров unit'а `log-mon`</summary>
# Command-line options for log monitor
ALERT="STP-W-PORTSTATUS"
LOG=/tmp/stplog.log
LINENUM=/tmp/linenum

</details>

<details>
<summary>файл `log-mon.service`</summary>
[Unit]
Description=log monitor service
After=systemd-journald.service

[Service]
Type=simple
Restart=always
RestartSec=5
EnvironmentFile=/etc/sysconfig/log-mon
ExecStartPre= $LINENUM
ExecStart=/usr/local/bin/log-mon.sh $ALERT $LOG $LINENUM
# ExecStopPost=echo '0' > $LINENUM

[Install]
WantedBy=multi-user.target

</details>

<details>
<summary>файл `log-mon.timer`</summary>

[Unit]
Description=Run log monitor script every 15 seconds

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=log-mon.service

[Install]
WantedBy=multi-user.target

</details>

<details>
<summary>файл `log_mon.py`</summary>
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

</details>


#### Запускаем!

Файлы сии раскатаются по закромам `vfs` на этапе провижиненга нашей ВМ

cp /vagrant/mon/log-{mon,gen} /etc/sysconfig/
cp /vagrant/mon/*.{service,timer} /etc/systemd/system/
cp /vagrant/mon/*.{sh,py} /usr/local/bin/
chmod +x /usr/local/bin/*

и запустятся сервисы:
    systemctl daemon-reload
    systemctl enable log-gen
    systemctl enable log-mon
    systemctl start log-gen
    systemctl start log-mon

    systemctl status log-gen

Генератор - как триггер: он либо спит, либо проснулся и в лог свой спамит.

> [root@task8-systemd /]# systemctl status log-gen  
> ● log-gen.service - log generator service  
>    Loaded: loaded (/etc/systemd/system/log-gen.service; disabled; vendor preset: disabled)  
>    Active: activating (auto-restart) since Wed 2021-06-30 17:30:14 UTC; 4s ago  
>   Process: 1794 ExecStart=/usr/bin/python3 /usr/local/bin/log_gen.py $LINES $SLOG $DLOG (code=exited, status=0/SUCCESS)  
>  Main PID: 1794 (code=exited, status=0/SUCCESS)  
>    CGroup: /system.slice/log-gen.service  

> [root@task8-systemd /]# systemctl status log-gen  
> ● log-gen.service - log generator service  
>    Loaded: loaded (/etc/systemd/system/log-gen.service; disabled; vendor preset: disabled)  
>    Active: active (running) since Wed 2021-06-30 17:30:19 UTC; 3ms ago  
>  Main PID: 1813 (python3)  
>    CGroup: /system.slice/log-gen.service  
>            └─1813 /usr/bin/python3 /usr/local/bin/log_gen.py 10 /vagrant/syslog.log /tmp/stplog.log  

любимый цербер может спать спокойно:

    systemctl status log-mon

> [root@task8-systemd /]# systemctl status log-mon  
> ● log-mon.service - log monitor service  
>    Loaded: loaded (/etc/systemd/system/log-mon.service; disabled; vendor preset: disabled)  
>    Active: activating (auto-restart) since Wed 2021-06-30 17:36:07 UTC; 3s ago  
>   Process: 2419 ExecStart=/usr/local/bin/log-mon.sh $ALERT $LOG $LINENUM (code=exited, status=0/SUCCESS)  
>  Main PID: 2419 (code=exited, status=0/SUCCESS)  

но каждые 30 секунд - подъём и зелёным глазом будет логи `grep`'ать он.

> [root@task8-systemd /]# systemctl status log-mon  
> ● log-mon.service - log monitor service  
>    Loaded: loaded (/etc/systemd/system/log-mon.service; disabled; vendor preset: disabled)  
>    Active: active (running) since Wed 2021-06-30 17:36:12 UTC; 1ms ago  
>  Main PID: 2430 (log-mon.sh)  
>    CGroup: /system.slice/log-mon.service  
>            └─2430 /bin/bash /usr/local/bin/log-mon.sh STP-W-PORTSTATUS /tmp/stplog.log /tmp/linenum  

Убедимся, что монитор наш на страже и скверны не пропустит (тут-то и `-t log-mon` пригодится):

    journalctl -t log-mon -e

> [vagrant@task8-systemd ~]$ sudo journalctl -t log-mon  
> -- Logs begin at Wed 2021-06-30 17:48:34 UTC, end at Wed 2021-06-30 17:53:54 UTC. --  
> Jun 30 17:52:41 task8-systemd log-mon[3077]: Wed Jun 30 17:52:41 UTC 2021: Alert occured!  
> Jun 30 17:52:47 task8-systemd log-mon[3091]: Wed Jun 30 17:52:47 UTC 2021: Alert occured!  
> Jun 30 17:52:52 task8-systemd log-mon[3105]: Wed Jun 30 17:52:52 UTC 2021: Alert occured!  
> Jun 30 17:53:02 task8-systemd log-mon[3128]: Wed Jun 30 17:53:02 UTC 2021: Alert occured!  
 

### II Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi)

Устанавливаем `spawn-fcgi` и необходимые пакеты

    yum install spawn-fcgi php php-cli mod_fcgid httpd -y

Глянем на `init`-скрипт

    cat /etc/init.d/spawn-fcgi

<details>
<summary>вывод</summary>

[root@task8-systemd ~]# cat /etc/init.d/spawn-fcgi
#!/bin/sh
#
# spawn-fcgi   Start and stop FastCGI processes
#
# chkconfig:   - 80 20
# description: Spawn FastCGI scripts to be used by web servers

### BEGIN INIT INFO
# Provides: 
# Required-Start: $local_fs $network $syslog $remote_fs $named
# Required-Stop: 
# Should-Start: 
# Should-Stop: 
# Default-Start: 
# Default-Stop: 0 1 2 3 4 5 6
# Short-Description: Start and stop FastCGI processes
# Description:       Spawn FastCGI scripts to be used by web servers
### END INIT INFO

# Source function library.
. /etc/rc.d/init.d/functions

exec="/usr/bin/spawn-fcgi"
prog="spawn-fcgi"
config="/etc/sysconfig/spawn-fcgi"

[ -e /etc/sysconfig/$prog ] && . /etc/sysconfig/$prog

lockfile=/var/lock/subsys/$prog

start() {
    [ -x $exec ] || exit 5
    [ -f $config ] || exit 6
    echo -n $"Starting $prog: "
    # Just in case this is left over with wrong ownership
    [ -n "${SOCKET}" -a -S "${SOCKET}" ] && rm -f ${SOCKET}
    daemon "$exec $OPTIONS >/dev/null"
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog
    # Remove the socket in order to never leave it with wrong ownership
    [ -n "${SOCKET}" -a -S "${SOCKET}" ] && rm -f ${SOCKET}
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}

restart() {
    stop
    start
}

reload() {
    restart
}

force_reload() {
    restart
}

rh_status() {
    # run checks to determine if the service is running or use generic status
    status $prog
}

rh_status_q() {
    rh_status &>/dev/null
}


case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 2
esac
exit $?

</details>

Баатюкши, вот такое надо показывать в лекции - тогда полку уверовавших в `systemd` основательно прибудет.

Раскомментируем строки с переменными в `/etc/sysconfig/spawn-fcgi`

    sed -i 's/#SOCKET/SOCKET/' /etc/sysconfig/spawn-fcgi
    sed -i 's/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi

Добавляем юнит

    cp /vagrant/scripts/fcgi/spawn-fcgi.service /etc/systemd/system/spawn-fcgi.service

Включаем и стартуем

    systemctl daemon-reload
    systemctl enable spawn-fcgi

Проверим и убедимся, что `spawn-fcgi` запускается как православный systemd-юнит.

    systemctl start spawn-fcgi

<details>
<summary>Вывод</summary>

[root@task8-systemd ~]# systemctl status spawn-fcgi
● spawn-fcgi.service - spawn-fcgi service
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2021-06-30 19:06:25 UTC; 6ms ago
  Process: 7890 ExecStart=/usr/bin/spawn-fcgi $OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 7891 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─7891 /usr/bin/php-cgi
           ├─7892 /usr/bin/php-cgi
           ├─7893 /usr/bin/php-cgi
           ├─7894 /usr/bin/php-cgi
           ├─7895 /usr/bin/php-cgi
           ├─7896 /usr/bin/php-cgi
           ├─7897 /usr/bin/php-cgi
           ├─7898 /usr/bin/php-cgi
           ├─7899 /usr/bin/php-cgi
           ├─7900 /usr/bin/php-cgi
           ├─7901 /usr/bin/php-cgi
           ├─7902 /usr/bin/php-cgi
           ├─7903 /usr/bin/php-cgi
           ├─7904 /usr/bin/php-cgi
           ├─7905 /usr/bin/php-cgi
           ├─7906 /usr/bin/php-cgi
           ├─7907 /usr/bin/php-cgi
           ├─7908 /usr/bin/php-cgi
           ├─7909 /usr/bin/php-cgi
           ├─7910 /usr/bin/php-cgi
           ├─7911 /usr/bin/php-cgi
           ├─7912 /usr/bin/php-cgi
           ├─7913 /usr/bin/php-cgi
           ├─7914 /usr/bin/php-cgi
           ├─7915 /usr/bin/php-cgi
           ├─7916 /usr/bin/php-cgi
           ├─7917 /usr/bin/php-cgi
           ├─7918 /usr/bin/php-cgi
           ├─7919 /usr/bin/php-cgi
           ├─7920 /usr/bin/php-cgi
           ├─7921 /usr/bin/php-cgi
           ├─7922 /usr/bin/php-cgi
           └─7923 /usr/bin/php-cgi

</details>


### III Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами

Установим `httpd` aka `apache`
Мы его уже установили на предыдущем шаге. )

Изначальные файлы

<details>
<summary>`/usr/lib/systemd/system/httpd.service`</summary>
[root@task8-systemd ~]# cat /usr/lib/systemd/system/httpd.service
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target

</details>
и
<details>
<summary>`/etc/sysconfig/httpd`</summary>

[root@task8-systemd ~]# cat /etc/sysconfig/httpd
#
# This file can be used to set additional environment variables for
# the httpd process, or pass additional options to the httpd
# executable.
#
# Note: With previous versions of httpd, the MPM could be changed by
# editing an "HTTPD" variable here.  With the current version, that
# variable is now ignored.  The MPM is a loadable module, and the
# choice of MPM can be changed by editing the configuration file
# /etc/httpd/conf.modules.d/00-mpm.conf.
# 

#
# To pass additional options (for instance, -D definitions) to the
# httpd binary at startup, set OPTIONS here.
#
#OPTIONS=

#
# This setting ensures the httpd process is started in the "C" locale
# by default.  (Some modules will not behave correctly if
# case-sensitive string comparisons are performed in a different
# locale.)
#
LANG=C

</details>

Мда, не то~~рт~~
Нам нужен `Type=forking` и вообще - шаблон `httpd@.service`
И ещё, чтобы колдунство было канонiчным, надо определить `PidFile` с `%i`

<details>
<summary>`/etc/systems/system/httpd@.service`</summary>

[Unit]
Description=The Apache HTTP Server instance %I
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=forking
PIDFile=/var/run/httpd/httpd-%i.pid
EnvironmentFile=/etc/sysconfig/httpd@%i
ExecStart=/usr/sbin/httpd $OPTIONS -c 'PidFile "/var/run/httpd/httpd-%i.pid"'
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true

[Install]
#RequiredBy=httpd.target
# If httpd.target doesn't exists, comment above uncomment underlying directives
WantedBy=multi-user.target

</details>

у нас будет два экземпляра `httpd`, работающих на портах `8080` и `8081`
Бог, конечно, любит троицу, но мне влом.

Скопируем наш юнит и файлы параметров в каноничные места 

    sudo cp /vagrant/scripts/httpd/httpd@.service /etc/systemd/system/
    sudo cp /vagrant/scripts/httpd/httpd@80* /etc/sysconfig/

Подправим `serverroot' и прочая

    sudo cp -a /etc/httpd /etc/httpd-8080
    sudo sed -i 's#^ServerRoot "/etc/httpd"$#ServerRoot "/etc/httpd-8080"#g' /etc/httpd-8080/conf/httpd.conf
    sudo sed -i 's#^Listen 80$#Listen 8080#g' /etc/httpd-8080/conf/httpd.conf
    sudo cp -a /etc/httpd /etc/httpd-8081
    sudo sed -i 's#^ServerRoot "/etc/httpd"$#ServerRoot "/etc/httpd-8081"#g' /etc/httpd-8081/conf/httpd.conf
    sudo sed -i 's#^Listen 80$#Listen 8081#g' /etc/httpd-8081/conf/httpd.conf

Запускаем:

    sudo systemctl enable httpd@808{0,1}.service
    sudo systemctl start httpd@808{0,1}.service

Посмотрим на всё, что мы наделали с решим, что это - хорошо )

    systemctl status httpd@808{0,1}

<details>
<summary>статус сервисов</summary>

[root@task8-systemd ~]# systemctl status httpd@808{0,1}
● httpd@8080.service - The Apache HTTP Server instance 8080
   Loaded: loaded (/etc/systemd/system/httpd@.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2021-06-30 20:49:09 UTC; 3min 41s ago
     Docs: man:httpd(8)
           man:apachectl(8)
  Process: 3275 ExecStart=/usr/sbin/httpd $OPTIONS -c PidFile "/var/run/httpd/httpd-%i.pid" (code=exited, status=0/SUCCESS)
 Main PID: 3278 (httpd)
   CGroup: /system.slice/system-httpd.slice/httpd@8080.service
           ├─3278 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           ├─3279 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           ├─3281 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           ├─3283 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           ├─3284 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           ├─3286 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"
           └─3288 /usr/sbin/httpd -d /etc/httpd-8080 -c PidFile "/var/run/httpd/httpd-8080.pid"

Jun 30 20:49:09 task8-systemd systemd[1]: Starting The Apache HTTP Server instance 8080...
Jun 30 20:49:09 task8-systemd httpd[3275]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.1.1. Set the 'ServerName' directive globally ... this message
Jun 30 20:49:09 task8-systemd systemd[1]: Can't open PID file /var/run/httpd/httpd-8080.pid (yet?) after start: No such file or directory
Jun 30 20:49:09 task8-systemd systemd[1]: Started The Apache HTTP Server instance 8080.

● httpd@8081.service - The Apache HTTP Server instance 8081
   Loaded: loaded (/etc/systemd/system/httpd@.service; enabled; vendor preset: disabled)
   Active: active (running) since Wed 2021-06-30 20:49:09 UTC; 3min 41s ago
     Docs: man:httpd(8)
           man:apachectl(8)
  Process: 3276 ExecStart=/usr/sbin/httpd $OPTIONS -c PidFile "/var/run/httpd/httpd-%i.pid" (code=exited, status=0/SUCCESS)
 Main PID: 3277 (httpd)
   CGroup: /system.slice/system-httpd.slice/httpd@8081.service
           ├─3277 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           ├─3280 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           ├─3282 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           ├─3285 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           ├─3287 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           ├─3289 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"
           └─3290 /usr/sbin/httpd -d /etc/httpd-8081 -c PidFile "/var/run/httpd/httpd-8081.pid"

Jun 30 20:49:09 task8-systemd systemd[1]: Starting The Apache HTTP Server instance 8081...
Jun 30 20:49:09 task8-systemd httpd[3276]: AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using 127.0.1.1. Set the 'ServerName' directive globally ... this message
Jun 30 20:49:09 task8-systemd systemd[1]: Can't open PID file /var/run/httpd/httpd-8081.pid (yet?) after start: No such file or directory
Jun 30 20:49:09 task8-systemd systemd[1]: Started The Apache HTTP Server instance 8081.
Hint: Some lines were ellipsized, use -l to show in full.

</details>

#### The end)

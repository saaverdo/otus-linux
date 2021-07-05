## ДЗ - 10  работа с процессами

Задания на выбор

    написать свою реализацию ps ax используя анализ /proc
    Результат ДЗ - рабочий скрипт который можно запустить

    написать свою реализацию lsof
    Результат ДЗ - рабочий скрипт который можно запустить

    дописать обработчики сигналов в прилагаемом скрипте, оттестировать, приложить сам скрипт, инструкции по использованию
    Результат ДЗ - рабочий скрипт который можно запустить + инструкция по использованию и лог консоли

    реализовать 2 конкурирующих процесса по IO. пробовать запустить с разными ionice
    Результат ДЗ - скрипт запускающий 2 процесса с разными ionice, замеряющий время выполнения и лог консоли

    реализовать 2 конкурирующих процесса по CPU. пробовать запустить с разными nice
    Результат ДЗ - скрипт запускающий 2 процесса с разными nice и замеряющий время выполнения и лог консоли


#### реализация ps ax используя анализ /proc 

`PID`  вытащми как имя каталога в `/proc/`
А прочие данные - `PPID`, `TTY`, `STAT`, `TIME` берём из `/proc/${PID}/stat`. https://linux.die.net/man/5/proc
Время взял как сумму `uTIME` и `sTIME` - там оно в тиках, т.н. `jiffies` поэтому потребовалось дополнитльное преобранзование:

> get_time(){  
>     #https://stackoverflow.com/questions/3875801/convert-jiffies-to-seconds  
>     SYS_CLK_TCK=$(getconf CLK_TCK)  
>     SUMTIME=$(awk '{print $14+$15}' "/proc/${PID}/stat")  
>     PSTIME="$(($SUMTIME / $SYS_CLK_TCK / 60)):$(($SUMTIME / $SYS_CLK_TCK % 60))"  
>     echo "$PSTIME"  
>  }  

Имя команды - из `/proc/${PID}/cmdline`, но если там пусто,   то берём второе поле из `/proc/${PID}/stat` и оборачиваем квадратными скобками

Скрипт `psax.sh` лежит в директории `/vagrant/`.
В вывод добавлено также поле `PPID` - просто так )
Запустим скрипт:

    /vagrant/psax.sh

<details>
<summary>Вывод скрипта:</summary>

```
[vagrant@task10-ps vagrant]$ bash psax.sh 
  PID  PPID TTY        STAT   TIME COMMAND
    1     0 0          S       0:1 /usr/lib/systemd/systemd --switched-root --system --deserialize 21
    2     0 0          S       0:0 [kthreadd]
    3     2 0          I       0:0 [rcu_gp]
    4     2 0          I       0:0 [rcu_par_gp]
    6     2 0          I       0:0 [kworker/0:0H-kblockd]
    7     2 0          I       0:0 [kworker/u2:0-events_unbound]
    8     2 0          I       0:0 [mm_percpu_wq]
    9     2 0          S       0:0 [ksoftirqd/0]
   10     2 0          R       0:0 [rcu_sched]
   11     2 0          S       0:0 [migration/0]
   13     2 0          S       0:0 [cpuhp/0]
   15     2 0          S       0:0 [kdevtmpfs]
   16     2 0          I       0:0 [netns]
   17     2 0          S       0:0 [rcu_tasks_rude_]
   18     2 0          S       0:0 [kauditd]
   19     2 0          S       0:0 [khungtaskd]
   20     2 0          S       0:0 [oom_reaper]
   21     2 0          I       0:0 [writeback]
   22     2 0          S       0:0 [kcompactd0]
   23     2 0          S       0:0 [ksmd]
   24     2 0          S       0:0 [khugepaged]
   74     2 0          I       0:0 [kintegrityd]
   75     2 0          I       0:0 [kblockd]
   76     2 0          I       0:0 [blkcg_punt_bio]
   77     2 0          I       0:0 [tpm_dev_wq]
   78     2 0          I       0:0 [md]
   79     2 0          I       0:0 [edac-poller]
   80     2 0          I       0:0 [devfreq_wq]
   81     2 0          S       0:0 [watchdogd]
   88     2 0          S       0:0 [kswapd0]
   90     2 0          I       0:0 [kthrotld]
   91     2 0          I       0:0 [acpi_thermal_pm]
   92     2 0          I       0:0 [kmpath_rdacd]
   93     2 0          I       0:0 [kaluad]
   95     2 0          I       0:0 [ipv6_addrconf]
   98     2 0          I       0:0 [zswap-shrink]
  103     2 0          I       0:0 [kworker/u3:0]
  178     2 0          I       0:0 [ata_sff]
  180     2 0          S       0:0 [scsi_eh_0]
  182     2 0          I       0:0 [scsi_tmf_0]
  183     2 0          S       0:0 [scsi_eh_1]
  184     2 0          I       0:0 [scsi_tmf_1]
  189     2 0          I       0:0 [kworker/0:1H-kblockd]
  200     2 0          I       0:0 [xfsalloc]
  201     2 0          I       0:0 [xfs_mru_cache]
  202     2 0          I       0:0 [xfs-buf/sda1]
  203     2 0          I       0:0 [xfs-conv/sda1]
  204     2 0          I       0:0 [xfs-cil/sda1]
  205     2 0          I       0:0 [xfs-reclaim/sda]
  206     2 0          I       0:0 [xfs-eofblocks/s]
  207     2 0          I       0:0 [xfs-log/sda1]
  208     2 0          S       0:0 [xfsaild/sda1]
  271     1 0          S       0:0 /usr/lib/systemd/systemd-journald
  311     1 0          S       0:0 /usr/lib/systemd/systemd-udevd
  336     1 0          S       0:0 /sbin/auditd
  361     1 0          S       0:0 /usr/lib/polkit-1/polkitd --no-debug
  363     1 0          S       0:0 /usr/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
  364     1 0          S       0:0 /sbin/rpcbind -w
  368     1 0          S       0:0 /usr/lib/systemd/systemd-logind
  380     1 0          S       0:0 /usr/sbin/chronyd
  382     2 0          I       0:0 [rpciod]
  384     2 0          I       0:0 [xprtiod]
  397     1 0          S       0:0 /usr/sbin/gssproxy -D
  409     1 0          S       0:0 /usr/sbin/crond -n
  410     1 1025       S       0:0 /sbin/agetty --noclear tty1 linux
  433     2 0          I       0:0 [cryptd]
  636     1 0          S       0:3 /usr/bin/python2 -Es /usr/sbin/tuned -l -P
  637     1 0          S       0:0 /usr/sbin/sshd -D -u0
  640     1 0          S       0:1 /usr/sbin/rsyslogd -n
  882     1 0          S       0:0 /usr/libexec/postfix/master -w
  885   882 0          S       0:0 qmgr -l -t unix -u
  898   637 0          S       0:0 sshd: vagrant [priv]
  901   898 0          S       0:1 sshd: vagrant@pts/0
  902   901 34816      S       0:0 -bash
 1038  1089 34817      S       0:0 bash psax.sh
 1087   902 34816      S       0:1 /usr/bin/mc -P /tmp/mc-vagrant/mc.pwd.902
 1089  1087 34817      S       0:0 bash -rcfile .bashrc
 1378     2 0          I       0:0 [kworker/u2:2-events_unbound]
 1794   882 0          S       0:0 pickup -l -t unix -u
 1869     1 0          S       0:0 /usr/sbin/NetworkManager --no-daemon
 1875     2 0          R       0:0 [kworker/0:1-events]
 1887     2 0          I       0:0 [kworker/0:2]
 1915  1869 0          S       0:0 /sbin/dhclient -d -q -sf /usr/libexec/nm-dhcp-helper -pf /var/run/dhclient-eth0.pid -lf /var/lib/NetworkManager/dhclient-5fb06bd0-0bb0-7ffb-45f1-d6edd65f3e03-eth0.lease -cf /var/lib/NetworkManager/dhclient-eth0.conf eth0
[vagrant@task10-ps vagrant]$ bash psax.sh 

```

</details>


#### The end)

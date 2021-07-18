## ДЗ - 16  Настраиваем бэкапы

Настроить стенд Vagrant с двумя виртуальными машинами: backup_server и client

Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

    Директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB.
    Репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение
    Имя бекапа должно содержать информацию о времени снятия бекапа
    Глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов
    Резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации.
    Написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение.


По ходу установки добавляем на сервер два диска для хранения бекапов, накатываем на них lvm, формируем vg на двух pv и создаём зеркалируемый lv.
Создаём папку `/var/backup` и монтируем туда наш LV

```
yum install lvm2 -y
pvcreate /dev/{sdb,sdc}
vgcreate vg_backup /dev/{sdb,sdc}
lvcreate -l+100%FREE -m 1 -n lv_backup vg_backup
mkfs.xfs /dev/mapper/vg_backup-lv_backup
mkdir /var/backup
mount /dev/mapper/vg_backup-lv_backup /var/backup
echo /dev/mapper/vg_backup-lv_backup /var/backup xfs defaults 0 0 >> /etc/fstab
```

Устанавливаем borg backup на сервере и клиенте из `epel-release` и мы готовы выполнить задание.

Итак, 
на сервере делаем пользователя 

    useradd -m back_oper

и даём ему права на директорию с бекапами

    chown -R back_oper:back_oper /var/backup/

на клиенте генерим ему ключ для подключения по ssh

    ssh-keygen

> Generating public/private rsa key pair.  
> Enter file in which to save the key (/root/.ssh/id_rsa):    
> Enter passphrase (empty for no passphrase):   
> Enter same passphrase again:   
> Your identification has been saved in /root/.ssh/id_rsa.  
> Your public key has been saved in /root/.ssh/id_rsa.pub.  
> The key fingerprint is:  
> SHA256:ETmqRT325OoMwumW1xfCaDqP0icwH5RaYAGmtUAChko root@client  
> The key's randomart image is:  
> +---[RSA 2048]----+  
> |O=o.   ...       |  
> |*Eo.  . *..      |  
> |+... o o.*       |  
> |.   + o  .o      |  
> |   = + oS.       |  
> |  + * + + .      |  
> |   * * = . .     |  
> |  . X.o + .      |  
> |   o.*.  .       |  
> +----[SHA256]-----+  

на сервере добавляем открытую часть ключа в `.ssh/authorized_keys` 

    mkdir ~back_oper/.ssh

    echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1E3kkWAhmT36iSEWj+iDKpQwq3LLt+snr8KO7StmjZ0hCrrf3tD+MKRQi1uku0wpaDwMJ3EJ8TCG+SeVqd+ETMeMDO0S46aLbWpX7+cun/SADEXNUdBuVmU49769YPXxW6aw937FEolcsrMlRRPBfcIRkENZ2MDZTkUM5GG/HJGuq82+IQye4QSBMMpc8U3iRDVtuULq0VHDgFRbknpNIQjN55JXpjMBZRVWzwG0RjYb9KuBhys1E2ZxFVzGSzwCp3n67l9qxII/2DYiQOVfzF9SoQ9shOihvXfD5TpEMIHLch+37TVsD7wo1qDT4kOZzcduhxJ581WktMSI1n17d root@client' > ~back_oper/.ssh/authorized_keys

на клиенте добавляем алиас в /etc/hosts для доступа к серверу бекапов по имени хоста

    echo "192.168.11.101 backup-server" >> /etc/hosts

Дальнейшие действия выполняем на клиенте:
инициализируем репозиторий бекапов c включеным шифрованием (опция `--encryption repokey`)

    borg init --encryption repokey back_oper@backup-server:/var/backup/client

> [root@client ~]# borg init --encryption repokey back_oper@backup-server:/var/backup/client  
> The authenticity of host 'backup-server (192.168.11.101)' can't be established.  
> ECDSA key fingerprint is SHA256:FvuPrR4OzV6xznscAj/2TkotbCYqVJ1KaW6RCGjibso.  
> ECDSA key fingerprint is MD5:f2:85:3f:b9:95:5a:e9:da:d1:86:6c:94:3c:f4:00:d0.  
> Are you sure you want to continue connecting (yes/no)? yes  
> Remote: Warning: Permanently added 'backup-server' (ECDSA) to the list of known hosts.  
> Enter new passphrase:   
> Enter same passphrase again:   
> Do you want your passphrase to be displayed for verification? [yN]: y  
> Your passphrase (between double-quotes): "otuspassword"  
> Make sure the passphrase displayed above is exactly what you wanted.  
>   
> By default repositories initialized with this version will produce security  
> errors if written to with an older version (up to and including Borg 1.0.8).  
>   
> If you want to use these older versions, you can disable the check by running:  
> borg upgrade --disable-tam ssh://back_oper@backup-server/var/backup/client  
>   
> See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.  
>   
> IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!  
> Use "borg key export" to export the key, optionally in printable format.  
> Write down the passphrase. Store both at safe place(s).  

повле вышеописанных действий на сервере бекапов в каталоге репы появится конфигурационный файл следующего содержания:

<details>
<summary>собержимое конфига репозирория</summary>

```
[root@backup-server ~]# cat /var/backup/client/config 
[repository]
version = 1
segments_per_dir = 1000
max_segment_size = 524288000
append_only = 0
storage_quota = 0
additional_free_space = 0
id = 835d7c8667754dfb3c35d36fa0e4eb74b3259d9747f4ba43842672d3f1cbb6d4
key = hqlhbGdvcml0aG2mc2hhMjU2pGRhdGHaAN5OA9BLVMmVSzL5XNTFdJev+41OPdAQH+786h
	51mvU0L79H+9bwssqw+7lGDrawBeKyh9rEkSAykxMYuXXGv+pkhF8+GkDDutnXHN/u7xRn
	LK75ISD8dExz8Yt12hJzWoBqs6tNs0CmfwOPW4oYTZzixFuPXZfr0CODoHOWdHvJxlhwMl
	83DFFBqQs8BJXg7pb7lRR+kTDdoEDLn2nm92W+IBhR2W8rp3fT73eVh6rE1PYwukplmsWi
	LEfitQkgRbW8BttwyE0sxNbCOC1f0rn/Iweup0mrLRXiAQcCDd6kaGFzaNoAIBopH93NBg
	fX7l3E/vD4T38NV5BmUczAom0oFRpcdl5Lqml0ZXJhdGlvbnPOAAGGoKRzYWx02gAgNjxm
	gO522wAU7GTfBIFb0nK3wE8CTDjySL+2jaGi/EandmVyc2lvbgE=

```

</details>

Для удобства работы пароль от ключа шифрования бекапа запишем в переменную окружения  

    export BORG_PASSPHRASE='passphrase'

Для запуска процесса бекапа подготовим скрипт `borg-back.sh`

<details>
<summary>содержимое borg-back.sh</summary>

```
#!/bin/bash
# Client and server name
BACKUP_USER=back_oper
BACKUP_HOST=backup-server
# Backup type, it may be data, system, mysql, binlogs, etc.
TYPEOFBACKUP="etc"
REPOSITORY=$BACKUP_USER@$BACKUP_HOST:/var/backup/$(hostname)-${TYPEOFBACKUP}
# Backup
borg create -v --stats $REPOSITORY::$TYPEOFBACKUP-$(date +%Y-%m-%d-%H-%M) /${TYPEOFBACKUP}
# Clear old backups
borg prune \
  -v --list \
  ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_REPO} \
  --keep-daily=90 \
  --keep-monthly=9
```

</details>

В нём для выполнения условия глубины хранения используем следующую конструкцию:
(то, что хранится согласно `--keep-daily` не идёт в зачёт `--keep-monthly`
https://borgbackup.readthedocs.io/en/stable/usage/prune.html)

> borg prune \  
>   -v --list \  
>   ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_REPO} \  
>   --keep-daily`=90 \  
>   --keep-monthly=9  

для запуска бекапа с заданным интервалом сделаем `systemd` сервис и повесим на него `timer`

<details>
<summary>borg-back.service</summary>

```
[Unit]
Description=Borg backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment="BORG_PASSPHRASE='otuspassword'"
ExecStart=/root/borg-back.sh
```

</details>

<details>
<summary>borg-back.timer</summary>

```
[Unit]
Description=Borg backup timer

[Timer]
#run hourly
OnBootSec=2min
OnUnitActiveSec=5min
Unit=borg-back.service

[Install]
WantedBy=multi-user.target
```

</details>

Запустим скрипт и убедимся, что он работает:

    ./borg-back.sh

```
[root@client ~]# ./borg-back.sh 
Creating archive at "back_oper@backup-server:/var/backup/client::etc-2021-07-18-17-00"
------------------------------------------------------------------------------
Archive name: etc-2021-07-18-17-00
Archive fingerprint: 9a2bc614f2beb91608e010e7f27faf61df7026d8c21ef39715d2d6b6b5bd5779
Time (start): Sun, 2021-07-18 17:00:27
Time (end):   Sun, 2021-07-18 17:00:27
Duration: 0.19 seconds
Number of files: 1725
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               32.33 MB             15.01 MB                699 B
All archives:              129.33 MB             60.05 MB             12.02 MB

                       Unique chunks         Total chunks
Chunk index:                    1317                 6900
------------------------------------------------------------------------------
Keeping archive: etc-2021-07-18-17-00                 Sun, 2021-07-18 17:00:27 [9a2bc614f2beb91608e010e7f27faf61df7026d8c21ef39715d2d6b6b5bd5779]
Pruning archive: etc-2021-07-18-16-59                 Sun, 2021-07-18 16:59:12 [2f36106c7cc2faedb6f43a4d6b613b2e5b7fc1aaa229cbf7ee8508446e3d783d] (1/3)
Pruning archive: etc-2021-07-18-16-05                 Sun, 2021-07-18 16:12:11 [224e12b6632871930749a3bd8e884b0712d4ba430da4649a8f548fbe445308d3] (2/3)
Pruning archive: etc-2021-07-18-03-44                 Sun, 2021-07-18 03:44:06 [edce17efb5fa3ef1a197233b1889e1d9dfa2fbc9b6c5a521f1f15ec3a48e8921] (3/3)
```

посмотрим, что осталось в репозитории:

> [root@client ~]# borg list back_oper@backup-server:/var/backup/client  
> etc-2021-07-18-17-00                 Sun, 2021-07-18 17:00:27 [9a2bc614f2beb91608e010e7f27faf61df7026d8c21ef39715d2d6b6b5bd5779]  

.... прошло не так много времени

<details>
<summary>статус borg-back.service</summary>

```
[root@client ~]# systemctl status borg-back.service
● borg-back.service - Borg backup
   Loaded: loaded (/etc/systemd/system/borg-back.service; static; vendor preset: disabled)
   Active: inactive (dead) since Sun 2021-07-18 17:17:08 UTC; 1min 11s ago
  Process: 1508 ExecStart=/root/borg-back.sh (code=exited, status=0/SUCCESS)
 Main PID: 1508 (code=exited, status=0/SUCCESS)

Jul 18 17:17:08 client borg-back.sh[1508]: ------------------------------------------------------------------------------
Jul 18 17:17:08 client borg-back.sh[1508]: Original size      Compressed size    Deduplicated size
Jul 18 17:17:08 client borg-back.sh[1508]: This archive:               32.33 MB             15.01 MB             19.67 kB
Jul 18 17:17:08 client borg-back.sh[1508]: All archives:               64.67 MB             30.03 MB             11.88 MB
Jul 18 17:17:08 client borg-back.sh[1508]: Unique chunks         Total chunks
Jul 18 17:17:08 client borg-back.sh[1508]: Chunk index:                    1308                 3452
Jul 18 17:17:08 client borg-back.sh[1508]: ------------------------------------------------------------------------------
Jul 18 17:17:08 client borg-back.sh[1508]: Keeping archive: etc-2021-07-18-17-17                 Sun, 2021-07-18 17:17:07 [ae205354f7e07513e60d8800076ceac0155caa4d1c3ff2fc435a101cc8ab47da]
Jul 18 17:17:08 client borg-back.sh[1508]: Pruning archive: etc-2021-07-18-17-00                 Sun, 2021-07-18 17:00:27 [9a2bc614f2beb91608e010e7f27faf61df7026d8c21ef39715d2d6b6b5bd5779] (1/1)
Jul 18 17:17:08 client systemd[1]: Started Borg backup.

```

</details>

И у нас есть один бекап - последний за текущий день

> [root@client ~]# borg list back_oper@backup-server:/var/backup/client  
> etc-2021-07-18-17-17                 Sun, 2021-07-18 17:17:07 [ae205354f7e07513e60d8800076ceac0155caa4d1c3ff2fc435a101cc8ab47da]  

#### The end)

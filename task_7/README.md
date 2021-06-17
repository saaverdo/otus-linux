### ДЗ - 4
Vagrant стенд для NFS

Условие задания:


> NFS:
> 
> vagrant up должен поднимать 2 виртуалки: сервер и клиент на сервер должна быть расшарена директория на клиента она должна автоматически монтироваться при старте (fstab или autofs) в шаре > должна быть папка upload с правами на запись
> 
>     требования для NFS: NFSv3 по UDP, включенный firewall




#### NFS SERVER 
Посмотрим, что у нас есть в наличии

    systemctl status nfs

> [root@nfss ~]# systemctl status nfs  
> ● nfs-server.service - NFS server and services  
>    Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; disabled; vendor preset: disabled)  
>      Drop-In: /run/systemd/generator/nfs-server.service.d  
>                 └─order-with-mounts.conf  
>                   
>    Active: inactive (dead)  

    systemctl status firewalld

> [root@nfss ~]# systemctl status firewalld  
> ● firewalld.service - firewalld - dynamic firewall daemon  
>    Loaded: loaded (/usr/lib/systemd/system/firewalld.service; disabled; vendor preset: enabled)  
>     Active: inactive (dead)  
>     Docs: man:firewalld(1)  

Итак, у нас не запущены демоны nfs и firewalld

Подготовим параметры nfs

> cat << EOF >> /etc/nfs.conf  
> [nfsd]  
>  udp=y  
>  tcp=n  
>  vers3=y  
>  vers4=n  
> EOF  

создадим папку для экспорта в nfs

    mkdir -p /var/nfs_share/upload

дадим на неё права

    chmod o+rwx /var/nfs_share/upload

и пропишем в `/etc/exports`

    echo '/var/nfs_share 192.168.50.11(rw,root_squash,all_squash,sync,wdelay)' >> /etc/exports

Запустим демонов nfs и огненных стен

    systemctl start firewalld
    systemctl enable firewalld

    systemctl start nfs
    systemctl enable nfs

И предоставим последним необходимые инструкции (пущать куда надо)

    firewall-cmd --add-service=nfs3
    firewall-cmd --add-service=rpc-bind
    firewall-cmd --add-service=mountd

И проверим, что же у нас экспортнулось

    exportfs -s

> [root@nfss ~]# exportfs -s  
> /var/nfs_share  192.168.50.11(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,all_squash)  
 
    systemctl status nfs

> [vagrant@nfss ~]$ systemctl status nfs  
> ● nfs-server.service - NFS server and services  
>    Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)  
>   Drop-In: /run/systemd/generator/nfs-server.service.d  
>            └─order-with-mounts.conf  
>    Active: active (exited) since Thu 2021-06-17 16:16:10 UTC; 3h 56min ago  
>  Main PID: 3569 (code=exited, status=0/SUCCESS)  
>    CGroup: /system.slice/nfs-server.service  

### CLIENT

Сделаем папку и смонтируем в неё шару с сервера

    mkdir -p /mnt/nfs
    mount -t nfs 192.168.50.10:/var/nfs_share /mnt/nfs -o rw,nosuid,noauto,x-systemd.automount,noexec,vers=3,proto=udp,hard,intr

Убедимся, что всё работает и создадим файл в подключенной шаре

    ll /mnt/nfs

> [vagrant@nfsc ~]$ ll /mnt/nfs  
> total 0  
> drwxr-xrwx. 2 root root 23 Jun 17  2021 upload  

Убедимся, что нам хватает прав на запись - создадим файл

    echo 'Lorem ipsum delor sit amet' > /mnt/nfs/upload/test.file

И убедимся, что всё получилось

    ll /mnt/nfs/upload

> [vagrant@nfsc ~]$ ll /mnt/nfs/upload/  
> total 4  
> -rw-rw-r--. 1 nfsnobody nfsnobody 27 Jun 17  2021 test.file  

    cat /mnt/nfs/upload/test.file

> [vagrant@nfsc ~]$ cat /mnt/nfs/upload/test.file   
> Lorem ipsum delor sit amet  

#### The end)

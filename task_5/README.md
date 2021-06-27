## ДЗ - 5

> Работа с загрузчиком  
>   
>     Попасть в систему без пароля несколькими способами  
>     Установить систему с LVM, после чего переименовать VG  
>     Добавить модуль в initrd  
>   
> 4(*). Сконфигурировать систему без отдельного раздела с /boot, а только с LVM >   Репозиторий с пропатченым grub: https://yum.rumyantsev.com/centos/7/x86_64/ PV >   необходимо инициализировать с параметром --bootloaderareasize 1m  


### Попасть в систему без пароля несколькими способами
Приступим.
Есть подготовленная ВМ с CentOS 8.2.
Запускаем нашу ВМ, в VirtualBox GUI ждём появления меню в выбором вариантов загрузки и наживаем `e` - редактировать выделенный пункт.
Теперь у нас еть несколько вариантов дальнейших действий:

#### 1) `init=/bin/sh`

В конце строки, начинающейся (в моём случае) с `linux` добавим `init=/bin/sh`
и убираем ересь вида `console=`
`Ctrl+x` - поехали!
Загрузка прошла, видим:

> sh-4.4#  

    mount | grep xfs

> sh-4.4# mount | grep xfs  
> /dev/sda1 on / type xfs (ro,realtime,sttr2,inode64,noquota)    


перемонтируем корневую фс в режим rw

    mount -o remount,rw /

Теперь у нас есть доступ на запись в корневую ФС.

    mkdir /method1
    ls -l /
<details>
    <summary>вывод команды</summary>

>  sh-4.4# ls -l /   
>  total 2097164  
>  lrwxrwxrwx  1 root    root             7 May 11  2019 bin -> usr/bin  
>  dr-xr-xr-x  5 root    root           273 Jun 11  2020 boot  
>  drwxr-xr-x 12 root    root          2400 Jun 24 10:50 dev  
>  drwxr-xr-x 81 root    root          8192 Jun 24 09:53 etc  
>  drwxr-xr-x  3 root    root            21 Jun 11  2020 home  
>  lrwxrwxrwx  1 root    root             7 May 11  2019 lib -> usr/lib  
>  lrwxrwxrwx  1 root    root             9 May 11  2019 lib64 -> usr/lib64  
>  drwxr-xr-x  2 root    root             6 May 11  2019 media  
>  drwxrwxrwx  2 root    root            18 Jun 24 11:42 method1  
>  drwxr-xr-x  2 root    root             6 May 11  2019 mnt  
>  drwxr-xr-x  2 root    root             6 May 11  2019 opt  
>  dr-xr-xr-x 67 root    root             0 Jun 24 10:51 proc  
>  dr-xr-x---  2 root    root           137 Jun 11  2020 root  
>  drwxr-xr-x 11 root    root           240 Jun 24 10:50 run  
>  lrwxrwxrwx  1 root    root             8 May 11  2019 sbin -> usr/sbin  
>  drwxr-xr-x  2 root    root             6 May 11  2019 srv  
>  -rw-------  1 root    root    2147483648 Jun 11  2020 swapfile  
>  dr-xr-xr-x 13 root    root             0 Jun 24 10:50 sys  
>  drwxrwxrwt  7 root    root           145 Jun 24 09:54 tmp  
>  drwxr-xr-x 12 root    root           144 Jun 11  2020 usr  
>  drwxrwxr-x  2 vagrant vagrant         42 Jun 24 09:53 vagrant  
>  drwxr-xr-x 20 root    root           278 Jun 24 09:53 var  

</details>

#### 2) `rd.break`

Аналогично п.1 конце строки, начинающейся (в моём случае) с `linux` добавляем `rd.break` и убираем ересь вида `console=`
`Ctrl+x` - поехали!
Загружаемся и попадаем в emergency mode.

> switch_root:/#  

Корневая ФС у нас лежит в `/sysroot`

    mount | grep root

> switch_root:/# mount | grep root  
> rootfs on / type rootfs (rw)  
> /dev/sda1 on /sysroot type xfs (ro,realtime,sttr2,inode64,noquota)  

перемонтируем корневую ФС

    mount -o remount,rw /sysroot

и сделаем `chroot` в неё

    chroot /sysroot

> sh-4.4#  

Ура, теперь у нас есть доступ на запись в корневую ФС

    mkdir /method2
    ls -l /
<details>
    <summary>вывод команды</summary>

>  sh-4.4# ls -l /   
>  total 2097172  
>  dr-xr-xr-x 20 root    root          4096 Jun 24 12:22 .  
>  dr-xr-xr-x 20 root    root          4096 Jun 24 12:22 ..  
>  -rw-r--r--  1 root    root             0 Jun 24 12:21 .autorelabel  
>  lrwxrwxrwx  1 root    root             7 May 11  2019 bin -> usr/bin  
>  dr-xr-xr-x  5 root    root           273 Jun 11  2020 boot  
>  drwxr-xr-x  2 root    root             6 Jun 11  2020 dev  
>  drwxr-xr-x 81 root    root          8192 Jun 24 12:17 etc  
>  drwxr-xr-x  3 root    root            21 Jun 11  2020 home  
>  lrwxrwxrwx  1 root    root             7 May 11  2019 lib -> usr/lib  
>  lrwxrwxrwx  1 root    root             9 May 11  2019 lib64 -> usr/lib64  
>  drwxr-xr-x  2 root    root             6 May 11  2019 media  
>  drwxrwxrwx  2 root    root            18 Jun 24 11:42 method1  
>  drwxr-xr-x  2 root    root            18 Jun 24 12:20 method2  
>  drwxr-xr-x  2 root    root             6 May 11  2019 mnt  
>  drwxr-xr-x  2 root    root             6 May 11  2019 opt  
>  drwxr-xr-x  2 root    root             6 Jun 11  2020 proc  
>  dr-xr-x---  2 root    root           137 Jun 11  2020 root  
>  drwxr-xr-x  2 root    root             6 Jun 11  2020 run  
>  lrwxrwxrwx  1 root    root             8 May 11  2019 sbin -> usr/sbin  
>  drwxr-xr-x  2 root    root             6 May 11  2019 srv  
>  -rw-------  1 root    root    2147483648 Jun 11  2020 swapfile  
>  drwxr-xr-x  2 root    root             6 Jun 11  2020 sys  
>  drwxrwxrwt  7 root    root            93 Jun 24 12:06 tmp  
>  drwxr-xr-x 12 root    root           144 Jun 11  2020 usr  
>  drwxrwxr-x  2 vagrant vagrant         42 Jun 24 09:53 vagrant  
>  drwxr-xr-x 20 root    root           278 Jun 24 09:53 var  

</details>

теперь можно поменять пароль рута

    passwd root

> Changing password for user root.  
> New password:  
> Retype new password:  
> passwd: all authentication tokens updated successfully  

и (memento SElinux!) 

    touch /.autorelabel

всё, можно перезагружаться и заходить с новым паролем

    exit
    reboot

#### 3) `rw init=/sysroot/bin/sh`

Аналогично п.1 в строке, начинающейся (в моём случае) с `linux` заменяем `ro` на `rw` и добавляем в конце `init=/sysroot/bin/sh`. Помним про ересь!
`Ctrl+x` - поехали!
Итог - корневая ФС у нас смонтирована в `/sysroot` и доступна на запись

    mount | grep root

>  sh-4.4# mount | grep root  
>  rootfs on / type rootfs (rw)  
>  /dev/sda1 on /sysroot type xfs (rw,relatime,attr2,inode64,noquota)  

    mkdir /method3
    ls -l /

<details>
    <summary>вывод команды</summary>

>  sh-4.4# ls -l /  
>  total 2097164  
>  lrwxrwxrwx.  1 root    root             7 May 11  2019 bin -> usr/bin  
>  dr-xr-xr-x.  5 root    root           273 Jun 11  2020 boot  
>  drwxr-xr-x. 17 root    root          2840 Jun 24 17:11 dev  
>  drwxr-xr-x. 83 root    root          8192 Jun 24 17:12 etc  
>  drwxr-xr-x.  3 root    root            21 Jun 11  2020 home  
>  lrwxrwxrwx.  1 root    root             7 May 11  2019 lib -> usr/lib  
>  lrwxrwxrwx.  1 root    root             9 May 11  2019 lib64 -> usr/lib64  
>  drwxr-xr-x.  2 root    root             6 May 11  2019 media  
>  drwxrwxrwx.  2 root    root            18 Jun 24 11:42 method1  
>  drwxr-xr-x.  2 root    root            18 Jun 24 12:20 method2  
>  drwxr-xr-x.  2 root    root            18 Jun 24 13:41 method3  
>  drwxr-xr-x.  2 root    root             6 May 11  2019 mnt  
>  drwxr-xr-x.  2 root    root             6 May 11  2019 opt  
>  dr-xr-xr-x. 95 root    root             0 Jun 24 17:10 proc  
>  dr-xr-x---.  2 root    root           158 Jun 24 12:25 root  
>  drwxr-xr-x. 23 root    root           720 Jun 24 17:11 run  
>  lrwxrwxrwx.  1 root    root             8 May 11  2019 sbin -> usr/sbin  
>  drwxr-xr-x.  2 root    root             6 May 11  2019 srv  
>  -rw-------.  1 root    root    2147483648 Jun 11  2020 swapfile  
>  dr-xr-xr-x. 13 root    root             0 Jun 24 17:11 sys  
>  drwxrwxrwt.  8 root    root           172 Jun 24 21:01 tmp  
>  drwxr-xr-x. 12 root    root           144 Jun 11  2020 usr  
>  drwxrwxr-x.  2 vagrant vagrant         42 Jun 24 09:53 vagrant  
>  drwxr-xr-x. 20 root    root           278 Jun 24 09:53 var  

</details>

### часть 2 Установить систему с LVM, после чего переименовать VG

Перезапустил ВМ (предыдущая была без lvm), посмотрим:

    vgs
>  [root@lvm ~]# vgs  
>    VG         #PV #LV #SN Attr   VSize   VFree  
>    VolGroup00   1   2   0 wz--n- <38.97g    0   

Переименуем VG в `OtusRoot`

    vgrename VolGroup00 OtusRoot

> [root@lvm ~]# vgrename VolGroup00 OtusRoot  
>   Volume group "VolGroup00" successfully renamed to "OtusRoot"  

Исправим значение VG на актуальное в `/etc/fstab`

    sed -i "s#VolGroup00#OtusRoot#g" /etc/fstab
    cat /etc/fstab

> [root@lvm ~]# cat /etc/fstab  
>   
> \#  
> \# /etc/fstab  
> \# Created by anaconda on Sat May 12 18:50:26 2018  
> \#  
> \# Accessible filesystems, by reference, are maintained under '/dev/disk'  
> \# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info  
> \#  
> /dev/mapper/OtusRoot-LogVol00 /                       xfs     defaults        0 0  
> UUID=570897ca-e759-4c81-90cf-389da6eee4cc /boot                   xfs     > defaults        0 0  
> /dev/mapper/OtusRoot-LogVol01 swap                    swap    defaults        0 0  
> \#VAGRANT-BEGIN  
> \# The contents below are automatically generated by Vagrant. Do not modify.  
> \#VAGRANT-END  

Аналогичным образом исправим `/etc/default/grub`

    sed -i "s#VolGroup00#OtusRoot#g" /etc/default/grub
    cat /etc/default/grub

> [root@lvm ~]# cat /etc/default/grub  
> GRUB_TIMEOUT=1  
> GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"  
> GRUB_DEFAULT=saved  
> GRUB_DISABLE_SUBMENU=true  
> GRUB_TERMINAL_OUTPUT="console"  
> GRUB_CMDLINE_LINUX="no_timer_check console=tty0 console=ttyS0,115200n8 net.> ifnames=0 biosdevname=0 elevator=noop crashkernel=auto rd.lvm.lv=OtusRoot/> LogVol00 rd.lvm.lv=OtusRoot/LogVol01 rhgb quiet"  
> GRUB_DISABLE_RECOVERY="true"  

И, наконец, пофиксим `/boot/grub2/grub.cfg`

    sed -i "s#VolGroup00#OtusRoot#g" /boot/grub2/grub.cfg
    cat /boot/grub2/grub.cfg grep lv=

>  [root@lvm ~]# cat /boot/grub2/grub.cfg | grep lv=  
>  	linux16 /vmlinuz-3.10.0-862.2.3.el7.x86_64 root=/dev/mapper/OtusRoot-LogVol00 >  ro no_timer_check console=tty0 console=ttyS0,115200n8 net.ifnames=0 >  biosdevname=0 elevator=noop crashkernel=auto rd.lvm.lv=OtusRoot/LogVol00 rd.>  lvm.lv=OtusRoot/LogVol01 rhgb quiet   

Пересоберём `initrd` с новым VG

    mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)

> Executing: /sbin/dracut -f -v /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img 3.10.> 0-862.2.3.el7.x86_64  
>  *** Creating image file ***  
>  *** Creating image file done ***  
>  *** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' >  done ***  

Перезагружаемся и проверяем, что изменения прошли успешно

    sudo vgs

> [vagrant@lvm ~]$ sudo vgs  
>   VG       #PV #LV #SN Attr   VSize   VFree  
>   OtusRoot   1   2   0 wz--n- <38.97g    0   

### часть 3. Появление пингвина. Добавить модуль а initrd

Создадим директорию для нашеко модуля с именем `01test`
    mkdir /usr/lib/dracut/modules.d/01test

И скопируем в неё скрипты модуля

    curl --silent https://gist.githubusercontent.com/lalbrekht/e51b2580b47bb5a150bd1a002f16ae85/raw/80060b7b300e193c187bbcda4d8fdf0e1c066af9/gistfile1.txt | sudo tee /usr/lib/dracut/modules.d/01test/module-setup.sh

    curl --silent https://gist.githubusercontent.com/lalbrekht/ac45d7a6c6856baea348e64fac43faf0/raw/69598efd5c603df310097b52019dc979e2cb342d/gistfile1.txt | sudo tee /usr/lib/dracut/modules.d/01test/test.sh

Сделаем из исполняемыми:

    chmod +x /usr/lib/dracut/modules.d/01test/*.sh
    ll /usr/lib/dracut/modules.d/01test/

> [root@lvm ~]# ll /usr/lib/dracut/modules.d/01test/  
> total 8  
> -rwxr-xr-x. 1 root root 126 Jun 27 10:54 module-setup.sh  
> -rwxr-xr-x. 1 root root 334 Jun 27 10:56 test.sh  

Теперь пересобираем `initrd`

    dracut -f -v
    lsinitrd -m /boot/initramfs-$(uname -r).img | grep test

> [root@lvm /]# lsinitrd -m /boot/initramfs-$(uname -r).img | grep test  
> test  

Отключим опции `rhgb` и `quiet` в `grub.cfg`

    sed -i 's# rhgb quiet##g' /etc/default/grub
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg

перезагружаемся - призагрузке системы у нас появляется пингвин ы выыоде терминала
...
PROFIT! )

#### The end)

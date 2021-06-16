### ДЗ - 3


запись работы выполнена командой 
    script --timing=timing.txt -a lvm-session.txt
результат - в файлах `lvm-session.txt` и `timing.txt`

Условие задания:
> на имеющемся образе /dev/mapper/VolGroup00-LogVol00 38G 738M 37G 2% /
> 
> уменьшить том под / до 8G выделить том под /home выделить том под /var /var - сделать в mirror /home - сделать том для снэпшотов прописать монтирование в fstab попробовать с разными > опциями и разными файловыми системами ( на выбор)
> 
>     сгенерить файлы в /home/
>     снять снэпшот
>     удалить часть файлов
>     восстановится со снэпшота
>     залоггировать работу можно с помощью утилиты script



#### Stage 1 
Посмотрим, что у нас есть в наличии

    lsblk
> [root@lvm ~]# lsblk
> NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
> sda                       8:0    0   40G  0 disk 
> ├─sda1                    8:1    0    1M  0 part 
> ├─sda2                    8:2    0    1G  0 part /boot
> └─sda3                    8:3    0   39G  0 part 
>   ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
>   └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
> sdb                       8:16   0   10G  0 disk 
> sdc                       8:32   0    2G  0 disk 
> sdd                       8:48   0    1G  0 disk 
> sde                       8:64   0    1G  0 disk 

    df -Th
> [root@lvm ~]# df -Th
> Filesystem                      Type      Size  Used Avail Use% Mounted on
> /dev/mapper/VolGroup00-LogVol00 xfs        38G  775M   37G   3% /
> devtmpfs                        devtmpfs  109M     0  109M   0% /dev
> tmpfs                           tmpfs     118M     0  118M   0% /dev/shm
> tmpfs                           tmpfs     118M  4.5M  114M   4% /run
> tmpfs                           tmpfs     118M     0  118M   0% /sys/fs/cgroup
> /dev/sda2                       xfs      1014M   63M  952M   7% /boot
> tmpfs                           tmpfs      24M     0   24M   0% /run/user/1000


т. к. файловая система на / у нас xfs, мы не можем уменьшить её размер.
поэтому мы перенсём / на другой диск (sdb), удалим старую корневую ФС, 
создадим на её месте новую необходимого размера, затем вернём / обратно на переделанный раздел
В процессе нам понадобится утилита `xfsdump`:
    yum install -y xfsdump
Подготовим новый раздел для временного размещения корневого тома на sdb
Инициализизируем физический том, создадим группу томов `vg_temp` и в ней - логический том `lv_temp`
    pvcreate /dev/sdb
    vgcreate vg_temp /dev/sdb
    vgscan
    lvcreate -l +100%FREE -n lv_temp vg_temp

В новосозданном LV создадим файловую систему XFS и смотнируем в каталог `/mnt/new_root`
    mkfs.xfs /dev/vg_temp/lv_temp
    mkdir -p /mnt/new_root
    mount /dev/vg_temp/lv_temp /mnt/new_root
Сдампим текущий корневой раздел во временный:
    xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt/new_root/
Делаем `chroot` во временный корень ФС
    for i in /proc/ /sys/ /dev/ /run/; do mount --bind $i /mnt/new_root/$i; done
    chroot /mnt/new_root/
    mount $(cat /etc/fstab | grep -o ^.boot) /boot
Перепишем загрузчик и обновим образы загрузки:
    cd /boot
    grub2-mkconfig -o /boot/grub2/grub.cfg
    for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force;done
Меняем в `/boot/grub2/grub.cfg` строки со старым корневым томом на новый
    sed -i "s#lv=VolGroup00/LogVol01#lv=vg_temp/lv_temp#g" /boot/grub2/grub.cfg
Выходим из `chroot` и перезагружаемся
    exit
    shutdown -r now


#### Time to turn it back!

Залогинимся, проверим что система использует временный раздел как корень
    lsblk
> [root@lvm ~]# lsblk
> NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
> sda                       8:0    0   40G  0 disk 
> ├─sda1                    8:1    0    1M  0 part 
> ├─sda2                    8:2    0    1G  0 part /boot
> └─sda3                    8:3    0   39G  0 part 
>   ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  
>   └─VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
> sdb                       8:16   0   10G  0 disk 
> └─vg_temp-lv_temp       253:1    0   10G  0 lvm  /
> sdc                       8:32   0    2G  0 disk 
> sdd                       8:48   0    1G  0 disk 
> sde                       8:64   0    1G  0 disk 

    df -Th
> [root@lvm ~]# df -Th
> Filesystem                  Type      Size  Used Avail Use% Mounted on
> /dev/mapper/vg_temp-lv_temp xfs        10G  775M  9.3G   8% /
> devtmpfs                    devtmpfs  110M     0  110M   0% /dev
> tmpfs                       tmpfs     118M     0  118M   0% /dev/shm
> tmpfs                       tmpfs     118M  4.5M  114M   4% /run
> tmpfs                       tmpfs     118M     0  118M   0% /sys/fs/cgroup
> /dev/sda2                   xfs      1014M   61M  954M   6% /boot
> tmpfs                       tmpfs      24M     0   24M   0% /run/user/1000

    lvs
> [root@lvm ~]# lvs
> LV       VG         Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
> LogVol00 VolGroup00 -wi-a----- <37.47g                                                    
> LogVol01 VolGroup00 -wi-ao----   1.50g                                                    
> lv_temp  vg_temp    -wi-ao---- <10.00g              

Теперь удалим логический том с исходной корневой ФС
    lvremove -y VolGroup00/LogVol00
Создадим новый логический том нужного размера с файловой системой XFS
    lvcreate -y -n LogVol00 -L 8G VolGroup00
    mkfs.xfs /dev/VolGroup00/LogVol00 
Теперь будем возвращать корневую ФС на её законное место.
Монтируем этот раздел в папку `/mnt/new_root/`
    mount /dev/VolGroup00/LogVol00 /mnt/new_root/
Возвращаем содержимое корневого раздела в новосозданный том
    xfsdump -J - / | xfsrestore -J - /mnt/new_root/
Делаем `chroot` во новый корень ФС
    for i in /proc/ /sys/ /dev/ /run/; do mount --bind $i /mnt/new_root/$i; done
    chroot /mnt/new_root/
    mount $(cat /etc/fstab | grep -o ^.boot) /boot
Перепишем загрузчик и обновим образы загрузки:
    cd /boot
    grub2-mkconfig -o /boot/grub2/grub.cfg
    for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force;done
Проверяем `/boot/grub2/grub.cfg` строки `lv=` должны указывать на нужный том
    cat /boot/grub2/grub.cfg | grep lv=
Выходим из `chroot` и перезагружаемся
    exit
    shutdown -r now

Прооверяем, всё ли у нас в порядке
    cd /
    sudo -i
    lsblk
> [root@lvm ~]# lsblk
> NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
> sda                       8:0    0   40G  0 disk 
> ├─sda1                    8:1    0    1M  0 part 
> ├─sda2                    8:2    0    1G  0 part /boot
> └─sda3                    8:3    0   39G  0 part 
>   ├─VolGroup00-LogVol00 253:0    0    8G  0 lvm  /
>   └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
> sdb                       8:16   0   10G  0 disk 
> └─vg_temp-lv_temp       253:2    0   10G  0 lvm  
> sdc                       8:32   0    2G  0 disk 
> sdd                       8:48   0    1G  0 disk 
> sde                       8:64   0    1G  0 disk 

Удалим нашу временную группу томов `vg_temp`
    vgremove -y vg_temp
    rm -rf /mnt/new_root/


#### STAGE 2 Time to play

Теперь у нас есть незадействованный физический том `/dev/sdb`
    pvscan
> [root@lvm ~]# pvscan
> PV /dev/sda3   VG VolGroup00      lvm2 [<38.97 GiB / <29.47 GiB free]
> PV /dev/sdb                       lvm2 [10.00 GiB]
> Total: 2 [<48.97 GiB] / in use: 1 [<38.97 GiB] / in no VG: 1 [10.00 GiB]
Добавим его в группу томов `VolGroup00`
    vgextend VolGroup00 /dev/sdb

Сделаем логический том для раздела `/var` с зеркалом, он использовать ФС ext4
    lvcreate -l +100%FREE -m 1 -n lv-var VolGroup00
    mkfs.ext4 /dev/VolGroup00/lv-var
Убедимся, что данный раздел работает в режиме mirror
    lvs
> [root@lvm ~]# lvs
> LV       VG         Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
> LogVol00 VolGroup00 -wi-ao----  8.00g                                                    
> LogVol01 VolGroup00 -wi-ao----  1.50g                                                    
> lv-var   VolGroup00 rwi-a-r--- <9.94g                                    100.00       
Перекинем данные из директории `var` корневого раздела на новый раздел для `/var`- `/dev/VolGroup00/lv-var`
    mount /dev/VolGroup00/lv-var /mnt
    cp -ax /var/* /mnt
    umount /mnt
И смонтируем его в `/var/`
    mount /dev/VolGroup00/lv-var /var


Создадим логический том для раздела `/home` размером 10 гигибайт. Он будет использовать ФС XFS
    lvcreate -L 10G -n lv-home VolGroup00
    mkfs.xfs /dev/VolGroup00/lv-home
Убедимся, что данный раздел работает
    lvs
> [root@lvm ~]# lvs
> LV       VG         Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
> LogVol00 VolGroup00 -wi-ao----  8.00g                                                    
> LogVol01 VolGroup00 -wi-ao----  1.50g                                                    
> lv-home  VolGroup00 -wi-a----- 10.00g                                                    
> lv-var   VolGroup00 rwi-aor--- <9.94g                                    100.00          

Перекинем данные из директории `/home` корневого раздела на новый раздел для `/home` - `/dev/VolGroup00/lv-home`
    mount /dev/VolGroup00/lv-home /mnt
    cp -ax /home/* /mnt
    umount /mnt
И смонтируем его в `/home/`
    mount /dev/VolGroup00/lv-home /home

Но 10 гигабайт для /home кажется маловато... Растянем же это удовольствие до 15-ти гигабайт!
Смотрим, что у нас с размером `/home`
    df -Th | grep home
> [root@lvm ~]# df -Th | grep home
> /dev/mapper/VolGroup00-lv--home xfs        10G   33M   10G   1% /home

Расширим `lv-home` до 15G
    lvextend -L 15G /dev/VolGroup00/lv-home
размер LV изменился
    lvs | grep home
> [root@lvm ~]# lvs | grep home
> lv-home  VolGroup00 -wi-ao---- 15.00g 

а размер ФС - нет
    df -Th | grep home
> [root@lvm ~]# df -Th | grep home
> /dev/mapper/VolGroup00-lv--home xfs        10G   33M   10G   1% /home

теперь растянем ~~сову на гло~~ ФС
    xfs_growfs /home
И вот результат
    df -Th | grep home
> [root@lvm ~]#     df -Th | grep home
> /dev/mapper/VolGroup00-lv--home xfs        15G   33M   15G   1% /home
    

#### STAGE 3 - сгенерить файлы, сделать снапшот, удалить данные со снапшота, восстановиться со снапшота
Генерим пачку странных файлов
for i in $(seq 1 25); do dd if=/dev/urandom of=/home/test.humster$i bs=1024 count=$i; done
ll /home
<details>
<summary>Вывод ll home</summary>
[root@lvm ~]# ll /home
total 364
-rw-r--r--. 1 root    root     1024 Jun 16 10:54 test.humster1
-rw-r--r--. 1 root    root    10240 Jun 16 10:54 test.humster10
-rw-r--r--. 1 root    root    11264 Jun 16 10:54 test.humster11
-rw-r--r--. 1 root    root    12288 Jun 16 10:54 test.humster12
-rw-r--r--. 1 root    root    13312 Jun 16 10:54 test.humster13
-rw-r--r--. 1 root    root    14336 Jun 16 10:54 test.humster14
-rw-r--r--. 1 root    root    15360 Jun 16 10:54 test.humster15
-rw-r--r--. 1 root    root    16384 Jun 16 10:54 test.humster16
-rw-r--r--. 1 root    root    17408 Jun 16 10:54 test.humster17
-rw-r--r--. 1 root    root    18432 Jun 16 10:54 test.humster18
-rw-r--r--. 1 root    root    19456 Jun 16 10:54 test.humster19
-rw-r--r--. 1 root    root     2048 Jun 16 10:54 test.humster2
-rw-r--r--. 1 root    root    20480 Jun 16 10:54 test.humster20
-rw-r--r--. 1 root    root    21504 Jun 16 10:54 test.humster21
-rw-r--r--. 1 root    root    22528 Jun 16 10:54 test.humster22
-rw-r--r--. 1 root    root    23552 Jun 16 10:54 test.humster23
-rw-r--r--. 1 root    root    24576 Jun 16 10:54 test.humster24
-rw-r--r--. 1 root    root    25600 Jun 16 10:54 test.humster25
-rw-r--r--. 1 root    root     3072 Jun 16 10:54 test.humster3
-rw-r--r--. 1 root    root     4096 Jun 16 10:54 test.humster4
-rw-r--r--. 1 root    root     5120 Jun 16 10:54 test.humster5
-rw-r--r--. 1 root    root     6144 Jun 16 10:54 test.humster6
-rw-r--r--. 1 root    root     7168 Jun 16 10:54 test.humster7
-rw-r--r--. 1 root    root     8192 Jun 16 10:54 test.humster8
-rw-r--r--. 1 root    root     9216 Jun 16 10:54 test.humster9
drwx------. 3 vagrant vagrant    95 Jun 16 10:42 vagrant
</details>

создадим снапшот хомяка
    lvcreate -L 1G -s -n lv-home-snap /dev/VolGroup00/lv-home
Удалим "случайно" файлы
    rm -f /home/test.humster{5..25}
упс, самые нужные файлы - всё(
    ll /home
> [root@lvm ~]# ll /home
> total 16
> -rw-r--r--. 1 root    root    1024 Jun 16 10:54 test.humster1
> -rw-r--r--. 1 root    root    2048 Jun 16 10:54 test.humster2
> -rw-r--r--. 1 root    root    3072 Jun 16 10:54 test.humster3
> -rw-r--r--. 1 root    root    4096 Jun 16 10:54 test.humster4
> drwx------. 3 vagrant vagrant   95 Jun 16 10:42 vagrant

не страшно, у нас есть снапшот!
    lvs
> [root@lvm ~]# lvs
> LV           VG         Attr       LSize  Pool Origin  Data%  Meta%  Move Log Cpy%Sync Convert
> LogVol00     VolGroup00 -wi-ao----  8.00g                                                     
> LogVol01     VolGroup00 -wi-ao----  1.50g                                                     
> lv-home      VolGroup00 owi-aos--- 15.00g                                                     
> lv-home-snap VolGroup00 swi-a-s---  1.00g      lv-home 0.00                                   
> lv-var       VolGroup00 rwi-aor--- <9.94g                                     100.00    
смонтируем снапшот в `/mnt`
    mount -o nouuid,ro /dev/VolGroup00/lv-home-snap /mnt
Есть наши файлики!
    ll /mnt
<details>
<summary>Вывод ll /home</summary>
[root@lvm ~]# ll /mnt
total 364
-rw-r--r--. 1 root    root     1024 Jun 16 10:58 test.humster1
-rw-r--r--. 1 root    root    10240 Jun 16 10:58 test.humster10
-rw-r--r--. 1 root    root    11264 Jun 16 10:58 test.humster11
-rw-r--r--. 1 root    root    12288 Jun 16 10:58 test.humster12
-rw-r--r--. 1 root    root    13312 Jun 16 10:58 test.humster13
-rw-r--r--. 1 root    root    14336 Jun 16 10:58 test.humster14
-rw-r--r--. 1 root    root    15360 Jun 16 10:58 test.humster15
-rw-r--r--. 1 root    root    16384 Jun 16 10:58 test.humster16
-rw-r--r--. 1 root    root    17408 Jun 16 10:58 test.humster17
-rw-r--r--. 1 root    root    18432 Jun 16 10:58 test.humster18
-rw-r--r--. 1 root    root    19456 Jun 16 10:58 test.humster19
-rw-r--r--. 1 root    root     2048 Jun 16 10:58 test.humster2
-rw-r--r--. 1 root    root    20480 Jun 16 10:58 test.humster20
-rw-r--r--. 1 root    root    21504 Jun 16 10:58 test.humster21
-rw-r--r--. 1 root    root    22528 Jun 16 10:58 test.humster22
-rw-r--r--. 1 root    root    23552 Jun 16 10:58 test.humster23
-rw-r--r--. 1 root    root    24576 Jun 16 10:58 test.humster24
-rw-r--r--. 1 root    root    25600 Jun 16 10:58 test.humster25
-rw-r--r--. 1 root    root     3072 Jun 16 10:58 test.humster3
-rw-r--r--. 1 root    root     4096 Jun 16 10:58 test.humster4
-rw-r--r--. 1 root    root     5120 Jun 16 10:58 test.humster5
-rw-r--r--. 1 root    root     6144 Jun 16 10:58 test.humster6
-rw-r--r--. 1 root    root     7168 Jun 16 10:58 test.humster7
-rw-r--r--. 1 root    root     8192 Jun 16 10:58 test.humster8
-rw-r--r--. 1 root    root     9216 Jun 16 10:58 test.humster9
drwx------. 3 vagrant vagrant    95 Jun 16 10:42 vagrant
</details>
отправим срочно понадобившийся файл из только что удалённых нафиг
    cp -v /mnt/test.humster20 /tmp
и спокойно восстановим состояние хомяка на момент снапшота
    umount /mnt
    umount /home
    lvconvert --merge /dev/VolGroup00/lv-home-snap
    mount /dev/VolGroup00/lv-home /home


Пропишем монтирование новых разделов в fstab
    echo /dev/VolGroup00/lv-var /var ext4 defaults 0 0 >> /etc/fstab
    echo /dev/VolGroup00/lv-home /home xfs defaults 0 0 >> /etc/fstab

Перезагрузимся и убедимся, что всё работает, как задумано
    shutdown -r now

Залогинились в ВМ, проверяем
    mount | grep /dev/
> [root@lvm ~]#     mount | grep /dev/
> tmpfs on /dev/shm type tmpfs (rw,nosuid,nodev,seclabel)
> devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,seclabel,gid=5,mode=620,ptmxmode=000)
> /dev/mapper/VolGroup00-LogVol00 on / type xfs (rw,relatime,seclabel,attr2,inode64,noquota)
> mqueue on /dev/mqueue type mqueue (rw,relatime,seclabel)
> hugetlbfs on /dev/hugepages type hugetlbfs (rw,relatime,seclabel)
> /dev/mapper/VolGroup00-lv--var on /var type ext4 (rw,relatime,seclabel,data=ordered)
> /dev/sda2 on /boot type xfs (rw,relatime,seclabel,attr2,inode64,noquota)
> /dev/mapper/VolGroup00-lv--home on /home type xfs (rw,relatime,seclabel,attr2,inode64,noquota)

.....
#### The END
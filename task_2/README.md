## ДЗ - 2
### добавил в Vagrantfile дисковые устройства sata 5-8 согласно ДЗ
### собираем массив raid-10 из 6-ти дисков
mdadm --create --verbose /dev/md0 -l 10 -n 6 /dev/sd[b-g]
### добавим 2 диска hot-spare
mdadm /dev/md0 --add /dev/sd{h,i}
<details>
<summary>вывод cat /proc/mdstat</summary>
<p>
Personalities : [raid10] 
md0 : active raid10 sdi[7](S) sdh[6](S) sdg[5] sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      301056 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]
      
unused devices: <none>
</p>
</details>

### "сломаем" несколько дисков в массиве:
mdadm /dev/md0 --fail /dev/sd{e,f}
<details>
<summary>вывод mdadm -D /dev/md0 </summary>
<p>
/dev/md0:
           Version : 1.2
     Creation Time : Fri Aug 28 13:24:56 2020
        Raid Level : raid10
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 6
     Total Devices : 8
       Persistence : Superblock is persistent

       Update Time : Sun Aug 30 17:24:26 2020
             State : clean 
    Active Devices : 6
   Working Devices : 6
    Failed Devices : 2
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus-task-2:0  (local to host otus-task-2)
              UUID : c54a24d9:f9e7e6bb:6cdfaab3:471d649f
            Events : 54

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       7       8      128        3      active sync set-B   /dev/sdi
       6       8      112        4      active sync set-A   /dev/sdh
       5       8       96        5      active sync set-B   /dev/sdg

       3       8       64        -      faulty   /dev/sde
       4       8       80        -      faulty   /dev/sdf
</p>
</details>
mdadm /dev/md0 --fail /dev/sdd
<details>
<summary>вывод mdadm -D /dev/md0 </summary>
<p>
/dev/md0:
           Version : 1.2
     Creation Time : Fri Aug 28 13:24:56 2020
        Raid Level : raid10
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 6
     Total Devices : 8
       Persistence : Superblock is persistent

       Update Time : Sun Aug 30 17:24:43 2020
             State : clean, degraded 
    Active Devices : 5
   Working Devices : 5
    Failed Devices : 3
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus-task-2:0  (local to host otus-task-2)
              UUID : c54a24d9:f9e7e6bb:6cdfaab3:471d649f
            Events : 56

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       -       0        0        2      removed
       7       8      128        3      active sync set-B   /dev/sdi
       6       8      112        4      active sync set-A   /dev/sdh
       5       8       96        5      active sync set-B   /dev/sdg

       2       8       48        -      faulty   /dev/sdd
       3       8       64        -      faulty   /dev/sde
       4       8       80        -      faulty   /dev/sdf
</p>
</details>

### удалим "сломанные" диски из массива и добавим их обратно:
mdadm /dev/md0 --remove /dev/sd{d,e,f}
mdadm /dev/md0 --add /dev/sd{d,e,f}

<details>
<summary>массив снова жив и здоров</summary>
<p>
/dev/md0:
           Version : 1.2
     Creation Time : Fri Aug 28 13:24:56 2020
        Raid Level : raid10
        Array Size : 301056 (294.00 MiB 308.28 MB)
     Used Dev Size : 100352 (98.00 MiB 102.76 MB)
      Raid Devices : 6
     Total Devices : 8
       Persistence : Superblock is persistent

       Update Time : Sun Aug 30 17:29:23 2020
             State : clean 
    Active Devices : 6
   Working Devices : 8
    Failed Devices : 0
     Spare Devices : 2

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otus-task-2:0  (local to host otus-task-2)
              UUID : c54a24d9:f9e7e6bb:6cdfaab3:471d649f
            Events : 78

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
      10       8       80        2      active sync set-A   /dev/sdf
       7       8      128        3      active sync set-B   /dev/sdi
       6       8      112        4      active sync set-A   /dev/sdh
       5       8       96        5      active sync set-B   /dev/sdg

       8       8       48        -      spare   /dev/sdd
       9       8       64        -      spare   /dev/sde
</p>
</details>

### запишем информацию о массиве в mdadm.comf
mkdir /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --details --scan --verbose | awk '/ARRAY/{print}' >> /etc/mdadm/mdadm.conf
### сделаем пять разделов на массиве
parted --script /dev/md0 mklabel gpt\  mkpart primary 2048s 20%\  mkpart primary 20% 40%\ mkpart primary ext4 40% 60%\ mkpart primary ext4 60% 80%\ mkpart primary ext4 80% 100%
### на полученных разделах делаем ФС ext4
for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
### создадим директории для монтирования разделов с массива и примонтируем их
mkdir -p /megaraid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount /dev/md0p$i /megaraid/part$i; done
### пропишем эти разделы в fstab
for i in $(seq 1 5); do echo /dev/md0p$i /megaraid/part$i ext4 defaults 0 0 >> /etc/fstab; done

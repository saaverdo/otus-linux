#!/usr/bin/bash
yum install lvm2 -y
pvcreate /dev/{sdb,sdc}
vgcreate vg_backup /dev/{sdb,sdc}
lvcreate -l+100%FREE -m 1 -n lv_backup vg_backup
mkfs.xfs /dev/mapper/vg_backup-lv_backup
mkdir /var/backup
mount /dev/mapper/vg_backup-lv_backup /var/backup
echo /dev/mapper/vg_backup-lv_backup /var/backup xfs defaults 0 0 >> /etc/fstab



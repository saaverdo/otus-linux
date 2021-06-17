#!/bin/bash
mkdir -p /mnt/nfs
mount -t nfs 192.168.50.10:/var/nfs_share /mnt/nfs -o rw,nosuid,noauto,x-systemd.automount,noexec,vers=3,proto=udp,hard,intr 
echo '192.168.50.10:/var/nfs_share /mnt/nfs nfs rw,nosuid,noauto,x-systemd.automount,noexec,vers=3,proto=udp,hard,intr 0 0' >> /etc/fstab


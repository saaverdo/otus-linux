#!/bin/bash

yum install nfs-utils -y
cat << EOF >> /etc/nfs.conf
[nfsd]
 udp=y
 tcp=n
 vers3=y
 vers4=n
EOF
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --add-service=nfs3
firewall-cmd --add-service=rpc-bind
firewall-cmd --add-service=mountd
mkdir -p /var/nfs_share/upload
chmod o+rwx /var/nfs_share/upload
echo '/var/nfs_share 192.168.50.11(rw,root_squash,all_squash,sync,wdelay)' >> /etc/exports
systemctl start nfs
systemctl enable nfs


#!/usr/bin/bash
yum install epel-release -y
yum install borgbackup -y
useradd -m back_oper
chown -R back_oper:back_oper /var/backup/
mkdir ~back_oper/.ssh

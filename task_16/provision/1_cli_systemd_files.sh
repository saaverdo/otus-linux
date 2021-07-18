#!/usr/bin/bash
cp /vagrant/*.{service,timer} /etc/systemd/system/
cp /vagrant/*.sh /root/
chmod +x /root/borg-back.sh
echo "192.168.11.101 backup-server" >> /etc/hosts
systemctl daemon-reload
systemctl enable borg-back.timer
#systemctl start borg-back.timer


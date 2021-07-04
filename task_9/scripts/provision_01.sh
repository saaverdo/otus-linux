#!/bin/bash

# Provision 

# install log-generator files to their location
cp /vagrant/scripts/log-gen/log-gen /etc/sysconfig/
cp /vagrant/scripts/log-gen/*.{service,timer} /etc/systemd/system/
cp /vagrant/scripts/log-gen/*.py /usr/local/bin/
cp /vagrant/scripts/logmonitor.sh /usr/local/bin/
#cp /vagrant/scripts/mon/syslog.log /opt/
# make scripts executable again!
chmod +x /usr/local/bin/*
# enable and start services
systemctl daemon-reload
systemctl enable log-gen
systemctl start log-gen.service
systemctl start log-gen.timer
# ensure services started and not hungry
systemctl list-units | grep log-
#systemctl status log-gen
#systemctl status log-mon
# add our task in cron
echo "*/2 * * * * root /usr/local/bin/logmonitor.sh /vagrant/access.log" >> /etc/crontab


#!/bin/bash

# Provision of part I 

# copy files to their location
cp /vagrant/scripts/mon/log-{mon,gen} /etc/sysconfig/
cp /vagrant/scripts/mon/*.{service,timer} /etc/systemd/system/
cp /vagrant/scripts/mon/*.{sh,py} /usr/local/bin/
#cp /vagrant/scripts/mon/syslog.log /opt/
# make scripts executable again!
chmod +x /usr/local/bin/*
# enable and start services
systemctl daemon-reload
systemctl enable log-gen
systemctl enable log-mon
systemctl start log-gen
systemctl start log-mon
# ensure services started and not hungry
systemctl list-units | grep log-
#systemctl status log-gen
#systemctl status log-mon



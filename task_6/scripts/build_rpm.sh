#!/bin/bash
# sudo -i
# get nginx sources with srpm
pwd
sudo -u vagrant wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.1-1.el7.ngx.src.rpm
#wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.1-1.el7.ngx.src.rpm
sudo -u vagrant rpm -i nginx-1.20.1-1.el7.ngx.src.rpm
#pwd
#ls -l
# get openssl sources 
sudo -u vagrant wget https://www.openssl.org/source/latest.tar.gz
sudo -u vagrant tar -xf latest.tar.gz
#pwd
#ls -l
yum-builddep rpmbuild/SPECS/nginx.spec
# enable --with-openssl option
sudo -u vagrant sed -i "s#--with-debug#--with-openssl=/home/vagrant/openssl-1.1.1k#g" ${PWD}/rpmbuild/SPECS/nginx.spec
# build rpm
sudo -u vagrant rpmbuild -bb rpmbuild/SPECS/nginx.spec
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.20.1-1.el7.ngx.x86_64.rpm
systemctl start nginx
systemctl enable nginx
systemctl status nginx

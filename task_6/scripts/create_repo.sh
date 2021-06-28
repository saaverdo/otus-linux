#!/usr/bin/env bash

mkdir -p /usr/share/nginx/html/repo
cp rpmbuild/RPMS/x86_64/nginx-1.20.1-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/
wget https://downloads.percona.com/downloads/percona-release/percona-release-1.0-9/redhat/percona-release-1.0-9.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-9.noarch.rpm
createrepo /usr/share/nginx/html/repo/
# enable file listing in nginx config
sed -i '/index  index.html index.htm;/ a autoindex on;' /etc/nginx/conf.d/default.conf
# restart nginx
nginx -t && nginx -s reload
# create repo file
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linuz
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
# install package fron our new repo
yum install percona-release -y

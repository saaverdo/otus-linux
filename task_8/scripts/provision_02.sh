yum install spawn-fcgi php php-cli mod_fcgid httpd -y
sed -i 's/#SOCKET/SOCKET/' /etc/sysconfig/spawn-fcgi
sed -i 's/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi
cp /vagrant/scripts/fcgi/spawn-fcgi.service /etc/systemd/system/spawn-fcgi.service
systemctl daemon-reload
systemctl enable spawn-fcgi
systemctl start spawn-fcgi
systemctl status spawn-fcgi

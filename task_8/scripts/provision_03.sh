
# copy httpd@ unit
sudo cp /vagrant/scripts/httpd/httpd@.service /etc/systemd/system/
# cpoy httpd@ environment files
sudo cp /vagrant/scripts/httpd/httpd@80* /etc/sysconfig/

sudo systemctl disable httpd
# copy httpd instance configs and edit settings
sudo cp -a /etc/httpd /etc/httpd-8080
sudo sed -i 's#^ServerRoot "/etc/httpd"$#ServerRoot "/etc/httpd-8080"#g' /etc/httpd-8080/conf/httpd.conf
sudo sed -i 's#^Listen 80$#Listen 8080#g' /etc/httpd-8080/conf/httpd.conf
sudo cp -a /etc/httpd /etc/httpd-8081
#sudo sed -i 's#^ServerRoot "/etc/httpd"$#ServerRoot "/etc/httpd-8081"#g' /etc/httpd-8081/conf/httpd.conf
#sudo sed -i 's#^Listen 80$#Listen 8081#g' /etc/httpd-8081/conf/httpd.conf
sudo systemctl enable httpd@808{0,1}.service
sudo systemctl start httpd@808{0,1}.service

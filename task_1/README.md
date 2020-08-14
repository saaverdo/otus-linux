# *ДЗ 1*
### на ноутбук установлена ОС Ubuntu 20.04
### установка обновлений
sudo apt-get update && sudo apt-get -y upgrade
### установка необходимых программ
sudo apt-get install -y htop wget curl git vim

### установка virtualbox
```
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib"
sudo apt-get install virtualbox-6.1
sudo apt-get -f -y install
```
### автонастройка virtualbox
```
sudo /sbin/vboxconfig
```
### установка vagrant
```
wget https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.deb
sudo dpkg -i vagrant_2.2.9_x86_64.deb
```
### проверка имеющихся vbox-ов
```
vagrant box list
```
### становка packer
```
curl https://releases.hashicorp.com/packer/1.6.1/packer_1.6.1_linux_amd64.zip | gzip -d > /usr/local/bin/packer && chmod +x /usr/local/bim/packer
chmod +x /usr/local/bin/packer
```
### клонируем репозитарии
```
git clone git@github.com:saaverdo/manual_kernel_update.git
git clone git@github.com:saaverdo/otus-linux.git
```
## ветка 1 - сборка ядра из исходников

### Источник <https://www.vlent.nl/weblog/2014/12/19/how-to-create-a-custom-vagrant-box/>  
### Источник <http://blog.sedicomm.com/2018/10/30/kak-skompilirovat-yadro-linux-na-centos-7/>  
### Источник <https://www.cyberciti.biz/tips/compiling-linux-kernel-26.html>  
### запускаем ВМ для обновления ядра из manual-kernel-update:
```
cd manual_kernel_update/
vagrant up
```
### Установка пакетов, необходимых для сборки ядра: 
```
yum install -y ncurses-devel make gcc bc bison flex elfutils-libelf-devel openssl-devel grub2 wget
cd /usr/src 
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.8.tar.xz 
tar xvf linux-5.8.tar.xz 
cd linux-5.8 
```
### 
```
cp /boot/config-3.10.0-1127.el7.x86_64 .config 
make menuconfig 
```
### В пункте выбрал Device Drivers  -> Virtualization drivers  
### В нём стал доступен ->  Virtual Box Guest integration support 
### После этого стал доступен пункт File systems -> Miscellaneous filesystems -> VirtualBox guest shared folder (vboxsf) support 
sudo make
### тут - облом "your compiler is too old" 

### чукча лёгких путей не ищет
### Источник <https://linuxize.com/post/how-to-install-gcc-compiler-on-centos-7/>
```
sudo yum install centos-release-scl 
sudo yum install devtoolset-7 
scl enable devtoolset-7 bash 
```
### компилируем ядро
```
make 
make modules
make install && make modules_install

sudo grub2-mkconfig -o /boot/grub2/grub.cfg 
sudo grub2-set-default 0 
```
### перезагрузка, убедился, что ВМ работает с новым ядром
uname -sr
### удаляем старые ядра
```
sudo rm -f /boot/*3.10.0* 
sudo grub2-mkconfig -o /boot/grub2/grub.cfg 
sudo grub2-set-default 0
```
### Чистим место в ВМ - команды взяты из packer/scripts
sudo rm -rf /usr/src/linux-5.8*
### Установим vagrant default key
```
mkdir -pm 700 /home/vagrant/.ssh
curl -sL https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh
```
### Удалим временные файлы
```
rm -rf /tmp/*
rm  -f /var/log/wtmp /var/log/btmp
rm -rf /var/cache/* /usr/share/doc/*
rm -rf /var/cache/yum
rm -rf /vagrant/home/*.iso
rm  -f ~/.bash_history
history -c
rm -rf /run/log/journal/*
```
### zeroize empty space
```
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
sync
shutdown
```
### сделаем vagrant box из этой ВМ
```
vboxmanage list vms 
vagrant package --base "manual_kernel_update_kernel-update_1596975497540_59595" --output centos-7-kernel-5-8.box 
```
## ветка 2 - сборка packer'ом - выполнял по методичке
### т.к. Яндекс у нас недоступен, в centos.json изменил адрес зеркала с образом ОС и контрольную сумму:
      "iso_url": "http://mirrors.bytes.ua/centos/7.8.2003/isos/x86_64/CentOS-7-x86_64-Minimal-2003.iso",
      "iso_checksum": "sha256:659691c28a0e672558b003d223f83938f254b39875ee7559d1a4a14c79173193",

### выполняю packer fix
```
packer fix centos.json > centosfix.json
mv centosfix.json centos.json

packer build centos.json
```
### Итог - выгрузка образа в vagrant cloud
### публикуем полученный из ветки 1 box в vagrant cloud
```
vagrant cloud auth login 
vagrant cloud publish --release saaverdo/centos-7-5-8 1.0 virtualbox centos-7-kernel-5-8.box 
```
### публикуем полученный из ветки 2 box в vagrant cloud
```
vagrant cloud publish --release saaverdo/centos-7.7 1.0 virtualbox centos-7.7.2003-kernel-5-8-x86_64-Minimal.box 
```
### тестируем:
```
vagrant box add --name centos-7.7 centos-7.7.2003-kernel-5-8-x86_64-Minimal.box
vagrant init centos-7.7
vagrant ssh
uname -r
```


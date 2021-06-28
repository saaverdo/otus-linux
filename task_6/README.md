## ДЗ - 6

> 1) Создать свой RPM пакет  (можно взять свое приложение, либо собрать, например, апач с определенными опциями)  
> 2) Создать свой репозиторий и разместить там ранее собранный RPM  
>    Реализовать это все либо в Vagrant, либо развернуть у себя через NGINX и дать ссылку на репозиторий.    


### I Создать свой RPM пакет
Приступим.
Подготовим ВМ - установим необходимые для сборки `rpm` пакеты
    yum install -y redhat-lsb-core rpmdevtools rpm-build createrepo yum-utils tree

По примеру в методичке возьмём `NGINX` и соберём его с `openssl`
Скачаем `srpm` пакет `NGINX`
    wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.1-1.el7.ngx.src.rpm
И установим его
    rpm -i nginx-1.20.1-1.el7.ngx.src.rpm
При этом создалось дерево каталогов для сборки:
    tree rpmbuild
<details>
    <summary>вывод</summary>

> [vagrant@task6-rpm ~]$ tree rpmbuild/  
> rpmbuild/  
> ├── SOURCES  
> │   ├── logrotate  
> │   ├── nginx-1.20.1.tar.gz  
> │   ├── nginx.check-reload.sh  
> │   ├── nginx.conf  
> │   ├── nginx.copyright  
> │   ├── nginx-debug.service  
> │   ├── nginx.default.conf  
> │   ├── nginx.service  
> │   ├── nginx.suse.logrotate  
> │   └── nginx.upgrade.sh  
> └── SPECS  
>     └── nginx.spec  
>   
> 2 directories, 11 files  

</details>

Теперь скачаем `openssl` - он понадобится для сборки

    wget https://www.openssl.org/source/latest.tar.gz && tar -xvf latest.tar.gz

Установим необходимые зависимости 
    yum-builddep rpmbuild/SPECS/nginx.spec 

<details>
    <summary>вывод</summary>

> [vagrant@task6-rpm ~]$ sudo yum-builddep rpmbuild/SPECS/nginx.spec   
> Failed to set locale, defaulting to C  
> Loaded plugins: fastestmirror  
> Enabling base-source repository  
> Enabling centos-sclo-rh-source repository  
> Enabling centos-sclo-sclo-source repository  
> Enabling extras-source repository  
> Enabling updates-source repository  
> Loading mirror speeds from cached hostfile  
>  * base: mirror.vsys.host  
>  * centos-sclo-rh: mirror.vsys.host  
>  * centos-sclo-sclo: mirror.vsys.host  
>  * extras: mirror.vsys.host  
>  * updates: mirror.vsys.host  
> base-source                                                                                                                                                                         | 2.9 > kB  00:00:00       
> centos-sclo-rh-source                                                                                                                                                               | 3.0 > kB  00:00:00       
> centos-sclo-sclo-source                                                                                                                                                             | 3.0 > kB  00:00:00       
> extras-source                                                                                                                                                                       | 2.9 > kB  00:00:00       
> updates-source                                                                                                                                                                      | 2.9 > kB  00:00:00       
> (1/5): centos-sclo-sclo-source/primary_db                                                                                                                                           | 126 > kB  00:00:01       
> (2/5): extras-source/7/primary_db                                                                                                                                                   |  30 > kB  00:00:02       
> (3/5): base-source/7/primary_db                                                                                                                                                     | 974 > kB  00:00:03       
> (4/5): centos-sclo-rh-source/primary_db                                                                                                                                             | 948 > kB  00:00:06       
> (5/5): updates-source/7/primary_db                                                                                                                                                  | 151 > kB  00:00:06       
> Checking for new repos for mirrors  
> Getting requirements for rpmbuild/SPECS/nginx.spec  
>  --> Already installed : systemd-219-73.el7_8.9.x86_64  
>  --> Already installed : 1:openssl-devel-1.0.2k-19.el7.x86_64  
>  --> Already installed : zlib-devel-1.2.7-18.el7.x86_64  
>  --> Already installed : pcre-devel-8.32-17.el7.x86_64  
> No uninstalled build requires  

</details>

Исправим `spec` файл - добавим нужные опции
    sed -i "s#--with-debug#--with-openssl=/root/openssl-1.1.1k#g" rpmbuild/SPECS/nginx.spec

Соберём rpm пакет

rpmbuild -bb 

Смотрим, что же у нас получилось

    rpmbuild -bb rpmbuild/SPECS/nginx.spec
    ll rpmbuild/RPMS/x86_64/

> [root@task6-rpm ~]# ll rpmbuild/RPMS/x86_64/  
> total 3908  
> -rw-r--r--. 1 root root 2037608 Jun 27 22:02 nginx-1.20.1-1.el7.ngx.x86_64.rpm  
> -rw-r--r--. 1 root root 1960400 Jun 27 22:02 nginx-debuginfo-1.20.1-1.el7.ngx.x86_64.rpm  

Теперь установим собранный пакет

    yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.20.1-1.el7.ngx.x86_64.rpm

И убедимся, что всё работает

    systemctl start nginx
    systemctl status nginx

> [root@task6-rpm ~]# systemctl status nginx/  
> ● nginx.service - nginx - high performance web server/  
>    Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)/  
>    Active: active (running) since Sun 2021-06-27 22:07:23 UTC; 10s ago/  
>      Docs: http://nginx.org/en/docs//  
>   Process: 2443 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)/  
>  Main PID: 2444 (nginx)/  
>    CGroup: /system.slice/nginx.service/  
>            ├─2444 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf/  
>            ├─2445 nginx: worker process/  
>            ├─2446 nginx: worker process/  
>            ├─2447 nginx: worker process/  
>            └─2448 nginx: worker process/  
>   
> Jun 27 22:07:23 task6-rpm systemd[1]: Starting nginx - high performance web server...  
> Jun 27 22:07:23 task6-rpm systemd[1]: Started nginx - high performance web server.  

Кррасота...

### II Создать свой репозиторий и разместить там ранее собранный RPM

Создадим каталог `repo` в директории `/usr/share/nginx/html` (директория для статики `nginx` по-умолчанию)

    mkdir /usr/share/nginx/html/repo

Скопируем туда свежесобранный `rpm` `NGINX` 
    
    cp rpmbuild/RPMS/x86_64/nginx-1.20.1-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/

и для массовки добавим `percona server`

    wget https://downloads.percona.com/downloads/percona-release/percona-release-1.0-9/redhat/percona-release-1.0-9.noarch.rpm \
-O /usr/share/nginx/html/repo/percona-release-0.1-9.noarch.rpm

И инициализируем репозиторий

    createrepo /usr/share/nginx/html/repo/ 


> [root@task6-rpm ~]# createrepo /usr/share/nginx/html/repo/  
> Spawning worker 0 with 1 pkgs  
> Spawning worker 1 with 1 pkgs  
> Spawning worker 2 with 0 pkgs  
> Spawning worker 3 with 0 pkgs  
> Workers Finished  
> Saving Primary metadata  
> Saving file lists metadata  
> Saving other metadata  
> Generating sqlite DBs  
> Sqlite DBs complete  

Посмотрим, что в новоиспечённом репозитории

    tree /usr/share/nginx/html/repo/

<detail>
<summary>вывод</summary>

> [root@task6-rpm ~]# tree /usr/share/nginx/html/repo/  
> /usr/share/nginx/html/repo/  
> ├── nginx-1.20.1-1.el7.ngx.x86_64.rpm  
> ├── percona-release-0.1-9.noarch.rpm  
> └── repodata  
>     ├── 1ab26a59ffcfc8d4e0f663a4a7c247d74408cb08e8ec67afba32f42498b05865-other.sqlite.bz2  
>     ├── 348fca4c6aea72929ba2c47474dc0e73c94c1c756890d544d796249b28d6f869-primary.sqlite.bz2  
>     ├── 57ab979f53a1603b5ca2e896484501668a5dbf5e4195865e34603d6842db4218-other.xml.gz  
>     ├── 7c1720f860e866100bc2c78319622fbed2e0ebed233664b2dc0b259d8ebc2f8d-primary.xml.gz  
>     ├── 8479b1937f8e4a80f408b7a9344dc55e184353c4c71be17b8b1c56bc8bf75861-filelists.sqlite.bz2  
>     ├── dcba458b293c396995ef314e41cdcccfbb1442cdea46674a8188169d97fadbd5-filelists.xml.gz  
>     └── repomd.xml  
>   
> 1 directory, 9 files  

</detail>

Но мы хотим уыидеть наш репо в браузере.
Поэтому добавим в `location /` в файле `/etc/nginx/conf.d/default.conf` директиву `autoindex on`
    
    sudo sed -i '/index  index.html index.htm;/ a autoindex on;' /etc/nginx/conf.d/default.conf

Применяем изменения:

    nginx -t && nginx -s reload

И проверяем:

    curl -a http://localhost/repo/

> [vagrant@task6-rpm ~]$ curl -a http://localhost/repo/  
> <html>  
> <head><title>Index of /repo/</title></head>  
> <body>  
> <h1>Index of /repo/</h1><hr><pre><a href="../">../</a>  
> <a href="repodata/">repodata/</a>                                          28-Jun-2021 07:24                   -  
> <a href="nginx-1.20.1-1.el7.ngx.x86_64.rpm">nginx-1.20.1-1.el7.ngx.x86_64.rpm</a>                  28-Jun-2021 07:24             2037228  
> <a href="percona-release-0.1-9.noarch.rpm">percona-release-0.1-9.noarch.rpm</a>                   11-Nov-2020 21:49               16664  
> </pre><hr></body>  
> </html>  


Добавим репозиторий в `/etc/yum.repos.d`

    cat >> /etc/yum.repos.d/otus.repo << EOF
    [otus]
    name=otus-linuz
    baseurl=http://localhost/repo
    gpgcheck=0
    enabled=1
    EOF

И `yum` видит его:

    yum repolist enabled | grep otus

> [root@task6-rpm ~]# yum repolist enabled | grep otus  
> Failed to set locale, defaulting to C  
> otus                                  otus-linuz                              2  

А теперь установим `percona` из нашего репозитория

    yum install percona-release -y

<detail>
    <summary>лог установки</summary>
<p>

[root@task6-rpm ~]# yum install percona-release -y
Failed to set locale, defaulting to C
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: mirror.vsys.host
 * centos-sclo-rh: mirror.vsys.host
 * centos-sclo-sclo: mirror.vsys.host
 * extras: mirror.vsys.host
 * updates: mirror.vsys.host
Resolving Dependencies
--> Running transaction check
---> Package percona-release.noarch 0:1.0-9 will be installed
--> Finished Dependency Resolution

Dependencies Resolved

=====================================================================================================================
 Package                            Arch                      Version                  Repository               Size
=====================================================================================================================
Installing:
 percona-release                    noarch                    1.0-9                    otus                     16 k

Transaction Summary
=====================================================================================================================
Install  1 Package

Total download size: 16 k
Installed size: 18 k
Downloading packages:
percona-release-0.1-9.noarch.rpm                                                              |  16 kB  00:00:00     
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : percona-release-1.0-9.noarch                                                                      1/1 
* Enabling the Percona Original repository
<*> All done!
The percona-release package now contains a percona-release script that can enable additional repositories for our newer products.

For example, to enable the Percona Server 8.0 repository use:

  percona-release setup ps80

Note: To avoid conflicts with older product versions, the percona-release setup command may disable our original repository for some products.

For more information, please visit:
  https://www.percona.com/doc/percona-repo-config/percona-release.html

  Verifying  : percona-release-1.0-9.noarch                                                                      1/1 

Installed:
  percona-release.noarch 0:1.0-9                                                                                     

Complete!

</p>
</detail>



#### The end)

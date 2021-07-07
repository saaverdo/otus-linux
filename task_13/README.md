## ДЗ - 13   Практика с SELinux

    Запустить nginx на нестандартном порту 3-мя разными способами:

    переключатели setsebool;
    добавление нестандартного порта в имеющийся тип;
    формирование и установка модуля SELinux. 
    К сдаче:
    README с описанием каждого решения (скриншоты и демонстрация приветствуются).

    Обеспечить работоспособность приложения при включенном selinux.

    Развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems
    Выяснить причину неработоспособности механизма обновления зоны (см. README);
    Предложить решение (или решения) для данной проблемы;
    Выбрать одно из решений для реализации, предварительно обосновав выбор;
    Реализовать выбранное решение и продемонстрировать его работоспособность. К сдаче:
    README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них;
    Исправленный стенд или демонстрация работоспособной системы скриншотами и описанием.


### Задание I

#### часть 0
#### преамбула

https://linux-notes.org/nastrojka-selinux-dlya-apache-nginx-v-unix-linux/
https://www.nginx.com/blog/using-nginx-plus-with-selinux/

Развернём стенд командой 
    
    vagrant up

Теперь можем запустить `ansible` роль `nginx` которая установит нам NGINX 

    ansible-playbook playbooks/deploy.yml

В результате `nginx` будет установлен и настроен на работу на порту `8086` (Intel(тм) одобряэ!)
Осталось только перезапустить сервис. Сейчас он работает и подмигивает зелёным глазом.

> [root@task-13-selinux ~]# systemctl status nginx  
> ● nginx.service - The nginx HTTP and reverse proxy server  
>    Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)  
>    Active: active (running) since Wed 2021-07-07 20:36:24 UTC; 11min ago  
>   Process: 2962 ExecReload=/usr/sbin/nginx -s reload (code=exited, status=0/SUCCESS)  
>   Process: 1060 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)  
>   Process: 1057 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)  
>   Process: 1055 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)  
>  Main PID: 1061 (nginx)  
>    CGroup: /system.slice/nginx.service  
>            ├─1061 nginx: master process /usr/sbin/nginx  
>            └─1153 nginx: worker process  

Перезапускаем его:

    systemctl restart nginx

> [root@task-13-selinux ~]# systemctl restart nginx  
> Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.  

Что-то пошло не так. Не хватило маны?

> [root@task-13-selinux ~]# systemctl status nginx  
> ● nginx.service - The nginx HTTP and reverse proxy server  
>    Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)  
>    Active: failed (Result: exit-code) since Wed 2021-07-07 20:48:26 UTC; 47s ago  
>   Process: 2962 ExecReload=/usr/sbin/nginx -s reload (code=exited, status=0/SUCCESS)  
>   Process: 1060 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)  
>   Process: 3055 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=1/FAILURE)  
>   Process: 3054 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)  
>  Main PID: 1061 (code=exited, status=0/SUCCESS)  
>   
> Jul 07 20:48:26 task-13-selinux systemd[1]: Stopped The nginx HTTP and reverse proxy server.  
> Jul 07 20:48:26 task-13-selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...  
> Jul 07 20:48:26 task-13-selinux nginx[3055]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok  
> Jul 07 20:48:26 task-13-selinux nginx[3055]: nginx: [emerg] bind() to 0.0.0.0:8086 failed (13: Permission denied)  
> Jul 07 20:48:26 task-13-selinux nginx[3055]: nginx: configuration file /etc/nginx/nginx.conf test failed  
> Jul 07 20:48:26 task-13-selinux systemd[1]: nginx.service: control process exited, code=exited status=1  
> Jul 07 20:48:26 task-13-selinux systemd[1]: Failed to start The nginx HTTP and reverse proxy server.  
> Jul 07 20:48:26 task-13-selinux systemd[1]: Unit nginx.service entered failed state.  
> Jul 07 20:48:26 task-13-selinux systemd[1]: nginx.service failed.  

Есть одно подозрение...

    sestatus

> [root@task-13-selinux ~]# sestatus  
> SELinux status:                 enabled  
> SELinuxfs mount:                /sys/fs/selinux  
> SELinux root directory:         /etc/selinux  
> Loaded policy name:             targeted  
> Current mode:                   enforcing  
> Mode from config file:          enforcing  
> Policy MLS status:              enabled  
> Policy deny_unknown status:     allowed  
> Max kernel policy version:      33  

И 100%-е подтверждение

    audit2why < /var/log/audit/audit.log

<details>
<summary>что audit2why нам глаголет:</summary>

```
[root@task-13-selinux ~]# audit2why < /var/log/audit/audit.log 
type=AVC msg=audit(1625690831.001:1992): avc:  denied  { name_bind } for  pid=1061 comm="nginx" src=8086 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

	Was caused by:
	The boolean nis_enabled was set incorrectly. 
	Description:
	Allow nis to enabled

	Allow access by executing:
	# setsebool -P nis_enabled 1
type=AVC msg=audit(1625690906.581:2036): avc:  denied  { name_bind } for  pid=3055 comm="nginx" src=8086 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

	Was caused by:
	The boolean nis_enabled was set incorrectly. 
	Description:
	Allow nis to enabled

	Allow access by executing:
	# setsebool -P nis_enabled 1

```

</details>


Знакомьтесь, ~~Джо Блек~~ SELinux.
Да, его можно отправить с грустным видом считать нарушения но не мешать работать,
однако, понижать градус - это не наш метод!

#### Амбула

В ругани из `audit.log` мы заметили нецензурное `unreserved_port_t`, смело предположим, что сей порт не в списке ~~пригла~~разрешённых.

    semanage port -l | grep 8086

А в ответ - пустота. Что и требовалось доказать.
Исправим это недоразумение, вписав наш порт... не будем торопиться.
И поручим допрос `audit.log` товарищу `sealert`.

    sealert -a /var/log/audit/audit.log

<details>
<summary>результат допроса audit.log и дальнейшие рекомендации. с ув. тов. sealert</summary>

```
[root@task-13-selinux ~]# sealert -a /var/log/audit/audit.log
100% done
found 1 alerts in /var/log/audit/audit.log
--------------------------------------------------------------------------------

SELinux is preventing nginx from name_bind access on the tcp_socket port 8086.

*****  Plugin bind_ports (92.2 confidence) suggests   ************************

If you want to allow nginx to bind to network port 8086
Then you need to modify the port type.
Do
# semanage port -a -t PORT_TYPE -p tcp 8086
    where PORT_TYPE is one of the following: http_cache_port_t, http_port_t, jboss_management_port_t, jboss_messaging_port_t, ntop_port_t, puppet_port_t.

*****  Plugin catchall_boolean (7.83 confidence) suggests   ******************

If you want to allow nis to enabled
Then you must tell SELinux about this by enabling the 'nis_enabled' boolean.

Do
setsebool -P nis_enabled 1

*****  Plugin catchall (1.41 confidence) suggests   **************************

If you believe that nginx should be allowed name_bind access on the port 8086 tcp_socket by default.
Then you should report this as a bug.
You can generate a local policy module to allow this access.
Do
allow this access for now by executing:
# ausearch -c 'nginx' --raw | audit2allow -M my-nginx
# semodule -i my-nginx.pp


Additional Information:
Source Context                system_u:system_r:httpd_t:s0
Target Context                system_u:object_r:unreserved_port_t:s0
Target Objects                port 8086 [ tcp_socket ]
Source                        nginx
Source Path                   nginx
Port                          8086
Host                          <Unknown>
Source RPM Packages           
Target RPM Packages           
Policy RPM                    selinux-policy-3.13.1-266.el7_8.1.noarch
Selinux Enabled               True
Policy Type                   targeted
Enforcing Mode                Enforcing
Host Name                     task-13-selinux
Platform                      Linux task-13-selinux 5.8.01 #1 SMP Wed Aug 12
                              21:26:08 UTC 2020 x86_64 x86_64
Alert Count                   3
First Seen                    2021-07-07 20:47:11 UTC
Last Seen                     2021-07-07 21:27:24 UTC
Local ID                      5228fd40-b115-45bf-93c0-b3475cd7e8d9

Raw Audit Messages
type=AVC msg=audit(1625693244.290:2053): avc:  denied  { name_bind } for  pid=3146 comm="nginx" src=8086 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0


Hash: nginx,httpd_t,unreserved_port_t,tcp_socket,name_bind

```

</details>


Итого нам предлагают тра варианта действий:
I - разрешить `nginx` работать на порту `8086` командой `semanage`
II - включить `nis_enabled` командой `setsebool`
III - собрать модуль с политикой, разрешающей работу `nginx` работать на порту `8086`

#### вариант ~~единорога~~ I
#### semanage port...

Кроме команды нам любезно предложили варианты, куда можно прописать наш порт:

> where PORT_TYPE is one of the following: http_cache_port_t, http_port_t, jboss_management_port_t, jboss_messaging_port_t, ntop_port_t, puppet_port_t.  

О, `http_port_t` определённо мне нравится, он прямо просится к нашему `httpd_t`. 
Пропишемся в эту компанию и избежим косых взглядов ~~цербера~~ SELinux'а

    semanage port -a -t http_port_t -p tcp 8086

Немножко задумаемся... и запустим `nginx`

    systemctl start nginx
    systemctl status nginx

> [root@task-13-selinux ~]# systemctl status nginx  
> ● nginx.service - The nginx HTTP and reverse proxy server  
>    Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)  
>    Active: active (running) since Wed 2021-07-07 21:22:35 UTC; 6s ago  
>   Process: 2962 ExecReload=/usr/sbin/nginx -s reload (code=exited, status=0/SUCCESS)  
>   Process: 3120 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)  
>   Process: 3118 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)  
>   Process: 3116 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)  
>  Main PID: 3121 (nginx)  
>    CGroup: /system.slice/nginx.service  
>            ├─3121 nginx: master process /usr/sbin/nginx  
>            └─3122 nginx: worker process  
>   
> Jul 07 21:22:35 task-13-selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...  
> Jul 07 21:22:35 task-13-selinux nginx[3118]: nginx: the configuration file /etc/nginx/nginx.conf sy... ok  
> Jul 07 21:22:35 task-13-selinux nginx[3118]: nginx: configuration file /etc/nginx/nginx.conf test i...ful  
> Jul 07 21:22:35 task-13-selinux systemd[1]: Started The nginx HTTP and reverse proxy server.  

Ура, работает!

Вернёмся на исходную с помощью следующего колдунства:

    semanage port -d -t http_port_t -p tcp 8086
    systemctl restart nginx

> [root@task-13-selinux ~]# systemctl restart nginx  
> Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.  

#### вариант II
#### setsebool 1
На этот раз обратимся к заклинанию

    setsebool -P nis_enabled 1

Оно весьма быстро, не требует много маны и гарантирует результат:

    systemctl start nginx
    systemctl status nginx

> [root@task-13-selinux ~]# systemctl status nginx/  
> ● nginx.service - The nginx HTTP and reverse proxy server/  
>    Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)/  
>    Active: active (running) since Wed 2021-07-07 21:51:58 UTC; 2s ago/  
>   Process: 3893 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)/  
>   Process: 3890 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)/  
>   Process: 3888 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)/  
>  Main PID: 3894 (nginx)/  
>    CGroup: /system.slice/nginx.service/  
>            ├─3894 nginx: master process /usr/sbin/nginx/  
>            └─3895 nginx: worker process/  
> /  
> Jul 07 21:51:58 task-13-selinux systemd[1]: Starting The nginx HTTP and reverse proxy server.../  
> Jul 07 21:51:58 task-13-selinux nginx[3890]: nginx: the configuration file /etc/nginx/nginx.conf sy... ok/  
> Jul 07 21:51:58 task-13-selinux nginx[3890]: nginx: configuration file /etc/nginx/nginx.conf test i...ful/  
> Jul 07 21:51:58 task-13-selinux systemd[1]: Started The nginx HTTP and reverse proxy server./  

NGINX зыркает зелёным глазом в статусе, работает на порту 8086 и весело машет хвостом.

И снова вернёмся на исходную:

    setsebool -P nis_enabled 0
    systemctl restart nginx

> [root@task-13-selinux ~]# systemctl restart nginx  
> Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details. 

#### вариант III

Строго следуем полученным ~~под пытками~~ в результате анализа `audit.log` инструкциям:

    ausearch -c 'nginx' --raw | audit2allow -M my-nginx

> [root@task-13-selinux ~]# ausearch -c 'nginx' --raw | audit2allow -M my-nginx  
> ******************** IMPORTANT ***********************  
> To make this policy package active, execute:  
>   
> semodule -i my-nginx.pp  

    semodule -i my-nginx.pp
    systemctl start nginx
    systemctl status nginx

И наш NGINX вновь слушает ~~эфир~~ сеть на `8086` порту.


### Задание II

Запустим стенд и проверим работу с клиента:

    vagrant ssh client

    dig @192.168.50.10 ns01.dns.lab

[vagrant@client ~]$ dig @192.168.50.10 ns01.dns.lab

```
; <<>> DiG 9.11.4-P2-RedHat-9.11.4-26.P2.el7_9.5 <<>> @192.168.50.10 ns01.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 13148
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;ns01.dns.lab.			IN	A

;; ANSWER SECTION:
ns01.dns.lab.		3600	IN	A	192.168.50.10

;; AUTHORITY SECTION:
dns.lab.		3600	IN	NS	ns01.dns.lab.

;; Query time: 17 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Wed Jul 07 22:17:13 UTC 2021
;; MSG SIZE  rcvd: 71
```

Ок, теперь повторим попытку изменить зону:

```
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> 
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
```

Ошибка воспроизводится. Чтож, согласимся с инженером, передавшем нам задачу и пойдём на сервер `ns01`

    vagrant ssh ns01

Попросим товарища ~~майора~~ `sealert` провести анализ улик

<details>
<summary>результат анализа audit.log и дальнейшие рекомендации (экстерминатус). с ув. тов. sealert</summary>

```
[root@ns01 ~]#  sealert -a /var/log/audit/audit.log
100% done
found 1 alerts in /var/log/audit/audit.log
--------------------------------------------------------------------------------

SELinux is preventing /usr/sbin/named from create access on the file named.ddns.lab.view1.jnl.

*****  Plugin catchall_labels (83.8 confidence) suggests   *******************

If you want to allow named to have create access on the named.ddns.lab.view1.jnl file
Then you need to change the label on named.ddns.lab.view1.jnl
Do
# semanage fcontext -a -t FILE_TYPE 'named.ddns.lab.view1.jnl'
where FILE_TYPE is one of the following: dnssec_trigger_var_run_t, ipa_var_lib_t, krb5_host_rcache_t, krb5_keytab_t, named_cache_t, named_log_t, named_tmp_t, named_var_run_t, named_zone_t.
Then execute:
restorecon -v 'named.ddns.lab.view1.jnl'


*****  Plugin catchall (17.1 confidence) suggests   **************************

If you believe that named should be allowed create access on the named.ddns.lab.view1.jnl file by default.
Then you should report this as a bug.
You can generate a local policy module to allow this access.
Do
allow this access for now by executing:
# ausearch -c 'isc-worker0000' --raw | audit2allow -M my-iscworker0000
# semodule -i my-iscworker0000.pp


Additional Information:
Source Context                system_u:system_r:named_t:s0
Target Context                system_u:object_r:etc_t:s0
Target Objects                named.ddns.lab.view1.jnl [ file ]
Source                        isc-worker0000
Source Path                   /usr/sbin/named
Port                          <Unknown>
Host                          <Unknown>
Source RPM Packages           bind-9.11.4-26.P2.el7_9.5.x86_64
Target RPM Packages           
Policy RPM                    selinux-policy-3.13.1-266.el7.noarch
Selinux Enabled               True
Policy Type                   targeted
Enforcing Mode                Enforcing
Host Name                     ns01
Platform                      Linux ns01 3.10.0-1127.el7.x86_64 #1 SMP Tue Mar
                              31 23:36:51 UTC 2020 x86_64 x86_64
Alert Count                   1
First Seen                    2021-07-07 22:16:56 UTC
Last Seen                     2021-07-07 22:16:56 UTC
Local ID                      3d8ad331-cd8c-46dd-8093-3fabb5fcab32

Raw Audit Messages
type=AVC msg=audit(1625696216.773:1937): avc:  denied  { create } for  pid=5104 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0


type=SYSCALL msg=audit(1625696216.773:1937): arch=x86_64 syscall=open success=no exit=EACCES a0=7fe97d4f7050 a1=241 a2=1b6 a3=24 items=0 ppid=1 pid=5104 auid=4294967295 uid=25 gid=25 euid=25 suid=25 fsuid=25 egid=25 sgid=25 fsgid=25 tty=(none) ses=4294967295 comm=isc-worker0000 exe=/usr/sbin/named subj=system_u:system_r:named_t:s0 key=(null)

Hash: isc-worker0000,named_t,etc_t,file,create

```

</details>

Что же мы имеем? 
SELinux блокирует доступ к файлу `named.ddns.lab.view1.jnl` программе `/usr/sbin/named`
И предлагает два варианта решения: 
- собрать модуль с политикой, разрешающей работу 
- изменить контекст для файла `named.ddns.lab.view1.jnl` c помощью `semanage`

Выберем второй вариант. У него уже область действия и `/usr/sbin/named` не будут даны излишние полномочия.
Посмотрим, где же лежит зона `ddns.lab`, которую мы не можем обновиить

    /etc/named.conf | grep ddns.lab

> [root@ns01 ~]# cat /etc/named.conf | grep ddns.lab  
>     zone "ddns.lab" {  
>         file "/etc/named/dynamic/named.ddns.lab.view1";  
>     zone "ddns.lab" {  
>         file "/etc/named/dynamic/named.ddns.lab";  

Посмотрим на его контекст безопасности:

    ls -Z /etc/named/dynamic/named.ddns.lab.view1

> [root@ns01 ~]# ls -Z /etc/named/dynamic/named.ddns.lab.view1  
> -rw-rw----. named named system_u:object_r:etc_t:s0       /etc/named/dynamic/named.ddns.lab.view1  

Но по-умолчанию динамические зоны лежат в `ls -Z /var/named/dynamic/`
Глянем, какой же там контекст у файлов:

    ls -Z /var/named/dynamic/

> [root@ns01 ~]# ls -Z /var/named/dynamic/  
> -rw-r--r--. named named system_u:object_r:named_cache_t:s0 default.mkeys  
> -rw-r--r--. named named system_u:object_r:named_cache_t:s0 default.mkeys.jnl  
> -rw-r--r--. named named system_u:object_r:named_cache_t:s0 view1.mkeys  
> -rw-r--r--. named named system_u:object_r:named_cache_t:s0 view1.mkeys.jnl  

На лицо несовпадение - `/etc/named/dynamic/named.ddns.lab.view1` имеет контекст `etc_t`,   а файлы в `/var/named/dynamic/` - `named_cache_t`
Его-то мы и выставим для `/etc/named/dynamic/`
    
    semanage fcontext -a -t named_cache_t '/etc/named/dynamic(/.*)?'
    restorecon -R -v /etc/named/dynamic/

> restorecon reset /etc/named/dynamic context unconfined_u:object_r:etc_t:s0->unconfined_u:object_r:named_cache_t:s0  
> restorecon reset /etc/named/dynamic/named.ddns.lab context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0  
> restorecon reset /etc/named/dynamic/named.ddns.lab.view1 context system_u:object_r:etc_t:s0->system_u:object_r:named_cache_t:s0  

Теперь попробуем снова обновить зону с клиента:

```
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
```

проверим:

```
[vagrant@client ~]$ nslookup www.ddns.lab
Server:		192.168.50.10
Address:	192.168.50.10#53

Name:	www.ddns.lab
Address: 192.168.50.15
```

Готово!


#### The end)

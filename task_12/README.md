## ДЗ - 12   PAM

> Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников  
>   
> Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис  

#### часть I  Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников

Установим ansible в виртуальном окружении python

```
python3 -m venv .venv
source .venv/bin/activate
pip install ansible
```


##### Важно!
Также нам понадобится модуль `community.general.pamd`, для этого установим пакет `community.general`

    ansible-galaxy collection install community.general

Теперь можно разворачивать окружение `vagrant`

    vagrant up

Разумеется, `ansible` задеплоит всё согласно рли, но мы пройдёмся по шагам.


Приступим.
Заведём двух пользователей ~~в лес~~ для ограничения иx прав ~~и прочих издевательств~~

”usr_monk” - обычный юзер
“usr_bishop” - ~~паладин 80го уровня~~админ

    sudo useradd usr_monk && sudo useradd usr_bishop

Юзеры нарисовались, надо раздать им ~~пороли~~ пароли (пороть их ещё не за что)

    echo "iDKFA" | sudo passwd --stdin usr_monk && echo "iDDQD" | sudo passwd --stdin usr_bishop

> Changing password for user usr_monk.  
> passwd: all authentication tokens updated successfully.  
> Changing password for user usr_bishop.  
> passwd: all authentication tokens updated successfully.

Также сделаем группу `admin` - по завету условия задания.

    groupadd admin

И добавим в неё пользователя `usr_bishop` дабы чувствовал он себя привилегированным.
А также нашего `vagrant` - дабы конфуз не случился.

    gpasswd -M usr_bishop,vagrant admin

Для пущей уверенности, что нечистая не помешает работать на стенде через ssh, выполним следующее заклинание:

    sudo bash -c "sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl restart sshd.service"

Для настройки ~~дней молебнов~~ доступа пользователей с учётом времени воспользуемся модулем `pam_exec` что позволит запустить 
скрипт при подключении пользователя. Приведём файл `/etc/pam.d/sshd` в должный вид:

```
[root@task-12-pam ~]# cat /etc/pam.d/sshd 
#%PAM-1.0
auth	   required	pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin
# Used with polkit to reauthorize users in remote sessions
-auth      optional     pam_reauthorize.so prepare
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/ssh_login.sh
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      password-auth
session    include      postlogin
# Used with polkit to reauthorize users in remote sessions
-session   optional     pam_reauthorize.so prepare
```

А для того, чтобы юзер, одержимый рабочим зудом, не прибежал в ДЦ и не начал 
изливать своё вдохновение в консоль сервера на выходных, когда некому его гонять оттуда,
аналогичным образом доработаем файл `/etc/pam.d/login`

```
[root@task-12-pam ~]# cat /etc/pam.d/login
#%PAM-1.0
auth [user_unknown=ignore success=ok ignore=ignore default=bad] pam_securetty.so
auth       substack     system-auth
auth       include      postlogin
account    required     pam_nologin.so
account    required     pam_exec.so /usr/local/bin/ssh_login.sh
account    include      system-auth
password   include      system-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_console.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    include      postlogin
-session   optional     pam_ck_connector.so
```

Файл `/usr/local/bin/ssh_login.sh` по замыслу выглядит так:

'''
[root@task-12-pam ~]# cat /usr/local/bin/ssh_login.sh
#!/bin/bash

group=$(groups $PAM_USER | grep -c admin)
uday=$(date +%u)

if [[ $group -eq 1 || $uday -gt 5 ]]; then
   exit 0
  else
   exit 1
fi
'''

Проверяем вход

> [root@task-12-pam ~]# ssh usr_monk@127.0.0.1  
> usr_monk@127.0.0.1's password:   
> /usr/local/bin/ssh_login.sh failed: exit code 1  
> Authentication failed.  
> [root@task-12-pam ~]# ssh usr_bishop@127.0.0.1  
> usr_bishop@127.0.0.1's password:   
> [usr_bishop@task-12-pam ~]$   

Как видим, обычного `usr_monk` в это время не пускает на хост, 
а вот `usr_bishop` - может работать и по выходным, "Нет препятствий патриотам!" (с) ДМБ

Естественно, всё это мы завернём в `ansible`-роль `pam`

Данные пользователей занесём в словарь `pam_users`,а для создания пользователей воспользуемся модулем `users`
Пароли просто так задать нельзя, поэтому приготовим по рецепту из `https://stackoverflow.com/questions/19292899/creating-a-new-user-and-password-with-ansible`
командой:

    python -c 'import crypt; print crypt.crypt("iDKFA", "$1$KneeDeep$")'

Я не понял, как добавить пользователей и завести из в группы в одной таске (при условии, что у части пользователей указан пароль, а часть уже существует и им пароль не нужен) поэтому сделал две.

Для изменения настроек `pam` в файлах `/etc/pam.d/sshd` и `/etc/pam.d/login` будем использовать модуль `community.general.pamd`, установленный ранее.

<details>
<summary>таски устас настройкой PAM</summary>

```
- name: Enable pam_exec for sshd
  community.general.pamd:
    name: sshd
    type: account
    control: required
    module_path: pam_nologin.so
    new_type: account
    new_control: required
    new_module_path: pam_exec.so
    module_arguments: /usr/local/bin/ssh_login.sh
    state: before

- name: Enable pam_exec for login
  community.general.pamd:
    name: login
    type: account
    control: required
    module_path: pam_nologin.so
    new_type: account
    new_control: required
    new_module_path: pam_exec.so
    module_arguments: /usr/local/bin/ssh_login.sh
    state: before
```

</details>

#### часть II Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

Для выполнения этой задачи сделаем роль `docker`
Права будем давать пользователю `vagrant`, что и отобразим в переменных:

> (.venv) serg@hpg11u:~/otus/otus-linux/task_12$ cat roles/docker/defaults/> main.yml   
> ---  
> \# defaults file for roles/docker  
> user: vagrant  

Собственно задачу разобьём на две части, `docker_install` и `docker_configure`, которые будем вызыватиь из `docker/tasks/mail.yml`

<details>
<summary>tasks/mail.yml</summary>

```
# tasks file for roles/docker
- name: Install docker
  include_tasks: docker_install.yml
  tags:
    - docker_install

- name: Configure rights
  include_tasks: configure.yml
  tags:
    - docker_configure
```

</details>

В `docker_install` с помощью модуля `yum` установим `docker`

> - name: Install docker  
>   yum:  
>     name: docker  
>     state: installed  

А в `docker_configure` создадим ряд тасок, которыми добавим в `systemd.unit` docker'а поправочку, которая даст права пользователю на чтение/запись `/var/run/docker.sock`
Насколько я понял из https://betterprogramming.pub/about-var-run-docker-sock-3bfd276e12fd это нужно для создания/старта контейнера.

> [Service]  
> ExecStartPost=/usr/bin/setfacl -m "u:{{ user }}:rw-" /var/run/docker.sock  

После чего выполнятся `systemctl daemon-reload` и `systemctl enable docker`/`systemctl start docker`, только в виде тасок.

> - name: Re-read changes  
>   systemd:  
>     daemon-reload: yes  
>   
> - name: Enable and start docker  
>   systemd:  
>     name: docker.service  
>     state: started  
>     enabled: yes  


И, вишенка нашего шашлыка - `polkit`.

> - name: Deploy PolKit rule for docker  
>   template:  
>     src: docker.polkit.j2  
>     dest: /etc/polkit-1/rules.d/01-docker.rules  

Посредством шаблона `docker.polkit.j2` сделаем файл с политикой для нашего пользователя (если уже забыл кто, это - `vagrant`), где разрешим ему управлять юнитами `systemd`, в часности - docker'ом.

> polkit.addRule(function(action, subject) {  
>   if (action.id.match("org.freedesktop.systemd1.manage-units") && subject.user === "{{ user }}") {  
>         polkit.log("Service management granted for user: " + subject.user);  
>         return polkit.Result.YES;  
>   }  
> });  

Проверяем:

    vagrant ssh
    docjer ps

> [vagrant@task-12-pam ~]$ docker ps  
> CONTAINER ID        IMAGE               COMMAND             CREATED             > STATUS              PORTS               NAMES  

#### The end)

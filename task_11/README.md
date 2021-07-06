## ДЗ - 11   Первые шаги с Ansible

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:

    необходимо использовать модуль yum/apt
    конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными
    после установки nginx должен быть в режиме enabled в systemd
    должен быть использован notify для старта nginx после установки
    сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible

Домашнее задание считается принятым, если:

    предоставлен Vagrantfile и готовый playbook/роль ( инструкция по запуску стенда, если посчитаете необходимым )
    после запуска стенда nginx доступен на порту 8080
    при написании playbook/роли соблюдены перечисленные в задании условия


Подготовлен стенд с двумя машинами:

<details>
<summary>два сервера под nginx</summary>

```
  :"nginx-lab-01" => {
        :box_name => "saaverdo/centos-7-5-8",
        :ip_addr => '192.168.11.101',
        :host_port => '8081',
        },
  :"nginx-lab-02" => {
        :box_name => "saaverdo/centos-7-5-8",
        :ip_addr => '192.168.11.102',
        :host_port => '8082',
        }
  }
```

</details>

Запустим стенд командой `vagrant up`

Установим `ansible` в виртуальном окружении python

    python3 -m venv .venv
    source .venv/bin/activate
    pip install ansible

> (.venv) serg@hpg11u:~/otus/otus-linux/task_11$  

посмотрим, какие порты для `ssh` выделил `vagrant`

    vagrant ssh-config | grep -i -B3 port

```
Host nginx-lab-01  
  HostName 127.0.0.1  
  User vagrant  
  Port 2222  
--  
Host nginx-lab-02  
  HostName 127.0.0.1  
  User vagrant  
  Port 2200  
```

В директории `inventory` сделаем файл `hosts.yml` где опишем наши ВМ

```
all:  
  children:  
    web:  
  vars:  
    ansible_host: 127.0.0.1  
  
web:  
  hosts:  
   nginx-lab-01:  
      ansible_port: 2222  
      ansible_ssh_private_key_file: ./.vagrant/machines/nginx-lab-01/virtualbox/private_key  
   nginx-lab-02:  
      ansible_port: 2200  
      ansible_ssh_private_key_file: ./.vagrant/machines/nginx-lab-02/virtualbox/private_key  
```

Для установки nginx будем использовать роль `ansible`.
Сделаем необходимую структуру директорий

    ansible-galaxy init roles/nginx

> (.venv) serg@hpg11u:~/otus/otus-linux/task_11$ tree  
> .  
> ├── ansible.cfg  
> ├── hosts  
> │   └── hosts.yml  
> ├── install_ansilbe.sh  
> ├── README.md  
> ├── roles  
> │   └── nginx  
> │       ├── defaults  
> │       │   └── main.yml  
> │       ├── files  
> │       ├── handlers  
> │       │   └── main.yml  
> │       ├── meta  
> │       │   └── main.yml  
> │       ├── README.md  
> │       ├── tasks  
> │       │   └── main.yml  
> │       ├── templates  
> │       ├── tests  
> │       │   ├── inventory  
> │       │   └── test.yml  
> │       └── vars  
> │           └── main.yml  
> └── Vagrantfile  

И укажем в `ansible.cfg`, где `ansible` должен искать наши файлы

> [defaults]  
> inventory = ./inventory  
> remote_user = vagrant  
> host_key_checking = False  
> retry_files_enabled = False  
> roles_path = ./roles  

Сделаем директорию для наших `playbook`

    mkdir playbooks
    touch playbooks/nginx.yml

Добавим в наш `playbook` `nginx.yml` указание запустить роль `nginx`

```
- name: NGINX | Install EPEL Repo
  hosts: all
  become: true
  roles:
    - nginx
```

Теперь переходим в `roles/nginx`
В директории `templates` нашей роли `roles/nginx` создадим файл фаблона конфигурации NGINX

```
(.venv) serg@hpg11u:~/otus/otus-linux/task_11$ cat roles/nginx/templates/nginx.conf.j2   
# {{ ansible_managed }}  
events {  
    worker_connections 1024;  
}  
  
http {  
    server {  
        listen       {{ nginx_listen_port }} default_server;  
        server_name  default_server;  
        root         /usr/share/nginx/html;  
  
        location / {  
        }  
    }  
}  
```

В `defaults/mail.yml` добавим переменную `nginx_listen_port: 8080`
А в `handlers/mail.yml`, соответственно, `handlers`

```
- name: restart nginx  
  systemd:  
    name: nginx  
    state: restarted  
    enabled: yes  
- name: reload nginx  
  systemd:  
    name: nginx  
    state: reloaded  
```

Осталось прописать таски для роли `nginx`. 
Устанавливать будем из epel-release


<details>
<summary>файл с тасками роли nginx</summary>

```
(.venv) serg@hpg11u:~/otus/otus-linux/task_11$ cat roles/nginx/tasks/main.yml   
---  
# tasks file for roles/nginx  
- name: NGINX | Install EPEL Repo package from standart repo  
  yum:  
    name: epel-release  
    state: present  
  
- name: Install packages  
  yum:  
    name: '{{ item }}'  
    state: present  
  loop: '{{ nginx_host_packages }}'  
  
- name: NGINX | Install nginx package from EPEL Repo  
  yum:  
    name: nginx  
    state: latest  
  notify:  
    - restart nginx  
  tags:  
    - nginx-package  
    - packages  
  
- name: NGINX | Create NGINX config from template  
  template:  
    src: ../templates/nginx.conf.j2  
    dest: /etc/nginx/nginx.conf  
  notify:  
    - reload nginx  
  tags:  
    - nginx-config  
```

</details>

и ~~я получил эту ро~~ запустить нашу роль:

    ansible-playbook playbooks/nginx.yml

```
> PLAY [NGINX | Install EPEL Repo] ************************************************************************  
>   
> TASK [Gathering Facts] **********************************************************************************  
> ok: [nginx-lab-02]  
> ok: [nginx-lab-01]  
>   
> TASK [nginx : NGINX | Install EPEL Repo package from standart repo] *************************************  
> changed: [nginx-lab-02]  
> changed: [nginx-lab-01]  
>   
> TASK [nginx : Install packages] *************************************************************************  
> changed: [nginx-lab-01] => (item=vim)  
> changed: [nginx-lab-02] => (item=vim)  
> changed: [nginx-lab-01] => (item=tree)  
> changed: [nginx-lab-02] => (item=tree)  
> changed: [nginx-lab-01] => (item=bind-utils)  
> changed: [nginx-lab-02] => (item=bind-utils)  
>   
> TASK [nginx : NGINX | Install nginx package from EPEL Repo] *********************************************  
> changed: [nginx-lab-01]  
> changed: [nginx-lab-02]  
>   
> TASK [nginx : NGINX | Create NGINX config from template] ************************************************  
> changed: [nginx-lab-02]  
> changed: [nginx-lab-01]  
>   
> RUNNING HANDLER [nginx : restart nginx] *****************************************************************  
> changed: [nginx-lab-01]  
> changed: [nginx-lab-02]  
>   
> RUNNING HANDLER [nginx : reload nginx] ******************************************************************  
> changed: [nginx-lab-02]  
> changed: [nginx-lab-01]  
>   
> PLAY RECAP **********************************************************************************************  
> nginx-lab-01               : ok=7    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0     
> nginx-lab-02               : ok=7    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0     
```

Уря!
Проверяем:

    curl -I localhost:8081

> HTTP/1.1 200 OK  
> Server: nginx/1.20.1  
> Date: Tue, 06 Jul 2021 10:25:49 GMT  
> Content-Type: text/html  
> Content-Length: 4833  
> Last-Modified: Fri, 16 May 2014 15:12:48 GMT  
> Connection: keep-alive  
> ETag: "53762af0-12e1"  
> Accept-Ranges: bytes  

    curl -I localhost:8082

> HTTP/1.1 200 OK  
> Server: nginx/1.20.1  
> Date: Tue, 06 Jul 2021 10:26:18 GMT  
> Content-Type: text/html  
> Content-Length: 4833  
> Last-Modified: Fri, 16 May 2014 15:12:48 GMT  
> Connection: keep-alive  
> ETag: "53762af0-12e1"  
> Accept-Ranges: bytes  


#### The end)

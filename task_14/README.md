## ДЗ - 12   PAM

> Создайте свой кастомный образ nginx на базе alpine. После запуска nginx должен отдавать кастомную страницу (достаточно изменить дефолтную страницу nginx)  
> Определите разницу между контейнером и образомВывод опишите в домашнем задании.  
> Ответьте на вопрос: Можно ли в контейнере собрать ядро?  
> Собранный образ необходимо запушить в docker hub и дать ссылку на ваш репозиторий.  


#### Поехали

Для выполнения задания создадим `Dockerfile` следующего содержания:

<details>
<summary></summary>

```

```

</details>

Теперь соберём наш контейнер командой 

    sudo docker build -t saaverdo/nginx-s:0.1 .

<details>
<summary>build контейнера</summary>

```
Sending build context to Docker daemon  81.92kB
Step 1/8 : FROM alpine:3.12
3.12: Pulling from library/alpine
339de151aab4: Pull complete 
Digest: sha256:87703314048c40236c6d674424159ee862e2b96ce1c37c62d877e21ed27a387e
Status: Downloaded newer image for alpine:3.12
 ---> 13621d1b12d4
Step 2/8 : RUN apk update && apk add nginx
 ---> Running in 80fe777daaec
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/community/x86_64/APKINDEX.tar.gz
v3.12.7-97-g6236a295f7 [http://dl-cdn.alpinelinux.org/alpine/v3.12/main]
v3.12.7-100-g98895c000a [http://dl-cdn.alpinelinux.org/alpine/v3.12/community]
OK: 12753 distinct packages available
(1/2) Installing pcre (8.44-r0)
(2/2) Installing nginx (1.18.0-r3)
Executing nginx-1.18.0-r3.pre-install
Executing busybox-1.31.1-r20.trigger
OK: 7 MiB in 16 packages
Removing intermediate container 80fe777daaec
 ---> 7c76698fe3ca
Step 3/8 : RUN adduser -D -g 'www' www && mkdir -p /var/www && chown -R www:www /var/lib/nginx && chown -R www:www /var/www && mkdir -p /run/nginx
 ---> Running in b7f659953ac4
Removing intermediate container b7f659953ac4
 ---> 0d80008e2807
Step 4/8 : COPY nginx.conf /etc/nginx
 ---> 239040251c0a
Step 5/8 : COPY index.html /var/www
 ---> c24546c87961
Step 6/8 : RUN apk add --no-cache curl
 ---> Running in f3d4af43271b
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/community/x86_64/APKINDEX.tar.gz
(1/4) Installing ca-certificates (20191127-r4)
(2/4) Installing nghttp2-libs (1.41.0-r0)
(3/4) Installing libcurl (7.77.0-r0)
(4/4) Installing curl (7.77.0-r0)
Executing busybox-1.31.1-r20.trigger
Executing ca-certificates-20191127-r4.trigger
OK: 9 MiB in 20 packages
Removing intermediate container f3d4af43271b
 ---> 0506ab76d499
Step 7/8 : EXPOSE 8080
 ---> Running in ce0bd40acb89
Removing intermediate container ce0bd40acb89
 ---> c215b33f7fcf
Step 8/8 : ENTRYPOINT ["nginx", "-g", "daemon off;"]
 ---> Running in fef99f919d0c
Removing intermediate container fef99f919d0c
 ---> 43538e29dc0c
Successfully built 43538e29dc0c
Successfully tagged saaverdo/nginx-s:0.1

```

</details>

Запустим и убедимся, что контейнер работает:

    sudo docker run -d -p 8080:8080 saaverdo/nginx-s:0.1

> a9bd6032466fdb5624364fbd73c36a5761149d5bc7d4a03269c81d7ff9e74532  

    sudo docker ps

> CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                    NAMES  
> a9bd6032466f   saaverdo/nginx-s:0.1   "nginx -g 'daemon of…"   13 minutes ago   Up 13 minutes   0.0.0.0:8080->8080/tcp   romantic_banzai  

Теперь посмотрим, что же выдаёт NGINX

    curl localhost:8080 

```
<!DOCTYPE html>
<html>
  <head>
      <title>NGINX-IN-DOCKER</title>
  </head>
  <body>
    <h1>This NGINX run in docker container!</h1>
  </body>
```

Осталось запушить наш образ на `docker hub`

Логинимся  в `docker hub`

    sudo docker login

и запушим туда наш контейнер:

    sudo docker push saaverdo/nginx-s:0.1

Теперь он доступен по ссылке:
https://hub.docker.com/r/saaverdo/nginx-s



#### Определите разницу между контейнером и образом

Образ - подготовленный файл с приложением и его окружением, а контейнер - запущенный экземпляр на образа с необходимыми параметрами.
Очень грубой и неточной параллелью образ-контейнер может служить бокс-виртуалка vagrant.


#### Ответьте на вопрос: Можно ли в контейнере собрать ядро?  

Да, можно

#### The end)

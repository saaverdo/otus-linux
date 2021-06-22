### ДЗ - 4

Практические навыки работы с ZFS

Условие задания:

> Цель:  
>   
> Отрабатываем навыки работы с созданием томов export/import и установкой параметров.  
>   
> Определить алгоритм с наилучшим сжатием.  
> Определить настройки pool’a Найти сообщение от преподавателей  
>   
> Результат: список команд которыми получен результат с их выводами  
>   
>     Определить алгоритм с наилучшим сжатием  
>   
> Зачем: Отрабатываем навыки работы с созданием томов и установкой параметров.   Находим > наилучшее сжатие.  
>   
> Шаги:  
>   
>     определить какие алгоритмы сжатия поддерживает zfs (gzip gzip-N, zle lzjb, lz4)  
>     создать 4 файловых системы на каждой применить свой алгоритм сжатия Для сжатия   > использовать либо текстовый файл либо группу файлов:  
>     скачать файл “Война и мир” и расположить на файловой системе wget -O >   War_and_Peace.txt http://www.gutenberg.org/ebooks/2600.txt.utf-8 либо скачать > файл   ядра распаковать и расположить на файловой системе
>   
> Результат:  
>   
>     список команд которыми получен результат с их выводами  
>     вывод команды из которой видно какой из алгоритмов лучше  
>   
>     Определить настройки pool’a  
>   
> Зачем: Для переноса дисков между системами используется функция export/import. >   Отрабатываем навыки работы с файловой системой ZFS  
>   
> Шаги:  
>   
>     Загрузить архив с файлами локально. https://drive.google.com/open?>   id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg Распаковать.  
>     С помощью команды zfs import собрать pool ZFS.  
>     Командами zfs определить настройки  
>         размер хранилища  
>         тип pool  
>         значение recordsize  
>         какое сжатие используется  
>         какая контрольная сумма используется Результат:  
>         список команд которыми восстановили pool . Желательно с Output команд.  
>         файл с описанием настроек settings  
>   
>     Найти сообщение от преподавателей  
>   
> Зачем: для бэкапа используются технологии snapshot. Snapshot можно передавать между   > хостами и восстанавливать с помощью send/receive. Отрабатываем навыки   восстановления > snapshot и переноса файла.  
>   
> Шаги:  
>   
>     Скопировать файл из удаленной директории. https://drive.google.com/file/d/>   1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing Файл был получен командой zfs >   send otus/storage@task2 > otus_task2.file  
>     Восстановить файл локально. zfs receive  
>     Найти зашифрованное сообщение в файле secret_message  
>   
> Результат:  
>   
>     список шагов которыми восстанавливали  
>     зашифрованное сообщение  





#### часть I Определить алгоритм с наилучшим сжатием

Глянем, что у нас имеется в плане дисков?

    lsblk

> [root@server ~]# lsblk  
> NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT  
> sda      8:0    0  10G  0 disk   
> `-sda1   8:1    0  10G  0 part /  
> sdb      8:16   0   1G  0 disk   
> sdc      8:32   0   1G  0 disk   
> sdd      8:48   0   1G  0 disk   
> sde      8:64   0   1G  0 disk   
> sdf      8:80   0   1G  0 disk   
> sdg      8:96   0   1G  0 disk   

Создадим zpool с названием task

    zpool create -o ashift=12 task raidz2 sd{b,c,d,e} log mirror sd{f..g}
    zpool status; zpool list

> [root@server ~]# zpool status; zpool list  
>   pool: task  
>  state: ONLINE  
>   scan: none requested  
> config:  
>   
> 	NAME        STATE     READ WRITE CKSUM  
> 	task        ONLINE       0     0     0  
> 	  raidz2-0  ONLINE       0     0     0  
> 	    sdb     ONLINE       0     0     0  
> 	    sdc     ONLINE       0     0     0  
> 	    sdd     ONLINE       0     0     0  
> 	    sde     ONLINE       0     0     0  
> 	logs	  
> 	  mirror-1  ONLINE       0     0     0  
> 	    sdf     ONLINE       0     0     0  
> 	    sdg     ONLINE       0     0     0  
>   
> errors: No known data errors  
> NAME   SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT  
> task  3.75G  1.05M  3.75G        -         -     0%     0%  1.00x    ONLINE  -  

Посмотрим, что может предложить zfs в плане сжатия
    man zfs
    
> compression=on|off|gzip|gzip-N|lz4|lzjb|zle  

Приведу цитату из статьи:

    LZ4 — это потоковый алгоритм, предлагающий чрезвычайно быстрое сжатие и декомпрессию и выигрыш в производительности для большинства случаев использования — даже на довольно медленных CPU.
    GZIP — почтенный алгоритм, который знают и любят все пользователи Unix-систем. Он может быть реализован с уровнями сжатия 1-9, с увеличением степени сжатия и использования CPU по мере приближения к уровню 9. Алгоритм хорошо подходит для всех текстовых (или других чрезвычайно сжимаемых) вариантов использования, но в противном случае часто вызывает проблемы c CPU — используйте его с осторожностью, особенно на более высоких уровнях.
    LZJB — оригинальный алгоритм в ZFS. Он устарел и больше не должен использоваться, LZ4 превосходит его по всем показателям.
    ZLE — кодировка нулевого уровня, Zero Level Encoding. Она вообще не трогает нормальные данные, но сжимает большие последовательности нулей. Полезно для полностью несжимаемых наборов данных (например, JPEG, MP4 или других уже сжатых форматов), так как он игнорирует несжимаемые данные, но сжимает неиспользуемое пространство в итоговых записях.

Создадим 4 датасета для алгоритмов сжатия gzip, lz4, lzjb, zle

    zfs create task/part1
    zfs create -o compression=lz4 task/part1/comp_lz4
    zfs create -o compression=gzip task/part1/comp_gzip
    zfs create -o compression=lzjb task/part1/comp_lzjb
    zfs create -o compression=zle task/part1/comp_zle


    zfs list

> [root@server ~]# zfs list  
> NAME                      USED  AVAIL     REFER  MOUNTPOINT  
> task                     1.54M  1.69G      145K  /task  
> task/part1                878K  1.69G      180K  /task/part1  
> task/part1/comp_gzip      140K  1.69G      140K  /task/part1/comp_gzip  
> task/part1/comp_lz4       140K  1.69G      140K  /task/part1/comp_lz4  
> task/part1/comp_lzjb      140K  1.69G      140K  /task/part1/comp_lzjb  
> task/part1/comp_zle       140K  1.69G      140K  /task/part1/comp_zle  
> task/part1/uncompressed   140K  1.69G      140K  /task/part1/uncompressed  

И убедимся, что компрессия данных включена
    
    zfs get compression

> [root@server ~]# zfs get compression  
> NAME                     PROPERTY     VALUE     SOURCE  
> task                     compression  off       default  
> task/part1               compression  off       default  
> task/part1/comp_gzip     compression  gzip      local  
> task/part1/comp_lz4      compression  lz4       local  
> task/part1/comp_lzjb     compression  lzjb      local  
> task/part1/comp_zle      compression  zle       local  
> task/part1/uncompressed  compression  off       default  

Теперь возьмём файл, на котором будем проверять работу сжатия

    wget -O /task/part1/uncompressed/dune.txt https://www.dropbox.com/sh/adbv1alp5oury4z/AACLug_oczRiOXNqWMqwEYE2a/dune.txt

Раскидаем его по нашим датасетам

> [root@server ~]# tree /task/part1/  
> /task/part1/  
> ├── comp_gzip  
> │   └── dune.txt  
> ├── comp_lz4  
> │   └── dune.txt  
> ├── comp_lzjb  
> │   └── dune.txt  
> ├── comp_zle  
> │   └── dune.txt  
> └── uncompressed  
>     └── dune.txt  

Теперь посмотрим, сколько занимает места антология Дюны на датасетах с различной степенью сжатия. Воспользуемся командой `du -h` с опцией `--apparent-size`

> [root@server ~]# du -h /task/part1/uncompressed/dune.txt   
> 5.3M	/task/part1/uncompressed/dune.txt  
> [root@server ~]# du -h --apparent-size /task/part1/uncompressed/dune.txt   
> 5.3M	/task/part1/uncompressed/dune.txt  

для датасета без сжатия, ожидаемо, разница отсутствует

Теперь на `zle`. тут также нет разницы.

>  [root@server ~]# du -h /task/part1/comp_zle/dune.txt   
>  5.3M	/task/part1/comp_zle/dune.txt  
>  [root@server ~]# du -h --apparent-size /task/part1/comp_zle/dune.txt   
>  5.3M	/task/part1/comp_zle/dune.txt  

Посмотрим на `lzjb` (4,4М от 5,3М)

>  [root@server ~]# du -h /task/part1/comp_lzjb/dune.txt   
>  4.4M	/task/part1/comp_lzjb/dune.txt  
>  [root@server ~]# du -h --apparent-size /task/part1/comp_gzip/dune.txt   
>  5.3M	/task/part1/comp_gzip/dune.txt  

И на `gzip` (2,4М от 5,3М)

> [root@server ~]# du -h /task/part1/comp_gzip/dune.txt   
> 2.4M	/task/part1/comp_gzip/dune.txt  
> [root@server ~]# du -h --apparent-size /task/part1/comp_gzip/dune.txt   
> 5.3M	/task/part1/comp_gzip/dune.txt  

На десерт у нас `lz4` (3,7М от 5,3М)

> [root@server ~]# du -h /task/part1/comp_lz4/dune.txt   
> 3.7M	/task/part1/comp_lz4/dune.txt  
> [root@server ~]# du -h --apparent-size /task/part1/comp_lz4/dune.txt   
> 5.3M	/task/part1/comp_lz4/dune.txt  

Таким образом, на данном текстовом примере лучше всего себя показал `gzip`,
что подтверждается информацией от самой zfs:

    zfs get compression,compressratio

> [root@server ~]# zfs get compression,compressratio  
> NAME                     PROPERTY       VALUE     SOURCE  
> task                     compression    off       default  
> task                     compressratio  1.25x     -  
> task/part1               compression    off       default  
> task/part1               compressratio  1.26x     -  
> task/part1/comp_gzip     compression    gzip      local  
> task/part1/comp_gzip     compressratio  2.26x     -  
> task/part1/comp_lz4      compression    lz4       local  
> task/part1/comp_lz4      compressratio  1.43x     -  
> task/part1/comp_lzjb     compression    lzjb      local  
> task/part1/comp_lzjb     compressratio  1.21x     -  
> task/part1/comp_zle      compression    zle       local  
> task/part1/comp_zle      compressratio  1.00x     -  
> task/part1/uncompressed  compression    off       default  
> task/part1/uncompressed  compressratio  1.00x     -  


#### часть II ~~Две сорванные башни~~ Определить настройки pool’a

Cкачаем..

    wget -O zfs_task1.tar.gz https://www.dropbox.com/sh/adbv1alp5oury4z/AADpekzHBfO49lpAAAdYS2PTa/zfs_task1.tar.gz?dl=0

и распакуем ~~лутбокс~~ файл с заданием

    tar -xvzf zfs_task1.tar.gz

> [root@server ~]# tar -xvzf zfs_task1.tar.gz   
> zpoolexport/  
> zpoolexport/filea  
> zpoolexport/fileb  

Такс, что тут у нас?

> [root@server ~]# ll -h  zpoolexport/  
> total 1000M  
> -rw-r--r--. 1 root root 500M May 15  2020 filea  
> -rw-r--r--. 1 root root 500M May 15  2020 fileb  

теперь импортируем этот пул...

    zpool import -d zpoolexport/

> [root@server ~]# zpool import -d zpoolexport/  
>    pool: otus  
>      id: 6554193320433390805  
>   state: ONLINE  
>  action: The pool can be imported using its name or numeric identifier.  
>  config:  
>   
> 	otus                         ONLINE  
> 	  mirror-0                   ONLINE  
> 	    /root/zpoolexport/filea  ONLINE  
> 	    /root/zpoolexport/fileb  ONLINE  

(ага, используется зеркалирование)
и его датасторы

    zpool import -d zpoolexport/ otus

Посмотрим на привалившее счастье:

    zpool list otus

> [root@server ~]# zpool list otus  
> NAME   SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT  
> otus   480M  2.09M   478M        -         -     0%     0%  1.00x    ONLINE  -  

    zfs list otus

> [root@server ~]# zfs list otus  
> NAME   USED  AVAIL     REFER  MOUNTPOINT  
> otus  2.04M   350M       24K  /otus  

И теперь с помощью команды 

    zfs get recordsize,compression,checksum otus

> [root@server ~]# zfs get recordsize,compression,checksum otus  
> NAME  PROPERTY     VALUE      SOURCE  
> otus  recordsize   128K       local  
> otus  compression  zle        local  
> otus  checksum     sha256     local  

мы момжем дать ответы на вопросы:

> Размер хранилища - `480М`  
> Тип pool - `mirror`  
> Значение recordsize - `128K`  
> Значение compression - `zle`  
> Значение checksum - `sha256`  

#### часть III ~~Возвращение кор~~ Найти сообщение от преподавателей 

Cкачаем файл с заданием

    wget -O otus_task2.file https://www.dropbox.com/sh/adbv1alp5oury4z/AAB3c-s0UfENdUcVUSySVxhUa/otus_task2.file?dl=0

и посмотрим, что же это к нам попало

    file otus_task2.file    

> [root@server ~]# file otus_task2.file   
> otus_task2.file: ZFS shapshot (little-endian machine), version 17, type: ZFS, >   destination GUID: 70 B1 CE AB 92 00 51 35, name: 'otus/storage@task2'  

`ZFS shapshot`, какая прелесть.
Импортируем его 

    zfs receive otus/hometask3 < otus_task2.file

Убедимся, что снапшот импортировался

    zfs list

> [root@server ~]# zfs list  
> NAME                      USED  AVAIL     REFER  MOUNTPOINT  
> otus                     4.97M   347M       25K  /otus  
> otus/hometask2           1.88M   347M     1.88M  /otus/hometask2  
> otus/hometask3           2.85M   347M     2.83M  /otus/hometask3  

и поищем файл `secret_message`

    find /otus/hometask3/ -name "secret_message" -exec cat {} \;

> https://github.com/sindresorhus/awesome  


#### The end)

---
layout: post
title:  "Dockerfile volume 测试"
date:   2017-08-18 23:44:06 +0800
categories: docker
---

最近在使用开源Image 作为基础进行新image创建的时候，遇到Volume问题，特进行测试并进行记录。

使用busybox 作为最基础的image，创建以下dockerfile
* volume 基础镜像Dockerfile base-Dockerfile

        FROM busybox 
        RUN   mkdir /volume /commdir
        RUN  adduser --uid 111 test -D
        RUN touch /volume/filebefore
        VOLUME /volume
        RUN touch /volume/fileafter
        ADD ./basetest /volume
* 子image ,Dockerfile

        FROM volume-test-base
        COPY ./test /volume/test
        COPY ./test /commdir/test
        RUN chown -hR test /volume
        RUN chown -hR test /commdir

* 一个测试脚本

           
        echo "test" >./test
        echo "base" >./basetest
        docker build -t volume-test-base . -f base-Dockerfile  --no-cache 
        docker build -t volume-test  .  --no-cache 
        docker run --rm -it volume-test  ls  -ltr /commdir 
        docker run --rm -it volume-test  ls  -ltr /volume 

        docker run --rm -it volume-test-base   ls  -ltr /volume 

运行结果如下：

     root@flannel:/media/psf/57root/dockerfile-volume-test# ./test.sh
    Sending build context to Docker daemon  6.144kB
    Step 1/7 : FROM busybox
     ---> 7968321274dc
    Step 2/7 : RUN mkdir /volume /commdir
     ---> Running in a2488b3340a7
     ---> 6110c6a34c7b
    Removing intermediate container a2488b3340a7
    Step 3/7 : RUN adduser --uid 111 test -D
     ---> Running in 72eaa1f07426
     ---> f1f4995f8751
    Removing intermediate container 72eaa1f07426
    Step 4/7 : RUN touch /volume/filebefore
     ---> Running in b11a1bacb99f
     ---> 2c16779576d9
    Removing intermediate container b11a1bacb99f
    Step 5/7 : VOLUME /volume
     ---> Running in ae30df4e3bd3
     ---> fa81508eca60
    Removing intermediate container ae30df4e3bd3
    Step 6/7 : RUN touch /volume/fileafter
     ---> Running in a873cc8a0038
     ---> 9119dfff6d69
    Removing intermediate container a873cc8a0038
    Step 7/7 : ADD ./basetest /volume
     ---> 25b66efc3f7e
    Removing intermediate container 10df898a8bbb
    Successfully built 25b66efc3f7e
    Successfully tagged volume-test-base:latest
    Sending build context to Docker daemon  6.144kB
    Step 1/5 : FROM volume-test-base
     ---> 25b66efc3f7e
    Step 2/5 : COPY ./test /volume/test
     ---> ee3f4f23b10c
    Removing intermediate container 8dcc417ab135
    Step 3/5 : COPY ./test /commdir/test
     ---> 37b823ebb23a
    Removing intermediate container e85340587c47
    Step 4/5 : RUN chown -hR test /volume
     ---> Running in 137e7d72d4b7
     ---> a2b155e02fad
    Removing intermediate container 137e7d72d4b7
    Step 5/5 : RUN chown -hR test /commdir
     ---> Running in acc3ffc39114
     ---> 02454129541c
    Removing intermediate container acc3ffc39114
    Successfully built 02454129541c
    Successfully tagged volume-test:latest
    total 4
    -rw-r--r--    1 test     root             5 Aug 18 15:51 test
    total 8
    -rw-r--r--    1 root     root             5 Aug 18 15:51 test
    -rw-r--r--    1 root     root             5 Aug 18 15:51 basetest
    -rw-r--r--    1 root     root             0 Aug 18 15:51 filebefore
    total 4
    -rw-r--r--    1 root     root             5 Aug 18 15:51 basetest
    -rw-r--r--    1 root     root             0 Aug 18 15:51 filebefore


可以看到：
* 所有文件被保存在volume中
* 所有在VOLUMNE 的操作都没有被保存，无论是touch 还是chown

查看volume 也可以看到文件owner还都是root

        root@flannel:/media/psf/57root/robert-gz.github.io/_posts# docker run -d -it volume-test sh -c cat
        73526055f3b4896f63e74ed8b2d801610e7cadea05dcce583b0450c019da9564
        root@flannel:/media/psf/57root/robert-gz.github.io/_posts# docker ps
        CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
        73526055f3b4        volume-test         "sh -c cat"         2 seconds ago       Up 2 seconds                            elated_darwin
        root@flannel:/media/psf/57root/robert-gz.github.io/_posts# docker volume ls
        DRIVER              VOLUME NAME
        local               e5b8d7b756457713846bff2234016b0dd05a59a1303ac416197b8e9ece664d25
        root@flannel:/media/psf/57root/robert-gz.github.io/_posts# ls -ltr /var/lib/docker/volumes/e5b8d7b756457713846bff2234016b0dd05a59a1303ac416197b8e9ece664d25/_data
        total 8
        -rw-r--r-- 1 root root 5 Aug 18 23:51 test
        -rw-r--r-- 1 root root 5 Aug 18 23:51 basetest
        -rw-r--r-- 1 root root 0 Aug 18 23:51 filebefore

总之，dockerfile 里面volume 存放文件没有问题，但如果要修改用户及其它操作，必须在容器启动后自行处理，dockerfile里面设置是无效的



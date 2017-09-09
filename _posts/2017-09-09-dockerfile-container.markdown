---
layout: post
title:  "Dockerfile 创建及Container启动小技巧"
date:   2017-09-09 18:44:06 +0800
categories: docker
---

最近看了不少开源代码的Image，总结下自己认为创建Image及启动Container要注意的小技巧。

创建Image
* 如果牵涉到编译，尽量使用1.7 的multi-stage 
* 适当使用Arg ,使用Arg的时候最好设置默认值
* 使用&& 或者;一次执行多条语句降低层数
* 使用apt-get或者yum安装时候后面跟上clean语句，清除安装包，降低大小
         apt-get update && apt-get install -y traceroute && apt clean
* 将需要进行写的文件及目录通过ln等方法汇总到一个目录下，并且使用volume 标示
* 非Volume部分应该是只读的
* 在容器使用非root启动应用要注意权限，尤其是volume的权限

 
启动Container 应该注意下
* 同步所有容器的时区，启动时候加上-v /etc/localtime:/etc/localtime:ro
* 对于有状态服务，尽量配置接收stop signal ，默认有10秒来完成shutdown，在docker1.7可以调整这个世界
* 所有主机必须配置时间同步，时区最好也一致，否则会有各种奇怪问题


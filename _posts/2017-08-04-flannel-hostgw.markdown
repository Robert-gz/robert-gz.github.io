---
layout: post
title:  "flannel hostgw 原理及代码分析"
date:   2017-08-12 10:44:06 +0800
categories: SDN
---

最近在不同的群里看到很多讲Calico 的优势，这些文章大多说flannel 只支持Vxlan，实际上Flannel 还有一种backend ：hostgw。

Hostgw 的原理非常的简单，在每台节点的route表里面增加相关虚拟网络节点的信心，核心命令就是ip route，如果你的环境不是很大，其实是一种非常好的sdn。

Hostgw 的配置如下：
        {
        "Network": "192.160.0.0/16",
        "SubnetLen": 26,
        "SubnetMin": "192.160.0.64",
        "SubnetMax": "192.160.250.192",
        "Backend": 
          {
            "Type": "host-gw"
          }
        }
和VXLAN的区别只在Backend 的Type

ETCD 的数据结构如下
           
        root@flannel:/media/psf# etcdctl ls /coreos.com/network
            /coreos.com/network/config
            /coreos.com/network/subnets
            root@flannel:/media/psf# etcdctl ls /coreos.com/network/subnets
            /coreos.com/network/subnets/192.160.16.192-26
            root@flannel:/media/psf# 

在flannel 0.8.0 已经开始支持使用k8s ，可以参看kube.go ,但这种模式还是实验版本，本文还是focus在基于etcd的local manager 模式，在这种模式下，Hostgw 模式下的代码主要还是在以下文件：
* main.go 
* local_manager.go
* hostgw.go
* hostgw_network.go
* registry.go


Flannel 在hostgw 模式下子网的分配模式没有变化，仍然使用lease 模式管理，为每个主机分配一段网络，基于CIDR模式。 默认lease 是24小时，即如果机器断网24小时，原来分配的CIDR可能被其它机器占用，如果要修改这个值，请在local_manager里面修改

        const (
            raceRetries = 10
            subnetTTL   = 24 * time.Hour
        )


local_manager 同时还负责申请lease，即申请虚拟网络，主要是以下几个函数
* WatchLeases 监听lease 变化，调用registry的WatchSubnets
* AcquireLease：调用tryAcquireLease, 失败时候再规定次数内再次重试
* tryAcquireLease:完成一次lease的申请,申请的次序如下
    -  如etcd 已经有对应配置，那么继续使用
    -  如ocalmanager 的previousSubnet 不为空，使用previousSubnet，previous Subnet  实际就是保存在/run/flannel/subnet.env 里面的数据，因此如果修改每个节点的存放位置（flannel 参数：-subnet-file），就可以实现subnet 与宿主IP的固定化
    -  以上都没有，才调用egistry.go createSubnet来创建新的lease/subnet

Registry.go 相对底层，负责lease的增加、修改、删除，监听变化并生产对应event，其它三个go文件都有调用registry.go ，函数用途从命名上也基本都可以知道，负责监听的函数主要有
* parseSubnetWatchResponse，被watchSubnets调用，生产lease的变化情况event flannel将根据event 修改route
* watchSubnets(ctx context.Context, since uint64) (Event, uint64, error)，监听的是/coreos.com/network/subnets
* watchSubnet(ctx context.Context, since uint64, sn ip.IP4Net) (Event, uint64, error)，监听的本机对应的rease ,即/coreos.com/network/subnets/192.160.16.192-26

hostgw.go 提供标准接口，创建一个backend 管理对象：HostgwBackend ，提供标准的Registernetwork 接口。

hostgw_network.go 是负责创建etcd watcher 并更新route 信息的主体，主要函数包括
*Run 
    - 启动 一个go routine执行Watchlease 
    - 启动 另外一个go routine 执行本地routecheck
*handleSubnetEvents 处理watch 的event，调用package netlink.Route 进行route操作，所有结果通过ip route 可以查看到
*routecheck 定时调用checkSubnetExistInRoutes 来保证本地route 与etcd中的配置一致

hostgw_network.go里面的network struct 的subnet.Manager 在etcd 模式下就是local_manager

最后我们来看下main.go ,flannel 使用package flagutil 来解析入口参数，func init 就负责参数初始化。

在main 函数依次执行以下内容
* 选择网络interface ，对于backend 主要就是获取到route转发需要的主机ip
    - 如果要知道interface ，使用的参数是iface-regex 或者iface
    - 如果没有指定，使用ip route default 对应的interface
    - public-ip 如果指定，必须是interface 的默认IP，hostgw不支持其它IP
    - 一般情况下建议使用默认就可以
* 创建一个SubnetManager kube或者local（etcd）
* 创建Signal 响应退出信号，用于安全退出，生产了一个go routine：go shutdown(sigs, cancel)
* 如果设置了健康检查端口，创建健康监测   go mustRunHealthz()
* 创建backend manager：be, err := bm.GetBackend(config.BackendType)
* 执行RegisterNetwork ，调用了local_manager的tryAcquireLease
* 如果设置了ip-masq ，即允许访问宿主机的网络，调用ipmasq的SetupIPMasq，在iptables 的 NAT的chain： POSTROUTING 增加 四条rule, 具体见func rules，调用的AppendUnique，这个函数内置的是否已经存在的判断，因此可以重复调用，保证flannel重新启动后iptables 配置不重复
* 调用WriteSubnetFile 将配置写入文件 /run/flannel/subnet.env 
* 调用backend的run 函数
* 如果是etcd模式，调用MonitorLease 负责
    - 调用subnet.WatchLease ，监听本机网络lease 变化，即监听：/coreos.com/network/subnets/192.160.16.192-26
    - 定时续约，即更新etcd 里面的ttl ，默认是在租约到期前1小时，参数：subnet-lease-renew-margin
    - 发现lease 被删除，报错并退出
    - 发现新增（第一次），设置下次续约时间






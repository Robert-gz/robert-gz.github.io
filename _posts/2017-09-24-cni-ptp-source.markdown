---
layout: post
title:  "cni ptp 代码分析"
date:   2017-09-24 08:00:06 +0800
categories: sdn cni ptp
---

最近老是被客户问能否支持flat network，虽然从实际使用上来看，这种场景估计很少用到，但也需要真正考虑自己如何实现，于是抽空看下CNI代码，考虑如何实现。


这里以ptp 插件为例进行学习，为何是PTP呢，因为这种一开始是我最不熟悉的网络模式，其次发现其实可以ptp为基础快速实现flat。

先分析下cni本身的主要流程，skel.go
*入口main ，func PluginMain(cmdAdd, cmdDel func(_ *CmdArgs) error, versionInfo version.PluginInfo) ，所有cni plugins都要调用此函数，这个函数就是生产一个dispatcher 封装好输入、输出及环境变量，并调用(t *dispatcher) pluginMain
           
        dispatcher{
                Getenv: os.Getenv,
                Stdin:  os.Stdin,
                Stdout: os.Stdout,
                Stderr: os.Stderr,}
*(t *dispatcher) pluginMain 主要完成检查及回调plugins的add/del/version命令
    *调用getCmdArgsFromEnv
        * 首先定义那些参数是必须的： vars,并根据CNI_COMMAND进行检查
        * 将CNI_COMMAND保存为cmd
        * 其它信息，如containerid,netns,network interface,stdin保持为cmdArgs并返回
    * 分析命令，ADD/DEL 通过checkVersionAndCall 回调cmdAdd/cmdDel  函数，这两个函数都是plugins 通过入口main 函数设置的
    * 如果是version 命令，根据plugins的配置文件内容返回：versionInfo.Encode(t.Stdout)，versioninfo的定义在package version下的plugins.go
*checkVersionAndCall,检查版本是否匹配，如果匹配就执行：toCall(cmdArgs) 调用cmdAdd/Del

以上就完成基本调用分析，下面是ptp的代码分析，focus在cmdAdd

*调用ipam.ExecAdd(conf.IPAM.Type, args.StdinData) 获取ip，其实是调用一次ipam plugins
    *调用invoke.DelegateAdd(plugin, netconf) 
    *判断CNI_COMMAND是否为ADD
    *在CNI_PATH search 对应执行文件
    *通过exec.go 最终调用raw_exec.go
        
        exec.Cmd{
                Env:    environ, —环境变量
                Path:   pluginPath, —命令，如ptp，veth等plugins 执行文件
                Args:   []string{pluginPath}, 
                Stdin:  
        bytes.NewBuffer(stdinData), -cni 配置文件
                Stdout: stdout,
                Stderr: e.Stderr,
            }
*EnableForward(result.IPs); -根据IP 是IP4/IP6 打开IP4/IP6 FORWARD
*调用ns.getNg 获取network namespace
*设置container段的veth setupContainerVeth
    *SetupVeth
    * 调用ipam.ConfigureIface，配置interface
    *删除原有Route，增加route以保障通讯
    *Send a gratuitous arp for all v4 addresses ，主动对外通知ip
    *返回hostInterface 及containerinterface
*setupHostVeth，操作类似，注意下host veth段的ip来自ipc.Gateway ,及将ipam返回的网关地址设置为veth的地址
*如果conf.IPMasq ，设置ipmasq
*调用types.PrintResult 返回结果






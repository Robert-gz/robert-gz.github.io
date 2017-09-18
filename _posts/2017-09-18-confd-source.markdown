---
layout: post
title:  "confd 代码分析"
date:   2017-09-18 08:00:06 +0800
categories: auto config
---

最近有用的confd，中途遇到些坑，于是决定看看代码避免后续再掉进去。


Confd代码比较简单，这里没有分析它的各种backend的代码，只分析了主体执行部分，涉及：
*confd.go
*processor.go
*resource.go

main 函数在confd.go 中，依次执行
* initConfig ，读取-configfile ，结构体为resource.go  里面的config 。可以将toml/template 目录等,backend 等放在一个toml文件中，取代命令行输入
* 创建一个storeclient ，对接好backend ，具体看client.go
* 如果是once，执行template.Process 并返回
* 根据是watcher还是interval 模式，启动不同处理go routine
* 设置接受退出信号，并循环等待

无论是intervalProcessor 还是WatchProcessor 最终都是调用func process(ts []*TemplateResource) 来执行template的解析及更新，这个process 调用 resource.go 里面的func (t *TemplateResource) process() error 来执行更新。

func (t *TemplateResource) process()代码如下

           
    func (t *TemplateResource) process() error {
        if err := t.setFileMode(); err != nil {
            return err
        }
        if err := t.setVars(); err != nil {
            return err
        }
        if err := t.createStageFile(); err != nil {
            return err
        }
        if err := t.sync(); err != nil {
            return err
        }
        return nil
    }


依次执行：
*文件mode修改
*从backend 读取变量，这个变量设置在toml 文件的keys 中，除环境变量外，其它所有tmpl里面的key都必须是keys的子项
*创建临时文件，stagefile 默认删除，但可以保留
*同步目标文件并执行check及reload

check 及reload 都是调用sh -c 

    func (t *TemplateResource) reload() error {
    log.Debug("Running " + t.ReloadCmd)
    c := exec.Command("/bin/sh", "-c", t.ReloadCmd)
    output, err := c.CombinedOutput()
    if err != nil {
        log.Error(fmt.Sprintf("%q", string(output)))
        return err
    }
    log.Debug(fmt.Sprintf("%q", string(output)))
    return nil}

confd 没有提供是否已经运行的判断，因此需要自己写一个shell来实现是start还是restart。

顺道记录下，编译用dockerfile ，不要用apline 版本的go

    FROM golang:1.8.3

    RUN mkdir -p $GOPATH/src/github.com/kelseyhightower
    RUN echo "cd /go/src/github.com/kelseyhightower/confd && ./build " > /run.sh && chmod +x /run.sh
    CMD ["sh" ,"-c","/run.sh"]


在resource/template 下有一些文件工具，包括获取文件GID/UID/MD5




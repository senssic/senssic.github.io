---
title: temp
date: 2019年06月09日22:28:28
tags: [杂项,记录]
copyright: true
---

##### 容器相关
pod内部容器不可用
echo $TERM  export TERM=dumb
通过 --previous参数可以看之前Pod的日志
kubectl logs zookeeper-1 --previous

##### log日志最优格式化以及配置每日文件滚动:
log4j.rootLogger=INFO,stdout,fileAppender
log4j.appender.fileAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.fileAppender.DatePattern='.'yyyy-MM-dd
log4j.appender.fileAppender.File=/opt/config/fileAppender.log
log4j.appender.fileAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.fileAppender.layout.ConversionPattern=[%p][%t]%-d{yyyy-MM-dd HH:mm:ss.SSS}: (%c{1}.%M:line %L) - %m%n

##### 桥接网络虚拟机无法自动获取ip
dhclient 网卡 -v

##### virtual Boxs使用virtual host和nat网络固定ip
1.新建net网络(管理->全局设置->网络设置)
2.虚拟机新建网卡1virtual host(可以指定网址段)，设置网络类型为virtual host
3.虚拟机新建网卡2设置网络类型为NAT(选择新建的NAT网络,可以指定网址段)
4.固定NAT网络IP地址
   编辑/etc/sysconfig/network-scripts/对应的网卡信息如果没有则新建
   修改属性BOOTPROTO=static
   新增属性(对应网卡的属性)
        IPADDR=10.0.1.101
        NETMASK=255.255.255.255
        GATEWAY=10.0.1.1
5.同上固定virtual host连接的网络IP地址

##### ...


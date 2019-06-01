---
title: 搭建NTP服务器
date: 2019年06月01日16:29:43
tags: [ntp]
categories: [搭建]
---

## 时间相关准备

```shell
#设置时区(东八区)
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime -R
#设置时间
date -s "20190601 16:51:50"
#查看格式化时间
date "+%Y-%m-%d %H:%M:%S"
#查看硬件时间
hwclock -r
#将当前时间回写到硬件上
hwclock -w
```



## 安装NTP离线安装包以及其依赖包

[下载NTP离线安装包](https://download.csdn.net/download/senssic/11221195)

### 服务器端-192.168.0.132

```shell
#安装相关离线包和NTP服务器
rpm -ivh autogen-libopts-5.18-5.el7.x86_64.rpm
rpm -ivh ntp-4.2.6p5-18.el7.centos.x86_64.rpm
rpm -ivh ntpdate-4.2.6p5-18.el7.centos.x86_64.rpm

#启动ntp服务并设置开机启动,若有防火墙需要将防火墙关闭,或者允许123端口
systemctl start ntpd
systemctl enable ntpd

```



### 客户端配置

```shell
#安装相关离线包
rpm -ivh ntpdate-4.2.6p5-18.el7.centos.x86_64.rpm

#同步服务器时间
ntpdate -u 192.168.0.132

#设置自动同步服务器时间
crontab -e
#追加定时任务同步时间(0 0 0 * * ? * 每天凌晨同步一次)
#每30分钟同步一次
*/30 * * * * /usr/sbin/ntpdate 192.168.0.132

#查看crond的状态
service crond status
crond -l
#crond的启动重启停止
service crond start
service crond stop
service crond reload
service crond restart


```



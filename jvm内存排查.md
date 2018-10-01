---
title: jvm内存排查
date: 2018-10-01 10:56:10
tags: [jvm,内存]
categories: [java]
---



一般线上JVM问题属于比较紧急的情况,需要立即保留现场信息,并及时回复生产。

# 保留现场

- 打印堆栈信息	jstack java进程id
- dump堆内存 jmap -dump:format=b,file=./jvmdump java进程id
- 打印至少30秒的jvm垃圾回收情况 jstat -gcutil java进程id 1000
- 查看堆内存占用情况 jmap -histo java进程id,或jmap -histo:live java进程id
- 查看堆情况  jmap -heap java进程id
- 查询系统日志/var/log/messages  一般java进程突然消失,可以到这个里面查看信息

有事在tomcat的jvm配置时候需要添加一些额外参数,这样在系统宕机之前可以保留一些关键的信息

-XX:+PrintGCDetails

-XX:+PrintGCDateStamps

-XX:+HeapDumpOnOutOfMemoryError 

-XX:HeapDumpPath=/usr/temp/dump 

 -Xloggc:/usr/temp/dump/heap_trace.txt  [**确保/usr/temp目录存在**]

# 一般问题原因

- 持续发生Full GC，但是系统不抛出OOM错误
- 堆内存溢出：java.lang.OutOfMemoryError：Java heap space
- 持久带溢出:java.lang.OutOfMemoryError： PermGen  Space (jdk8已移除)
- 线程过多：java.lang.OutOfMemoryError：unable to create new native thread
- JAVA进程退出,一般JVM设置过大导致内存不够用也会导致,JVM一般设置为内存的65%
- CPU占用过高
- JIT编译导致load过高



# 堆内存分析使用到的工具

- MAT
- Jprofile
- Btrace



[MAT使用进阶](https://www.jianshu.com/p/c8e0f8748ac0)

[jstat命令详解](https://blog.csdn.net/zhaozheng7758/article/details/8623549)

[JVM问题分析处理手册](https://zhuanlan.zhihu.com/p/43435903)

[jmap命令详解](https://blog.csdn.net/zhaozheng7758/article/details/8623530)

[jvm性能调优](http://uule.iteye.com/blog/2114697)

[Linux系统日志及日志分析](http://c.biancheng.net/cpp/html/2783.html)






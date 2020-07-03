---
title: temp
date: 2019年06月09日22:28:28
tags: [杂项,记录]
copyright: true
---

##### mysql相关
1.重置root密码
update user set authentication_string = password(‘123456’), password_expired = ‘N’, password_last_changed = now() where user = ‘root’;
2.刷新权限
flush privileges


##### linux相关
1.设置hostname名称
sudo hostnamectl set-hostname <newhostname>

2.查看磁盘

lsblk

3.设置磁盘分区

fdisk /dev/sdf

输入 n 开始进行设置

输入 p  设置主分区

分区号默认

起始扇区默认

结束扇区默认

输入 w 设置保存

重启机器

lsblk 查看磁盘信息

mkfs.ext3 /dev/sda3  #格式化新创建的分区

mkdir data #创建目录

mount /dev/sda3  #挂载分区

vim /etc/fstab #挂载重启生效，永久挂载

df -h  #查看硬盘信息

重启系统

##### 容器相关
1.pod内部容器不可用top命令
echo $TERM  export TERM=dumb
2.通过 --previous参数可以看之前Pod的日志
kubectl logs zookeeper-1 --previous
3.获取登陆dashbord相关
kubectl cluster-info|grep dashboard
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

##### log日志最优格式化以及配置每日文件滚动:
log4j.rootLogger=INFO,stdout,fileAppender
log4j.appender.fileAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.fileAppender.DatePattern='.'yyyy-MM-dd
log4j.appender.fileAppender.File=/opt/config/fileAppender.log
log4j.appender.fileAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.fileAppender.layout.ConversionPattern=[%p][%t]%-d{yyyy-MM-dd HH:mm:ss.SSS}: (%c{1}.%M:line %L) - %m%n

##### 桥接网络虚拟机无法自动获取ip
dhclient 网卡 -v

##### virtual Boxs设置已存在的硬盘的大小

**C:\Program Files\Oracle\VirtualBox\VBoxManage.exe modifyhd E:\vribox\k8s-temp\k8s-temp-disk1.vdi --resize 512000**



##### virtual Boxs使用virtual host和nat网络固定ip
1.新建net网络(管理->全局设置->网络设置)
2.虚拟机新建网卡1virtual host(可以指定网址段)，设置网络类型为virtual host
3.虚拟机新建网卡2设置网络类型为NAT(选择新建的NAT网络,可以指定网址段)
4.固定NAT网络IP地址
   编辑/etc/sysconfig/network-scripts/对应的网卡信息如果没有则新建
   修改属性BOOTPROTO=static
   修改属性NOBOOT=yes
   新增属性(对应网卡的属性)
        IPADDR=10.0.2.101
        NETMASK=255.255.255.0
        GATEWAY=10.0.2.1
5.同上固定virtual host连接的网络IP地址

> virtual boxs上网
>
> 0.使用everthing的iso
>
> 1.使用NET网络选择准虚拟化网络(virtio-net),混杂模式拒绝
>
> 2.创建host-noly网络并选择,混杂模式拒绝



##### kafka相关
1.新建topic
bin/kafka-topics.sh --create --zookeeper node:2181 --topic test --partitions 2 --replication-factor 1
2.修改partition数 只能增
./bin/kafka-topics.sh --alter --topic test2 --zookeeper node:2181 --partitions 3  
3.查看指定topic
bin/kafka-topics.sh --zookeeper zookeeper01:2181 --describe --topic topic_test
4.删除topic
bin/kafka-topics.sh  --delete --topic test --zookeeper node:2181
5.显示某个消费组的消费详情(CURRENT-OFFSET:已消费的,LOG-END-OFFSET:总数,LAG=LOG-END-OFFSET-CURRENT-OFFSET:堆积的消息)
bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --describe --group test-consumer-group
6.消费者列表查询
bin/kafka-topics.sh --zookeeper 127.0.0.1:2181 --list
7.所有新消费者列表
bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --list
8.查询集群描述
bin/kafka-topics.sh --describe --zookeeper 
9.从头开始消费
bin/kafka-console-consumer.sh --zookeeper node:2181 --topic test --from-beginning
10.获取主题(其分区)的最大偏移量
bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic mytopic
11.从尾开始消费指定分区指定消费个数
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic mytopic --offset 10 --partition 0   --max-messages 1 



##### impala相关
[常用修改操作][https://www.cnblogs.com/yhason/p/4724987.html]
 1.查看表的文件分布
 show files in xxx;
 2.查看表的状态
 show table stats xxx;
 3.表基本描述
 describe xxx;
 4.查看表的见表语句
 show CREATE TABLE xxx;
 5.compute stats 
 为表收集重要的与性能相关的信息,以便被 Impala 用于优化查询
 6.更新 impalad 元数据中表的存在性与结构
 invalidate metadata
 7.刷新 impalad 元数据中 Impala 数据文件对应的 HDFS 块的位置
 refresh xxx;
 8.使用jar包查看parquet文件
 https://github.com/apache/parquet-mr/tree/master/parquet-tools?spm=5176.doc52798.2.6.H3s2kL
 http://logservice-resource.oss-cn-shanghai.aliyuncs.com/tools/parquet-tools-1.6.0rc3-SNAPSHOT.jar?spm=5176.doc52798.2.7.H3s2kL&file=parquet-tools-1.6.0rc3-SNAPSHOT.jar
 查看结构：
 java -jar parquet-tools-1.6.0rc3-SNAPSHOT.jar schema -d activity.201711171437.0.parquet |head -n 30
 查看内容：
 java -jar parquet-tools-1.6.0rc3-SNAPSHOT.jar head -n 2 activity.201711171437.0.parquet

##### hdfs相关

 `hadoop fs <选项>` 建议使用
`hdfs dfs <选项>`

| 选项名称       | **使用格式**                                                 | **含义**                                                     | Example                                           |
| -------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------- |
| -ls            | -ls <路径>                                                   | 查看指定路径的当前目录结构                                   | `hadoop fs -ls /input`                            |
| -lsr           | -lsr <路径>                                                  | 递归查看指定路径的目录结构                                   | `hadoop fs -lsr /`                                |
| -du            | -du <路径>                                                   | 统计目录下文件的大小                                         | `hadoop fs -du /input`                            |
| -dus           | -dus <路径>                                                  | 汇总统计目录下文件和文件夹的大小                             | `hadoop fs -du /`                                 |
| -mv            | -mv <源路径> <目的路径>                                      | 移动或重命名                                                 | `hadoop fs -mv /input /tmp`                       |
| -count         | -count [-q] <路径>                                           | 查询文件夹的磁盘空间限额和文件数目限额                       | `hadoop fs -count -p /tmp`                        |
| -cp            | -cp <源路径> <目的路径>                                      | 复制文件(夹)到指定目录                                       | `hadoop fs -cp /one /two`                         |
| -put           | -put <多个 Linux 上的文件>                                   | 上传文件到 HDFS 中                                           | `hadoop fs -put ~/Downloads/abc.txt /two/one/`    |
| -copyFromLocal | -copyFromLocal <多个或单个 linux 上的文件>                   | 从本地复制文件到 HDFS                                        | `hadoop fs -copyFromLocal ~/Downloads/1.txt /two` |
| -moveFromLocal | -moveFromLocal <多个或单个 linux 上的文件>                   | 从本地移动                                                   | `hadoop fs -copyFromLocal ~/Downloads/2.txt /two` |
| -rm            | -rm [-skipTrash] <路径>                                      | 删除文件或空白文件夹, 加上 `-skipTrash` 删除不会放到回收站   | `hadoop -fs -rm -skipTrash /two/one/abc.txt`      |
| -rmr           | -rmr [-skipTrash] <路径>                                     | 递归删除, 加上 `-skipTrash` 删除不会放到回收站               | `hadoop -fs -rmr -skipTrash /two/one`             |
| -getmerge      | -getmerge <源路径> [addnl]                                   | 合并文件到本地, [addnl] 参数实在每一个文件末尾添加一个换行符 | `hadoop fs -getmerge /two/*.txt ~/Down addnl`     |
| -cat           | -cat                                                         | 查看文件内容                                                 | `hadoop fs -cat /input/abc.txt`                   |
| -text          | -text                                                        | 查看文件或者 zip 的内容                                      | `hadoop fs -text /input/abc.txt`                  |
| -copyToLocal   | -copyToLocal [-ignoreCrc] [-crc] [hdfs 源路径] [linux 目的路径] | 从 hdfs 向本地复制                                           | `hadoop fs -copyToLocal /input/* ~/Downloads`     |
| -moveToLocal   | -moveToLocal [-crc]                                          | 从 hdfs 向本地移动                                           | `hdfs dfs -moveToLocal /input/* ~/Downloads`      |
| -mkdir         | -mkdir                                                       | 创建空白文件夹                                               | `hadoop fs -mkdir /666`                           |
| -setrep        | -setrp [-R] [-w] <副本数> <路径>                             | `修改文件的副本系数。-R选项用于递归改变目录下所有文件的副本系数` | `hadoop fs -setrep -R -w 3 /user/hadoop/dir`      |
| -touchz        | -touchz <文件路径>                                           | 创建空白文件                                                 | `hadoop fs -touchz /666/999.log`                  |
| -stat          | -stat [format] <路径>                                        | 显示文件统计信息                                             | `hadoop fs -stat path`                            |
| -tail          | -tail [-f] <文件>                                            | 查看文件尾部信息                                             | `hadoop fs -tail pathname`                        |
| -chmod         | -chmod [-R] <权限模式> [路径]                                | 修改权限                                                     | `hadoop fs -chmod -R 777 /input`                  |
| -chown         | -chown [-R] [属主][:[属组]] 路径                             | 修改属主                                                     | `hadoop fs -chown -R hadoop0 /input`              |
| -chgrp         | -chgrp [-R] 属组名称 路径                                    | 修改属组                                                     | `hadoop fs -chgrp -R root /flume`                 |
| -help          | -help [命令选项]                                             | 查看帮助                                                     | `hadoop fs -help`                                 |


##### 关于断电

1.客户端向服务端发送写操作（数据在客户端的内存中）
2.数据库服务端接收到写请求的数据（数据在服务端的内存中）
3.服务端调用write这个系统调用，将数据往磁盘上写（数据在系统内存的缓冲区中）
4.操作系统将缓冲区中的数据转移到磁盘控制器上（数据在磁盘缓存中）
5.磁盘控制器将数据写到磁盘的物理介质中（数据真正落到磁盘上）

当数据库系统故障时，这时候系统内核还是正常运行的，此时只要执行完了第3步，数据就是安全的，操作系统会完成后面几步，保证数据最终会落到磁盘上。
 当系统断电，这时候上面5项中提到的所有缓存都会失效，并且数据库和操作系统都会停止工作，数据都会丢失，只有当数据在完成第5步后，机器断电才能保证数据不丢失。
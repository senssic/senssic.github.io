---
title: temp
date: 2021年03月03日22:28:28
tags: [杂项,记录]
copyright: true
---

[TOC]

# 0.windows脚本

## 0.0 windows关于端口查询和自启动目录

```shell
# 查看被占用的端口的进程
netstat -aon|findstr "8081"
#杀死进程PID以及子进程
taskkill /T /F /PID 9088
#自启动脚本的.vbs文件不弹框
set ws=WScript.CreateObject("WScript.Shell")
ws.Run "C:\start\bat-start.bat",0
#将上面的代码文本编辑重命名.vbs文件放到下面的自启动目录
C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp
```

# 1.linux脚本

## 1.1 hexo一键执行脚本

```shell
#!/bin/sh
nowdate=$(date)
echo ${nowdate}

cd /Users/senssic/work/mkdown/githublog/senssic
hexo clean
hexo g
hexo d
cd ./source/_posts/senssic.github.io
git pull
git add .
git commit -m 'updated:'$(date +%y年%m月%d日%H时%M分)
git push
cd /Users/senssic/work/mkdown/githublog
```

## 1.2 使用阿里源

```shell
yum install -y wget
rm -rf /etc/yum.repos.d/*.repo
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
sed -i '/aliyuncs/d' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/$releasever/7/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i '/aliyuncs/d' /etc/yum.repos.d/epel.repo
yum clean all
yum makecache fast
```

## 1.3 linux操作系统相关

1. 设置hostname名称
   sudo hostnamectl set-hostname <newhostname>

2. 查看磁盘

   lsblk

3. 新增磁盘进行分区

   ```shell
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
   ```

4. tcpdump的命令使用

   ```shell
   #详细输出且目标端host为10.19.146.223且目标端端口为28201 且网卡为ens160
   tcpdump -s 0 -l -w - dst 10.19.146.223 and port 28201 -i ens160|strings > tcpdump.txt
   ```

## 1.4 linux的初始化优化

```shell
# 1.设置主机名称
hostnamectl set-hostname xxx # 将 xxx 替换为当前主机名
# 2.设置host
cat >> /etc/hosts <<EOF
172.27.138.251 xxx-01
172.27.137.229 xxx-02
172.27.138.239 xxx-03
EOF
#3.添加节点信任关系
ssh-keygen -t rsa 
ssh-copy-id root@xxx-01
ssh-copy-id root@xxx-02
ssh-copy-id root@xxx-03
#4.安装基础依赖
yum install -y epel-release
yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git
#5.关闭防火墙
systemctl stop firewalld
systemctl disable firewalld
iptables -F && iptables -X && iptables -F -t nat && iptables -X -t nat
iptables -P FORWARD ACCEPT
#6.关闭 swap 分区
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab 
#7.关闭 SELinux
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
#8.优化内核参数
cat > temp.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.tcp_tw_recycle=0
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv4.neigh.default.gc_thresh1=4096
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF
cp temp.conf  /etc/sysctl.d/temp.conf
sysctl -p /etc/sysctl.d/temp.conf
#9.设置系统时区
timedatectl set-timezone Asia/Shanghai
#10.设置系统时钟同步
systemctl enable chronyd
systemctl start chronyd
#11.关闭无关的服务
systemctl stop postfix && systemctl disable postfix
#12.升级内核
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
# 安装完成后检查 /boot/grub2/grub.cfg 中对应内核 menuentry 中是否包含 initrd16 配置，如果没有，再安装一次！
yum --enablerepo=elrepo-kernel install -y kernel-lt
# 设置开机从新内核启动
grub2-set-default 0
sync
reboot
#安装docker
curl -sSL https://get.daocloud.io/docker | sh
```



# 2.虚拟机相关

## 2.1 virtual Boxs使用virtual host和nat网络固定ip

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
> 2.创建host-noly网络并选择选择准虚拟化网络(virtio-net),混杂模式拒绝
>
> **如果无法自动获取net和host-noly的ip,到/etc/sysconfig/network-scripts/目录下将这两个网卡的配置(ifcfg-xxx)删除然后重启**

## 2.2 桥接网络虚拟机无法自动获取ip

dhclient 网卡 -v

## 2.3 virtual Boxs设置已存在的硬盘的大小

**C:\Program Files\Oracle\VirtualBox\VBoxManage.exe modifyhd E:\vribox\k8s-temp\k8s-temp-disk1.vdi --resize 512000**

## 2.4 主盘扩容(/dev/mapper/centos-root 空间不足)

```shell
ls  /dev/sd*  #使用fdisk分区然后找一块空的分区
pvcreate /dev/sda3 #使用空的分区创建pv
vgs  #先使用vgs查看vg组大小
vgextend centos /dev/sda3 #扩展vg
vgs  #再查看一下vg组大小，看是否发生变化
lvs #查看lv大小,虽然我们把vg扩展了，但是lv还没有扩展
lvextend -L +20G /dev/mapper/centos-root #扩展lv,使用lvextend
xfs_growfs /dev/mapper/centos-root #命令使系统重新读取大小
df -h  #查看磁盘是否成功变化大小
```

# 3.数据库相关

## 3.1 mysql数据库

1. 重置root密码
   update user set authentication_string = password(‘123456’), password_expired = ‘N’, password_last_changed = now() where user = ‘root’;

2. 刷新权限

   flush privileges

# 4.容器相关

## 4.1 命令相关

```shell
1.列出所有的容器 ID
docker ps -aq
2.停止所有的容器
docker stop $(docker ps -aq)
3.删除所有的容器
docker rm $(docker ps -aq)
或
docker container prune -f
4.删除所有镜像
docker rmi $(docker images -q)
或
docker image prune -f -a
5.删除所有网络
docker network prune -f -a
6.复制文件
docker cp mycontainer:/opt/file.txt /opt/local/
docker cp /opt/local/file.txt mycontainer:/opt/
7.查看镜像的启动命令
alias runlike="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock assaflavie/runlike"
runlike -p 容器
8.查看镜像的构建Dockerfile(大致)
alias whaler="docker run -t --rm -v /var/run/docker.sock:/var/run/docker.sock:ro pegleg/whaler"
whaler -sV=1.36  容器
9.调试k8s的pod容器
#如果是私有仓库需要自己将debug-agent:v0.1.1 和 nicolaka/netshoot:latest push到私有仓库,docker tag,docker push
kubectl-debug -n dev pod-xxx --agentless=true --port-forward=true --agent-image=aylei/debug-agent:v0.1.1

```

## 4.2 安装docker和minikube

```shell
#1.创建非root用户
adduser test
passwd  test
#创建docker组
sudo groupadd docker
#将您的用户添加到该docker组
sudo usermod -aG docker test
#在Linux上，运行以下命令来激活对组的更改
newgrp docker
#2.安装docker
curl -fsSL https://get.docker.com | bash -s docker --mirror aliyun
#3.安装kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod a+x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
#4.安装minikube
curl -Lo minikube https://kubernetes.oss-cn-hangzhou.aliyuncs.com/minikube/releases/v1.20.0/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
#5.多节点启动
##创建主集群(默认Profile为minikube,可以加 -p 创建不通的k8s集群)
minikube start --force
##增加节点
minikube node add
##查看节点
minikube node list
##启动主节点仪表盘
minikube dashboard
##删除集群
minikube delete
```

## 4.3 安装jenkins

```shell
docker pull jenkins/jenkins
#挂载配置文件
mkdir -p /var/jenkins_mount && chmod 777 /var/jenkins_mount
#启动Jenkins端口为10240
docker run -d -p 10240:8080 -p 10241:50000 -v /var/jenkins_mount:/var/jenkins_home -v /etc/localtime:/etc/localtime --name myjenkins jenkins/jenkins
# 清华大学官方镜像：https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json
vi  hudson.model.UpdateCenter.xml
```

## 4.4 自定义jenkins的镜像

当前目录下存在:  config  Dockerfile  glibc-2.23-r3.apk  kubectl  settings.xml 文件

```shell
FROM jenkins/jenkins:alpine
LABEL auth="qisensen"

USER root

ARG MAVEN_VERSION=3.6.3
ARG MAVEN_SHA=fae9c12b570c3ba18116a4e26ea524b29f7279c17cbaadc3326ca72927368924d9131d11b9e851b8dc9162228b6fdea955446be41207a5cfc61283dd8a561d2f
ARG MAVEN_BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN echo "https://mirrors.aliyun.com/alpine/v3.8/main/" > /etc/apk/repositories \
  && echo "https://mirrors.aliyun.com/alpine/v3.8/community/" >> /etc/apk/repositories \
  && apk add --no-cache curl  ca-certificates openrc tar procps tzdata shadow docker \
  && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo Asia/Shanghai > /etc/timezone \
  && mkdir -p /usr/share/maven /usr/share/maven/ref/repository \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${MAVEN_BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn \
  && usermod -aG 999 jenkins \
  && chown 1000:1000 /usr/share/maven/ref/repository \
  && apk del tzdata shadow tar && rc-update add docker boot && mkdir -p ~/.kube/
COPY kubectl /usr/local/bin/
COPY config ~/.kube/
ENV MAVEN_HOME /usr/share/maven
ENV KUBECONFIG ~/.kube/config
VOLUME /usr/share/maven/ref/repository

COPY settings.xml /usr/share/maven/conf/settings.xml
```

执行容器命令启动

```shell
docker run -d -p 10240:8080 -p 10241:50000 -v /root/test/jenkins:/var/jenkins_home -v /etc/localtime:/etc/localtime -v "/var/run/docker.sock:/var/run/docker.sock:rw"  --name myjenkins f7b60faddb9e
```



# 5.大数据相关

## 5.1 kafka相关
```shell
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
```

## 5.2 impala相关
 ```shell
 常用修改操作: https://www.cnblogs.com/yhason/p/4724987.html
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
 ```

## 5.3 hdfs相关

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
| -chown         | -chown [-R] [属主]] 路径                                     | 修改属主                                                     | `hadoop fs -chown -R hadoop0 /input`              |
| -chgrp         | -chgrp [-R] 属组名称 路径                                    | 修改属组                                                     | `hadoop fs -chgrp -R root /flume`                 |
| -help          | -help [命令选项]                                             | 查看帮助                                                     | `hadoop fs -help`                                 |

# 6.Java相关

## 6.1 maven插件maven-shade-plugin支持将开源包直接改package名称解决类冲突

### 6.1.1 排除不使用的类

```xml
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-shade-plugin</artifactId>
        <version>3.1.1</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>shade</goal>
            </goals>
            <configuration>
              <minimizeJar>true</minimizeJar>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
```

### 6.1.2 将依赖的类重命名并打包进来 （隔离方案）

```xml
<!--
将“org.codehaus.plexus.util”重命名为“org.shaded.plexus.util”，原始jar包中的“org.codehaus.plexus.util.xml.Xpp3Dom”和“org.codehaus.plexus.util.xml.pull”不会被重命名到目的包中；
-->
<build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-shade-plugin</artifactId>
        <version>3.1.1</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals>
              <goal>shade</goal>
            </goals>
            <configuration>
              <relocations>
                <relocation>
                  <pattern>org.codehaus.plexus.util</pattern>
                  <shadedPattern>org.shaded.plexus.util</shadedPattern>
                  <excludes>
                    <exclude>org.codehaus.plexus.util.xml.Xpp3Dom</exclude>
                    <exclude>org.codehaus.plexus.util.xml.pull.*</exclude>
                  </excludes>
                </relocation>
              </relocations>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
```

### 6.1.3 Java执行单个编译类包括依赖

比如，需要执行Simple.class以及其依赖包xxxa.jar以及xxxb.jar

```java
java -cp .:xxxa.jar;d:\classes\*.jar  Simple
```

## 6.2 Java VisualVM 远程调试

1. 创建all.policy文件

   ```shell
   cat > all.policy <<EOF
   grant codebase "file:${java.home}/../lib/tools.jar" {
   permission java.security.AllPermission;
   };
   EOF
   ```

2. 服务器端启动

   ```shell
   jstatd -J-Djava.security.policy=all.policy
   ```

3. 打开 Java VisualVM  文件>添加远程主机   填入服务端IP

# 7.其他杂项相关

## 7.1 log日志最优格式化以及配置每日文件滚动:

```properties
log4j.rootLogger=INFO,stdout,fileAppender
log4j.appender.fileAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.fileAppender.DatePattern='.'yyyy-MM-dd
log4j.appender.fileAppender.File=/opt/config/fileAppender.log
log4j.appender.fileAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.fileAppender.layout.ConversionPattern=[%p][%t]%-d{yyyy-MM-dd HH:mm:ss.SSS}: (%c{1}.%M:line %L) - %m%n
```

## 7.2 关于断电

1.客户端向服务端发送写操作（数据在客户端的内存中）
2.数据库服务端接收到写请求的数据（数据在服务端的内存中）
3.服务端调用write这个系统调用，将数据往磁盘上写（数据在系统内存的缓冲区中）
4.操作系统将缓冲区中的数据转移到磁盘控制器上（数据在磁盘缓存中）
5.磁盘控制器将数据写到磁盘的物理介质中（数据真正落到磁盘上）

当数据库系统故障时，这时候系统内核还是正常运行的，此时只要执行完了第3步，数据就是安全的，操作系统会完成后面几步，保证数据最终会落到磁盘上。
 当系统断电，这时候上面5项中提到的所有缓存都会失效，并且数据库和操作系统都会停止工作，数据都会丢失，只有当数据在完成第5步后，机器断电才能保证数据不丢失。
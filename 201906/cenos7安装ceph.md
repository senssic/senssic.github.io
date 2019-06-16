```
title: centos7安装ceph
date: 2019年06月16日22:28:28
tags: [ceph]
copyright: true
```

### 节点信息配置

| 虚拟机名称  | 虚拟机ip       | 虚拟机应用             |
| :---------- | :------------- | :--------------------- |
| ceph-master | 192.168.56.101 | ceph-master/deployment |
| ceph-node-1 | 192.168.56.102 | ceph-node              |
| ceph-node-2 | 192.168.56.102 | ceph-node              |

### 环境准备

1.关闭防火墙(所有节点)

```shell
sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0
systemctl stop firewalld
systemctl disable firewalld
```

2.配置节点host解析设置hostname(所有节点)

```shell
192.168.56.101 ceph-master
192.168.56.102 ceph-node-1
192.168.56.103 ceph-node-2
#ceph-master
sudo hostnamectl set-hostname ceph-master
#ceph-node-
sudo hostnamectl set-hostname ceph-node-1
#ceph-node-2
sudo hostnamectl set-hostname ceph-node-2
```

3.安装依赖(所有节点)

```shell
yum install tree nmap sysstat lrzsz dos2unix wegt git net-tools -y
```

4.设置免密登录

1. 生成秘钥文件(ceph-master节点)

   ssh-keygen -t rsa

2. 拷贝秘钥文件

   ```shell
   ssh-copy-id root@ceph-master
   ssh-copy-id root@ceph-node-1
   ssh-copy-id root@ceph-node-2
   ```

5.配置NTP服务

1. 安装NTP服务(所有节点)

   yum install -y ntp

2. ceph-master节点配置

   1. 修改NTP配置文件/etc/ntp.conf

      ```shell
      vim /etc/ntp.conf
      #server 0.centos.pool.ntp.org iburst
      #server 1.centos.pool.ntp.org iburst
      #server 2.centos.pool.ntp.org iburst
      #server 3.centos.pool.ntp.org iburst
      #网关和广播地址
      restrict 192.168.56.1 mask 255.255.255.0 nomodify notrap
      server 127.127.1.0 minpoll 4
      fudge 127.127.1.0 stratum 0
      ```

   2. 修改配置文件/etc/ntp/step-tickers

      ```shell
      # vim /etc/ntp/step-tickers
      #0.centos.pool.ntp.org
      127.127.1.0
      ```

   3. 启动NTP服务并设置开机启动

      ```shell
      systemctl enable ntpd
      systemctl start ntpd
      ```

3. 所有OSD节点配置

   1. 修改NTP配置文件/etc/ntp.conf

      ```shell
      vim /etc/ntp.conf
      #server 0.centos.pool.ntp.org iburst
      #server 1.centos.pool.ntp.org iburst
      #server 2.centos.pool.ntp.org iburst
      #server 3.centos.pool.ntp.org iburst
      server 192.168.56.101
      ```

   2. 启动NTP服务并设置开机启动

      ```shell
      systemctl enable ntpd
      systemctl start ntpd
      ```

4. 验证NTP(所有节点)

   ```shell
   ntpstat
   ntpq -p
        remote           refid      st t when poll reach   delay   offset  jitter
   ==============================================================================
   *ceph-master     .LOCL.           1 u   16   64  377    0.269    0.032   0.269
   
   ```

### 安装ceph

1.更新系统源(所有节点)

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

2.安装ceph-deploy和配置ceph集群(master节点执行)

1. 安装ceph-deploy

   ```shell
   yum install http://mirrors.163.com/ceph/rpm-jewel/el7/noarch/ceph-deploy-1.5.38-0.noarch.rpm
   ```

2. 创建ceph集群

   ```shell
   eph-deploy new ceph-node-1 ceph-node-2 
   ```

3. 编辑ceph配置文件

   在global下添加一下配置

   ```shell
   vim ceph.conf 
   [global]
   mon_clock_drift_allowed = 5
   osd_journal_size = 20480
   #查看自己的网关地址
   public_network=192.168.56.1/24
   ```

4. 使用163源安装CEPH

   ```shell
   ceph-deploy install --release jewel --repo-url http://mirrors.163.com/ceph/rpm-jewel/el7 --gpg-url http://mirrors.163.com/ceph/keys/release.asc ceph-master ceph-node-1 ceph-node-2
   ```

5. 初始化节点

   ```shell
   ceph-deploy mon create-initial
   ```

6. 配置管理节点(ceph-master)

   ```shell
   ceph-deploy admin ceph-master
   chmod +r /etc/ceph/ceph.client.admin.keyring
   #查询集群状态
   ceph -s
   ```

### 创建和配置OSD存储节点

1.查看OSD节点的磁盘情况(找到要挂载的新磁盘)

```shell
eph-deploy disk list ceph-node-1
eph-deploy disk list ceph-node-2
```

2.创建并激活OSD节点

```shell
#重建分区表,磁盘存储要大些,如果比较小会报错
ceph-deploy disk zap ceph-node-1:/dev/sdb
ceph-deploy disk zap ceph-node-2:/dev/sdb
#创建OSD
ceph-deploy osd prepare ceph-node-1:/dev/sdb
ceph-deploy osd prepare ceph-node-2:/dev/sdb
#激活若激活失败报:Cannot discover filesystem type 请在OSD执行激活后执行ceph-disk  activate-all
ceph-deploy osd activate ceph-node-1:/dev/sdb
ceph-deploy osd activate ceph-node-2:/dev/sdb
#查看是否激活挂载成功
fdisk -l /dev/sdb
磁盘 /dev/sdb：1099.5 GB, 1099511627776 字节，2147483648 个扇区
Units = 扇区 of 1 * 512 = 512 bytes
扇区大小(逻辑/物理)：512 字节 / 512 字节
I/O 大小(最小/最佳)：512 字节 / 512 字节
磁盘标签类型：gpt
Disk identifier: AA34481A-A35C-4CB1-BB5E-9D334594D67C
#         Start          End    Size  Type            Name
 1     41945088   2147483614   1004G  Ceph OSD        ceph data
 2         2048     41945087     20G  Ceph Journal    ceph journal
#查看ceph的状态
ceph health
#将配置拷贝到其他节点
ceph-deploy --overwrite-conf admin ceph-master ceph-node-1 ceph-node-2
```

### 部署时常用命令

```
#若部署出现问题可以清空一切重新开始部署
#安装包也清除
ceph-deploy purge ceph-master ceph-node-1 ceph-node-2
ceph-deploy purgedata ceph-master ceph-node-1 ceph-node-2
ceph-deploy forgetkeys

#需要用命令进行服务的启动和关闭等
#监控相关
systemctl start ceph-mon.target
systemctl stop ceph-mon.target
#osd相关
systemctl start ceph-osd.target
systemctl stop ceph-osd.target
#ceph相关
systemctl start ceph.target
systemctl stop ceph.target

#设置开机启动
systemctl enable ceph-mon.target
systemctl enable ceph-osd.target
systemctl enable ceph.target

#验证ceph安装是否成功
#创建一个测试文件
echo "hello liberalman" > testfile.txt
#创建一个pool
rados mkpool data
#将文件写入pool
rados put test-object-1 testfile.txt --pool=data
#查看文件是否存在于pool中
rados -p data ls
#确定文件的位置
ceph osd map data test-object-1
#从pool中读取文件
rados get test-object-1 --pool=data myfile
#查看读取的文件是否和之前的一样
cat myfile
#从pool移除文件
rados rm test-object-1 --pool=data

#查看状态
ceph -s
ceph osd tree
```



### 默认相关文件地址

- 配置文件：默认 /etc/ceph/ceph.conf
- 日志文件：默认 /var/log/ceph
- 运行时文件:默认 /var/run/ceph

每个进程的管理套接字位置：/var/run/ceph/cluster-name.asok

使用管理套接字查看osd.0的运行时配置信息：

```shell
$ ceph --admin-daemon /var/run/ceph/ceph-osd.0.asok config show | less
```

集群启动后，每个守护进程从配置文件 /etc/ceph/ceph.conf中查看配置信息

```properties
[ global ]
#该配置下设置应用于所有ceph守护进程
[ osd ]
#该配置下设置应用于所有osd守护进程
#或者重写global配置
[ osd.0 ]
#该配置设置应用于osd 0进程，或者重写前面配置
[ mon ]
#该配置应用于所有监视器进程
[ mds ]
#该配置应用于所有元数据服务进程
```

其他相关

```
#查看pool类型 默认rbd
ceph osd pool ls
#获取rbd大小
ceph osd pool get rbd size
#设置rbd大小
ceph osd pool set rbd size 3
ceph osd pool set rbd min_size 3
```



[centos 7.4安装ceph集群](https://www.jianshu.com/p/26829d796064)
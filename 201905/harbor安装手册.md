---
title: harbor安装教程
date: 2019年05月20日21:01:43
tags: [harbor]
categories: [harbor]
---



## 安装docker以及docker-compose

```shell
yum update -y
yum -y install docker 
#临时关闭selinux
setenforce 0 
#关闭防火墙
systemctl stop firewalld 
systemctl disable firewalld.service
#关闭selinux
vi /etc/sysconfig/selinux
#修改SELINUX=enforcing 为SELINUX=disabled
setenforce 0

systemctl start docker

#安装：docker-compose
yum install -y epel-release
yum install -y python-pip
#如有报错更新pip
#python -m pip install --upgrade pip
pip install docker-compose 
docker --version 
docker-compose --version
```



## 下载harbor并生成证书

```shell
wget https://storage.googleapis.com/harbor-releases/release-1.7.0/harbor-offline-installer-v1.7.4.tgz
tar -xvf harbor-offline-installer-v1.7.4.tgz
cd harbor
```



## 生成证书

```shell
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/harbor.key -x509 -days 365 -out certs/harbor.crt 
Generating a 4096 bit RSA private key
....++
..............................................................................................................................................................................++
writing new private key to 'certs/harbor.key'
-----
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:
string is too long, it needs to be less than  2 bytes long
Country Name (2 letter code) [XX]:
State or Province Name (full name) []:
Locality Name (eg, city) [Default City]:
Organization Name (eg, company) [Default Company Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (eg, your name or your server's hostname) []:aliyun.harbor
Email Address []:
[root@senssic harbor]# 
```

注意:Common Name (eg, your name or your server's hostname)为仓库的域名.

在当前目录的certs中会生成两个证书文件

**harbor.crt**  #**客户端需要(客户端可以是远程客户端)**,需要将此证书复制到/etc/docker/certs.d/aliyun.harbor/harbor.crt 路径,目录不存在则需要自己创建

**harbor.key**



## 配置harbor的配置文件

编辑当前目录的**harbor.cfg**文件修改如下配置项:

```properties
hostname = aliyun.harbor
ui_url_protocol = https
customize_crt = off
#刚才生成certs的路径,确保能读取到harbor.crt和harbor.key
ssl_cert = /root/harbor/certs/harbor.crt
ssl_cert_key = /root/harbor/certs/harbor.key
```

执行预安装命令***./prepare***

```shell
[root@senssic harbor]# ./prepare 
loaded secret from file: /data/secretkey
Generated configuration file: ./common/config/nginx/nginx.conf
Generated configuration file: ./common/config/adminserver/env
Generated configuration file: ./common/config/core/env
Generated configuration file: ./common/config/registry/config.yml
Generated configuration file: ./common/config/db/env
Generated configuration file: ./common/config/jobservice/env
Generated configuration file: ./common/config/jobservice/config.yml
Generated configuration file: ./common/config/log/logrotate.conf
Generated configuration file: ./common/config/registryctl/env
Generated configuration file: ./common/config/core/app.conf
Copied configuration file: ./common/config/coreprivate_key.pem
Copied configuration file: ./common/config/registryroot.crt
The configuration files are ready, please use docker-compose to start the service.
```

使私有仓库同时支持mirro功能,编辑common/config/registry/config.yml追加

```yml
proxy:
  remoteurl: https://registry-1.docker.io
```



配置完毕执行安装命令***./install.sh***



## 客户端拉取上传镜像

1.将上述生成的***harbor.crt***放置到客户端所在机器的***/etc/docker/certs.d/aliyun.harbor/*** 目录下,若目录不存在则创建.

```shell
mkdir -p /etc/docker/certs.d/aliyun.harbor/
cp certs/harbor.crt /etc/docker/certs.d/aliyun.harbor/
```

2.拉取测试镜像,生成tag,登陆私有镜像仓库并上传镜像

- 增加对于aliyun.harbor的hosts解析

  编辑**/etc/hosts**  追加 **私有仓库ip aliyun.harbor**

- 登陆私有仓库输入用户名密码,可以在上面的**harbor.cfg**设置

  ```shell
  [root@senssic harbor]# docker login aliyun.harbor
  Username: admin
  Password: 
  WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
  Configure a credential helper to remove this warning. See
  https://docs.docker.com/engine/reference/commandline/login/#credentials-store
  
  Login Succeeded
  [root@senssic harbor]# 
  ```

- 在harbor管理界面新建项目,项目名为test

- 给已存在的镜像打标签(标签前缀即为私有仓库域名,第层为上面一步创建的项目名称 **test**),并推送到仓库

  ```shell
  #aliyun.harbor/test/showdoc中的test需要在harbor界面管理中创建,也可直接使用默认的library
  docker tag registry.docker-cn.com/star7th/showdoc aliyun.harbor/test/showdoc:1.0.0
  #推送到远端私有仓库
  docker push aliyun.harbor/test/showdoc:1.0.0
  ```

- 拉取上传的镜像文件

  ```shell
  [root@cjvm101 aliyun.harbor]# docker login aliyun.harbor
  Username: admin
  Password: 
  WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
  Configure a credential helper to remove this warning. See
  https://docs.docker.com/engine/reference/commandline/login/#credentials-store
  
  Login Succeeded
  [root@cjvm101 aliyun.harbor]# docker pull aliyun.harbor/test/showdoc:1.0.0
  1.0.0: Pulling from test/showdoc
  ff3a5c916c92: Pull complete 
  2ca736d3a2d3: Pull complete 
  ed01bffbd8ba: Pull complete 
  86a241b7142f: Pull complete 
  2ffa2200859b: Downloading [=======> 
  ```

## 安装过程中常用命令

```shell
#docker加载配置文件
systemctl daemon-reload
service docker restart

#在harbor安装根目录下
#停止运行容器
docker-compose stop
#删除容器
docker-compose rm
#启动harbor
./install.sh
```
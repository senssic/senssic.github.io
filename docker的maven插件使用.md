---
title: docker的maven插件使用
date: 2019-01-06 17:57:07
tags: [maven,docker]
categories: [插件]
---



# 搭建docker私有仓库

### 创建私有仓库

- 拉取仓库镜像

  docker pull registry

- 启动仓库镜像

  docker run ‐di ‐‐name=registry ‐p 5000:5000 registry

- 修改daemon.json,让docker信任私有仓库地址

  vi /etc/docker/daemon.json

  添加

  `{"insecure‐registries":["127.0.0.1:5000"]}`

- 重启docker服务

  systemctl restart docker



### 镜像上传到私有仓库

为了验证私有仓库搭建以及能正常上传到私有仓库,新建tag并尝试push镜像

- 标记此镜像为私有仓库的镜像

  docker tag java:8 127.0.0.1:5000/jdk1.8

  注意:java:8为本身已经存在的镜像

- 再次启动私服容器

  docker start registry

- 上传标记的镜像

  docker push 127.0.0.1:5000/jdk1.8

  ![上传标记的镜像](maven的docker插件_01.png)

### docker的maven插件使用

### 生成TLS认证远程访问 Docker

需要生成三种证书类型:

- CA 证书用来生成客户端和服务端证书
- 远端Docker使用的客户端生疏
- 服务端使用的Docker daemon证书

#### 服务端配置

```
# 生成 CA 私钥

$ openssl genrsa -aes256 -out ca-key.pem 4096

# 需要输入两次密码(自定义)

# 生成 CA 公钥

$ openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem

# 输入上一步中设置的密码，然后需要填写一些信息

# 下面是服务器证书生成

# 生成服务器私钥

$ openssl genrsa -out server-key.pem 4096

# 用私钥生成证书请求文件

$ openssl req -subj "/CN=localhost" -sha256 -new -key server-key.pem -out server.csr

$ echo subjectAltName = DNS:localhost,DNS:www.khs1994.com,DNS:tencent,IP:192.168.199.100,IP:192.168.57.110,IP:127.0.0.1 >> extfile.cnf

# 允许服务端哪些 IP 或 host 能被客户端连接，下文会进行测试。

# DNS 我也不是很理解，这里配置 localhost ，公共 DNS 解析的域名，/etc/hosts 文件中的列表进行测试。

$ echo extendedKeyUsage = serverAuth >> extfile.cnf

# 用 CA 来签署证书

$ openssl x509 -req -days 365 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out server-cert.pem -extfile extfile.cnf

# 再次输入第一步设置的密码

# 下面是客户端证书文件生成

# 生成客户端私钥

$ openssl genrsa -out key.pem 4096

# 用私钥生成证书请求文件  

$ openssl req -subj '/CN=client' -new -key key.pem -out client.csr

$ echo extendedKeyUsage = clientAuth >> extfile.cnf

# 用 CA 来签署证书

$ openssl x509 -req -days 365 -sha256 -in client.csr -CA ca.pem -CAkey ca-key.pem \
  -CAcreateserial -out cert.pem -extfile extfile.cnf

# 再次输入第一步设置的密码

# 删除文件，更改文件权限

$ rm -v client.csr server.csr

$ chmod -v 0400 ca-key.pem key.pem server-key.pem

$ chmod -v 0444 ca.pem server-cert.pem cert.pem
```

把 `ca.pem` `server-cert.pem` `server-key.pem` 三个文件移动到 `/etc/docker/` 文件夹中。

#### 在远端配置Docker

配置/etc/docker/daemon.json文件如下,注意,镜像地址与本文无关,可不配置

```
"insecure-registries":["127.0.0.1:5000"],
  "tlsverify": true,
  "tlscacert": "/etc/docker/ca.pem",
  "tlscert": "/etc/docker/server-cert.pem",
  "tlskey": "/etc/docker/server-key.pem",
  "hosts": ["tcp://0.0.0.0:2376","unix:///var/run/docker.sock"]
}
```

### CoreOS 官方文档的方法

首先需要修改 `/etc/systemd/system/docker-tcp.socket` 文件内容

```
ListenStream=2375

# 修改为

ListenStream=2376
```

重新启动服务器

```
$ sudo systemctl daemon-reload
$ sudo systemctl stop docker
$ sudo systemctl restart docker-tcp.socket
$ sudo systemctl restart docker
```

将 `ca.pem` `cert.pem` `key.pem`下载到客户端,放置到~/.docker目录下

运行测试命令

docker --tlsverify -H=tcp://207.246.117.90:2376 info

![成功返回docker信息](maven的docker插件_02.png)

### Maven插件自动部署步

```xml
<plugin>
    <groupId>com.spotify</groupId>
    <artifactId>docker-maven-plugin</artifactId>
    <version>0.4.13</version>
    <configuration>
        <imageName>127.0.0.1:5000/${docker.image.prefix}/${project.artifactId}
        </imageName>
        <baseImage>java:8</baseImage>
        <entryPoint>["java", "-jar", "/${project.build.finalName}.jar"]</entryPoint>
       <!--<dockerDirectory>${project.basedir}/src/main/docker</dockerDirectory>-->
        <resources>
            <resource>
                <targetPath>/</targetPath>
                <directory>${project.build.directory}</directory>
                <include>${project.build.finalName}.jar</include>
            </resource>
        </resources>
        <dockerHost>http://207.246.117.90:2375</dockerHost>
        <dockerCertPath>/Users/senssic/.docker/</dockerCertPath>
    </configuration>
</plugin>
```




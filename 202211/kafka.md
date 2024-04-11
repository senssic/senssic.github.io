---
title: kafka相关
date: 2022年01月26日
tags: [kafka]
categories: [kafka]
---

 

# Ⅰ kafka配置SASL认证

https://blog.csdn.net/weixin_38251332/article/details/105637628

> #### kafka安全机制
>
> kakfa 的安全机制主要分为两部分：
>
> - 身份认证（Authentication）： 对客户端的身份进行认证
> - 权限控制（Authorization）： 对topic级别的权限进行控制
>
> kafka 目前支持 SSL，SASL(Kerberos)，SASL（PLAIN) 三种认证机制。 这里只讲解最容易实现的SASL（PLAIN）机制，值的注意的是SASL(PLAIN)是通过明文传输用户名和密码的。因此在不安全的网络环境下需要建立在TLS安全层之上。

kafka的service配置SASL用户名密码

1.在配置文件所在目录添加jaas的文件 **kafka_server_jaas.conf**

```properties
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin-123"
    user_admin="admin-123";
};

```

2.修改kafka服务配置文件 server.properties 增加

```properties
#追加如下内容
inter.broker.listener.name=INTERNAL
#inter.broker.listener.name=SASL_PLAINTEXT
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN
authorizer.class.name = kafka.security.auth.SimpleAclAuthorizer
super.users=User:admin
```

3.在服务启动脚本增加对于认证的配置**kafka-server-start.sh**

```shell
#增加加载jaas的配置，替换上述文件的最后两行
export KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kafka_server_jaas.conf"
exec $base_dir/kafka-run-class.sh $EXTRA_ARGS kafka.Kafka "$@"
```

若此时客户端想链接需要配置如下

1.假设你有一个用户名为`user`，密码为`password`，你可以将这些凭据添加到命令中，如下所示：

```shell
kafka-consumer-groups.bat --bootstrap-server INTERNAL://kafka.test.cn:9092 --command-config client-sasl.properties --list
```

2.在这里，`client-sasl.properties`文件是包含认证凭据信息的配置文件，其内容可能类似于：

```shell
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="user" password="password";
```

你需要根据你的实际情况修改用户名和密码。

然后执行就会自动认证链接上kafka了



3.Java客户端链接,无配置文件模式

```java
props.put("security.protocol", "SASL_PLAINTEXT");
props.put("sasl.mechanism", "PLAIN");
props.put("sasl.jaas.config", "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"admin\" password=\"adminpasswd\";");
```

springboot链接模式

```yaml
spring:
  kafka:
    bootstrap-servers: kafka.test.cn:443
    producer:
      retries: 0
      batch-size: 16384
      buffer-memory: 33554432
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
      properties:
        sasl.mechanism: PLAIN
        security.protocol: SASL_PLAINTEXT
    jaas:
      enabled: true
      loginModule: org.apache.kafka.common.security.plain.PlainLoginModule
      controlFlag: REQUIRED
      options:
        username: admin
        password: admin-123
```



# Ⅱ kafka 权限控制的配置(ACL控制)

> 使用非超级用户(即不在*super.users=*配置的)用户之前先需要ACL授权,超级用户不受ACL权限控制。

权限的内容

| 权限     | 说明          |
| -------- | ------------- |
| READ     | 读取topic     |
| WRITE    | 写入topic     |
| DELETE   | 删除topic     |
| CREATE   | 创建topic     |
| ALTER    | 修改topic     |
| DESCRIBE | 获取topic信息 |

kafka提供命令行工具来添加和修改acl。该命令行工具位于 kafka 目录 ==bin/kafka-acls.sh==

| Option                 | Description                                                  | Default                                 | Option type   |
| ---------------------- | ------------------------------------------------------------ | --------------------------------------- | ------------- |
| –add                   | Indicates to the script that user is trying to add an acl.   |                                         | Action        |
| –remove                | Indicates to the script that user is trying to remove an acl. |                                         | Action        |
| –list                  | Indicates to the script that user is trying to list acts.    |                                         | Action        |
| –authorizer            | Fully qualified class name of the authorizer.                | kafka.security.auth.SimpleAclAuthorizer | Configuration |
| –authorizer-properties | key=val pairs that will be passed to authorizer for initialization. For the default authorizer the example values are: zookeeper.connect=localhost:2181 |                                         | Configuration |
| –cluster               | Specifies cluster as resource.                               |                                         | Resource      |
| –topic [topic-name]    | Specifies the topic as resource.                             |                                         | Resource      |
| –group [group-name]    | Specifies the consumer-group as resource.                    |                                         | Resource      |
| –allow-principal       | Principal is in PrincipalType:name format that will be added to ACL with Allow permission. You can specify multiple –allow-principal in a single command. |                                         | Principal     |
| –deny-principal        | Principal is in PrincipalType:name format that will be added to ACL with Deny permission. You can specify multiple –deny-principal in a single command. |                                         | Principal     |
| –allow-host            | IP address from which principals listed in –allow-principal will have access. if –allow-principal is specified defaults to * which translates to “all hosts” |                                         | Host          |
| –deny-host             | IP address from which principals listed in –deny-principal will be denied access. if –deny-principal is specified defaults to * which translates to “all hosts” |                                         | Host          |
| –operation             | Operation that will be allowed or denied. Valid values are : Read, Write, Create, Delete, Alter, Describe, ClusterAction, All | All                                     | Operation     |
| –producer              | Convenience option to add/remove acls for producer role. This will generate acls that allows WRITE, DESCRIBE on topic and CREATE on cluster. |                                         | Convenience   |
| –consumer              | Convenience option to add/remove acls for consumer role. This will generate acls that allows READ, DESCRIBE on topic and READ on consumer-group. |                                         | Convenience   |

配置例子： add 操作

```shell
# 为用户 alice 在 test（topic）上添加读写的权限
bin/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 --add --allow-principal User:alice --operation Read --operation Write --topic test
```

list 操作

```shell
# 列出 topic 为 test 的所有权限账户
bin/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 --list --topic test
```

remove 操作

```shell
# 移除 Alice 在 test(topic) 上的读写权限
bin/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 --remove --allow-principal User:Alice --operation Read --operation Write --topic test
```

producer 和 consumer 的操作

```shell
# producer
bin/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 --add --allow-principal User:alice --producer --topic test
#consumer
bin/kafka-acls.sh --authorizer-properties zookeeper.connect=localhost:2181 --add --allow-principal User:alice --consumer --topic test --group test-group
```



# 三，kafka监听地址配置 

https://juejin.cn/post/6893410969611927566

  kafka的监听主要是对两个参数进行配置`listeners`和`advertised.listeners`,关于这两个参数总结一句话就是

> 1. listeners 指明 kafka 当前节点监听本机的哪个网卡
> 2. advertised.listeners 指明客户端通过哪个 ip 可以访问到当前节点

​       建议在配，监听地址的时候通过域名配置，这样可以通过配置不同的host解决基于NAT暴露给外部的情况。比如，只用listeners ，采用域名的方式，内部hosts配置kafka本机，外部客户端链接的时候也是同样的域名但是ip配置为外网的ip，由于端口是外网ip端口映射到这个内网端口地址上，所以直接可以请求成功，效果类似于内网穿透。

效果等同如下:

内网ip: 192.168.0.213,  外网ip: 101.89.163.9 但是无网卡，SASL认证

```shell
listener.security.protocol.map=INTERNAL:SASL_PLAINTEXT,EXTERNAL:SASL_PLAINTEXT
listeners=INTERNAL://192.168.0.213:19092,EXTERNAL://192.168.0.213:443
advertised.listeners=INTERNAL://192.168.0.213:19092,EXTERNAL://101.89.163.9:443
inter.broker.listener.name=INTERNAL
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN
authorizer.class.name = kafka.security.auth.SimpleAclAuthorizer
super.users=User:admin
```




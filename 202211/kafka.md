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

①zookeeper配置SASL认证

vi /opt/kafka/config/zookeeper.properties

```shell
#追加如下内容
authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
requireClientAuthScheme=sasl
jaasLoginRenew=3600000
```

②创建zookeeper的jaas配置文件，zk_server_jaas.conf

vi /opt/kafka/config/zk_server_jaas.conf

```shell
Server {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="zk_cluster"
    password="zk_cluster_passwd"
    #急用户名为:kafka,密码为:zk_kafka_client_passwd
    user_kafka="zk_kafka_client_passwd";
};
```

③在zk的启动脚本增加变量，export EXTRA_ARGS="-Djava.security.auth.login.config=/opt/kafka/config/zk_server_jaas.conf"

vi /opt/kafka/bin/zookeeper-server-start.sh

```shell
…………
if [ "x$KAFKA_HEAP_OPTS" = "x" ]; then
    export KAFKA_HEAP_OPTS="-Xmx512M -Xms512M"
fi
#增加如下一行
export EXTRA_ARGS="-Djava.security.auth.login.config=/opt/kafka/config/zk_server_jaas.conf"
EXTRA_ARGS=${EXTRA_ARGS-'-name zookeeper -loggc'}
…………
```

④创建kafka的jaas配置文件，kafka_server_jaas.conf

vi /opt/kafka/config/kafka_server_jaas.conf

```properties
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin-juanwang2022"
    user_admin="admin-juanwang2022";
};
# 与kafka的配置用户名密码保持一致
Client{
 org.apache.kafka.common.security.plain.PlainLoginModule required
 username="kafka"
 password="zk_kafka_client_passwd";
};
```

⑤在kafka的启动脚本增加变量，export KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kafka_server_jaas.conf"

vi /opt/kafka/bin/kafka-run-class.sh

```shell
………………
# If Cygwin is detected, LOG_DIR is converted to Windows format.
(( CYGWIN )) && LOG_DIR=$(cygpath --path --mixed "${LOG_DIR}")
KAFKA_LOG4J_OPTS="-Dkafka.logs.dir=$LOG_DIR $KAFKA_LOG4J_OPTS"
# Generic jvm settings you want to add
# 增加如下一行
export KAFKA_OPTS="-Djava.security.auth.login.config=/opt/kafka/config/kafka_server_jaas.conf"
if [ -z "$KAFKA_OPTS" ]; then
  KAFKA_OPTS=""
fi
………………
```

⑥配置kafka的配置文件

vi /opt/kafka/config/server.properties

```shell
security.inter.broker.protocol=SASL_PLAINTEXT
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN
authorizer.class.name = kafka.security.auth.SimpleAclAuthorizer
#超级用户,即为kafka的jaas配置的用户,超级用户无需ACL认证，
super.users=User:admin
listeners=SASL_PLAINTEXT://kafka-single:9092
```

⑦重启kafka和zookeeper

⑧客户端访问方式

命令行消费者，生产者认证(拼接sasl认证)

```shell
#consumer
kafka-console-consumer.sh --bootstrap-server 10.194.202.17:8092 \
--consumer-property "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='admin' password='adminpasswd';" \
--consumer-property security.protocol=SASL_PLAINTEXT \
--consumer-property sasl.mechanism=PLAIN \
--consumer-property client.id=consumer_01 \
--topic test.1 \
--group c1
#producer
kafka-console-producer.sh --broker-list 10.194.202.17:8092 \
--consumer-property "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='admin' password='adminpasswd';" \
--consumer-property security.protocol=SASL_PLAINTEXT \
--consumer-property sasl.mechanism=PLAIN \
--consumer-property client.id=producer_01 \
--topic test.1
```

Java客户端链接,无配置文件模式

```java
props.put("security.protocol", "SASL_PLAINTEXT");
props.put("sasl.mechanism", "PLAIN");
props.put("sasl.jaas.config", "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"admin\" password=\"adminpasswd\";");
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

内网ip: 192.168.0.213,  外网ip: 101.89.163.9 但是无网卡

```shell
listener.security.protocol.map=INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT
listeners=INTERNAL://192.168.0.213:9092,EXTERNAL://192.168.0.213:19092
advertised.listeners=INTERNAL://192.168.0.213:9092,EXTERNAL://101.89.163.9:19092
inter.broker.listener.name=INTERNAL
```




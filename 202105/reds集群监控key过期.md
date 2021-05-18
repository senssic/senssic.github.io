---
title: redis集群监控key过期
date: 2021年5月18日
tags: [redis]
categories: [redis]
---

   工作中遇到需要监听redis过期时间,整理了一下redis集群过期监听的设置过程。注意key的监听比较消耗资源，测试完毕后记得将监听设置去除掉。

# 修改redis配置文件

​      集群的redis需要在每个集群redis配置文件中开启redis过期监听。将redis配置文件中的(redis.conf) **notify-keyspace-events**设置未**Ex**即可。所有集群的配置文件都需要更改。

​     ![redis配置文件](pic_01.png)

​       当然也可以不用重启redis动态更新redis的配置。因为我这边只是做测试使用，所以直接使用这种方式了，不用重启redis集群立即生效，每个redis集群节点都需要设置一下。

```shell
config set notify-keyspace-events Ex
# 查十分配置成功
config get notify-keyspace-events
```

关于**notify-keyspace-events** 配置含义可以参考下图

​     ![notify-keyspace-events参数](pic_02.png)

# 集成springboot

## 配置依赖

```xml
<dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>2.1.7.RELEASE</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>cn.hutool</groupId>
            <artifactId>hutool-all</artifactId>
            <version>5.6.4</version>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        <dependency>
            <groupId>redis.clients</groupId>
            <artifactId>jedis</artifactId>
        </dependency>
    </dependencies>
```

## 配置文件

```yaml
server:
  port: 8201
spring:
  redis:
    cluster:
      nodes: 10.11.136.121:7001,10.11.136.121:7002,10.11.136.122:7001,10.11.136.122:7002,10.11.136.123:7001,10.11.136.123:7002
```

## redis监听配置类

```java
@Configuration
@ConditionalOnClass({JedisConnection.class, RedisOperations.class, Jedis.class, MessageListener.class})
@AutoConfigureAfter({JacksonAutoConfiguration.class, RedisAutoConfiguration.class})
public class RedisAutoConfiguration {

    @Configuration
    public static class RedisStandAloneAutoConfiguration {
        @Bean
        public RedisMessageListenerContainer customizeRedisListenerContainer(
                RedisConnectionFactory redisConnectionFactory, MessageListener messageListener) {
            RedisMessageListenerContainer redisMessageListenerContainer = new RedisMessageListenerContainer();
            redisMessageListenerContainer.setConnectionFactory(redisConnectionFactory);
            redisMessageListenerContainer.addMessageListener(messageListener, new PatternTopic("__keyevent@0__:expired"));
            return redisMessageListenerContainer;
        }
    }


    @Configuration
    public static class RedisClusterAutoConfiguration {
        @Bean
        public RedisMessageListenerFactory redisMessageListenerFactory(BeanFactory beanFactory,
                                                                       RedisConnectionFactory redisConnectionFactory) {
            RedisMessageListenerFactory beans = new RedisMessageListenerFactory();
            beans.setBeanFactory(beanFactory);
            beans.setRedisConnectionFactory(redisConnectionFactory);
            return beans;
        }
    }
}
```

```java
public class RedisMessageListenerFactory implements BeanFactoryAware, ApplicationListener<ContextRefreshedEvent> {


    private DefaultListableBeanFactory beanFactory;

    private RedisConnectionFactory redisConnectionFactory;

    @Autowired
    private MessageListener messageListener;

    @Override
    public void setBeanFactory(BeanFactory beanFactory) throws BeansException {
        this.beanFactory = (DefaultListableBeanFactory) beanFactory;
    }

    public void setRedisConnectionFactory(RedisConnectionFactory redisConnectionFactory) {
        this.redisConnectionFactory = redisConnectionFactory;
    }

    @Override
    public void onApplicationEvent(ContextRefreshedEvent contextRefreshedEvent) {
        RedisClusterConnection redisClusterConnection = redisConnectionFactory.getClusterConnection();
        if (redisClusterConnection != null) {
            Iterable<RedisClusterNode> nodes = redisClusterConnection.clusterGetNodes();
            for (RedisClusterNode node : nodes) {
                if (node.isMaster()) {
                    System.out.println("获取到redis的master节点为[{}]" + node.toString());
                    String containerBeanName = "messageContainer" + node.hashCode();
                    if (beanFactory.containsBean(containerBeanName)) {
                        return;
                    }
                    JedisShardInfo jedisShardInfo = new JedisShardInfo(node.getHost(), node.getPort());
                    JedisConnectionFactory factory = new JedisConnectionFactory(jedisShardInfo);
                    BeanDefinitionBuilder containerBeanDefinitionBuilder = BeanDefinitionBuilder
                            .genericBeanDefinition(RedisMessageListenerContainer.class);
                    containerBeanDefinitionBuilder.addPropertyValue("connectionFactory", factory);
                    containerBeanDefinitionBuilder.setScope(BeanDefinition.SCOPE_SINGLETON);
                    containerBeanDefinitionBuilder.setLazyInit(false);
                    beanFactory.registerBeanDefinition(containerBeanName,
                            containerBeanDefinitionBuilder.getRawBeanDefinition());

                    RedisMessageListenerContainer container = beanFactory.getBean(containerBeanName,
                            RedisMessageListenerContainer.class);
                    String listenerBeanName = "messageListener" + node.hashCode();
                    if (beanFactory.containsBean(listenerBeanName)) {
                        return;
                    }
                    container.addMessageListener(messageListener, new PatternTopic("__keyevent@0__:expired"));
                    container.start();
                }
            }
        }
    }

}

```

## redis工具类

```java

@Component
public class RedisHelper {

    @Autowired
    private StringRedisTemplate stringRedisTemplate;

    /**
     * scan 实现
     *
     * @param pattern
     *         表达式
     * @param consumer
     *         对迭代到的key进行操作
     */
    public void scan(String pattern, Consumer<byte[]> consumer) {
        this.stringRedisTemplate.execute((RedisConnection connection) -> {
            try (Cursor<byte[]> cursor = connection.scan(ScanOptions.scanOptions().count(Long.MAX_VALUE).match(pattern).build())) {
                cursor.forEachRemaining(consumer);
                return null;
            } catch (IOException e) {
                e.printStackTrace();
                throw new RuntimeException(e);
            }
        });
    }

    /**
     * 获取符合条件的key
     *
     * @param pattern
     *         表达式
     * @return
     */
    public List<String> keys(String pattern) {
        List<String> keys = new ArrayList<>();
        this.scan(pattern, item -> {
            //符合条件的key
            String key = new String(item, StandardCharsets.UTF_8);
            keys.add(key);
        });
        return keys;
    }
}
```

## 监听过期

```java
@Component
public class KeyExpiredEventMessageListener implements MessageListener {

    @Override
    public void onMessage(Message message, byte[] pattern) {
        String expiredKey = message.toString();

        System.out.println(DateUtil.format(new Date(), DatePattern.CHINESE_DATE_TIME_PATTERN) + "======接收监听====" + expiredKey);
    }


}
```

## 运行主类

```java
@SpringBootApplication
@RestController
@EnableScheduling
public class RedisTestApplication {
    @Autowired
    private RedisHelper redisHelper;

    public static void main(String[] args) {
        SpringApplication.run(RedisTestApplication.class, args);
    }

    @Autowired
    protected StringRedisTemplate redisTemplate;

    @RequestMapping("/testRedis")
    public void testRedis() {
        redisHelper.scan("SECURE:*", bytes -> {
            String key = new String(bytes, StandardCharsets.UTF_8);
            System.out.println(DateUtil.format(new Date(), DatePattern.CHINESE_DATE_TIME_PATTERN) + " key: " + key + "   ===>   " + redisTemplate.getExpire(key, TimeUnit.SECONDS));
        });
    }

    @Scheduled(fixedRate = 30 * 60 * 1000)
    public void scheduler() {
        System.out.println("=========> start scan <=========");
        redisHelper.scan("SECURE:*", bytes -> {
            String key = new String(bytes, StandardCharsets.UTF_8);
            System.out.println(DateUtil.format(new Date(), DatePattern.CHINESE_DATE_TIME_PATTERN) + " key: " + key + "   ===>   " + redisTemplate.getExpire(key, TimeUnit.SECONDS));
        });
        System.out.println("=========> stop scan <=========");
    }
}
```


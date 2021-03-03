---
title: tk-mybatis的自定义Mapper实现原理
date: 2021年3月3日
tags: [mybatis]
categories: [mybatis]
---



# 1.环境版本

- spring-boot  2.1.7.RELEASE
- mapper-spring-boot-starter  2.1.5

# 2.基本原理

1. MappedStatement 

   MappedStatement维护了一条<select|update|delete|insert>节点的封装

2. SqlSource

   负责根据用户传递的parameterObject，**动态地生成SQL语句**，将信息封装到BoundSql对象中。

3. BoundSql

   示动态生成的SQL语句以及相应的参数信息

   当调用SqlSource的getBoundSql方法，传入的就是parameterMappings相对应的参数,最终生成BoundSql对象,有了BoundSql就可以执行sql语句了。

​          在 MyBatis 中，使用@SelectProvider 这种方式定义的方法，最终会构造成 ProviderSqlSource，ProviderSqlSource 是一种处于中间的 SqlSource，它本身不能作为最终执行时使用的 SqlSource，但是他会根据指定方法返回的 SQL 去构造一个可用于最后执行的 StaticSqlSource，StaticSqlSource的特点就是静态 SQL，支持在 SQL 中使用#{param} 方式的参数，但是不支持 <if>，<where> 等标签。

```java
public interface SelectMapper<T> {
    //使用mybatis提供的@SelectProvider注解
    @SelectProvider(type = BaseSelectProvider.class, method = "dynamicSQL")
    List<T> select(T record);
}
```

​         在 MyBatis 中，每一个方法（注解或 XML 方式）经过处理后，最终会构造成 MappedStatement 实例，这个对象包含了方法id（namespace+id）、结果映射、缓存配置、SqlSource 等信息，和 SQL 关系最紧密的是其中的 SqlSource，MyBatis 最终执行的 SQL 时就是通过这个接口的 getBoundSql 方法获取的。

​         针对不同的运行环境，需要用不同的方式去替换。当使用纯 MyBatis （没有Spring）方式运行时，替换很简单，因为会在系统中初始化 SqlSessionFactory，可以初始化的时候进行替换，这个时候也不会出现前面提到的问题。替换的方式也很简单，通过 SqlSessionFactory 可以得到 SqlSession，然后就能得到 Configuration，通过 configuration.getMappedStatements() 就能得到所有的 MappedStatement，循环判断其中的方法是否为通用接口提供的方法，如果是就按照前面的方式替换就可以了。

​           在使用 Spring 的情况下，以继承的方式重写了 MapperScannerConfigurer 和 MapperFactoryBean，在 Spring 调用 checkDaoConfig 的时候对 SqlSource 进行替换。在使用 Spring Boot 时，提供的 mapper-starter 中，直接注入 List<SqlSessionFactory> sqlSessionFactoryList 进行替换。


# 3.基于springboot版本的代码分析

​         tk.mybatis.spring.mapper.MapperFactoryBean为整个基于springboot加载的入口类。其继承的抽象类org.springframework.dao.support.DaoSupport实现了org.springframework.beans.factory.InitializingBean最终会执行到MapperFactoryBean的checkDaoConfig()方法。

```java
//位置tk.mybatis.spring.mapper.MapperFactoryBean,动态创建每个mapper的代理
protected void checkDaoConfig() {
        super.checkDaoConfig();
        Assert.notNull(this.mapperInterface, "Property 'mapperInterface' is required");
        Configuration configuration = this.getSqlSession().getConfiguration();
        if (this.addToConfig && !configuration.hasMapper(this.mapperInterface)) {
            try {
                configuration.addMapper(this.mapperInterface);
            } catch (Exception var6) {
                this.logger.error("Error while adding the mapper '" + this.mapperInterface + "' to configuration.", var6);
                throw new IllegalArgumentException(var6);
            } finally {
                ErrorContext.instance().reset();
            }
        }

        if (configuration.hasMapper(this.mapperInterface) && this.mapperHelper != null && this.mapperHelper.isExtendCommonMapper(this.mapperInterface)) {
            //为每个代理的mapper开始配置
            this.mapperHelper.processConfiguration(this.getSqlSession().getConfiguration(), this.mapperInterface);
        }

    }
```

匹配MappedStatement进行配置，类位置tk.mybatis.mapper.mapperhelper.MapperHelper

```java
 public void processConfiguration(Configuration configuration, Class<?> mapperInterface) {
        String prefix;
        if (mapperInterface != null) {
            prefix = mapperInterface.getCanonicalName();
        } else {
            prefix = "";
        }
     //通过configuration获取所有getMappedStatements,循环匹配
        for (Object object : new ArrayList<Object>(configuration.getMappedStatements())) {
            if (object instanceof MappedStatement) {
                MappedStatement ms = (MappedStatement) object;
                if (ms.getId().startsWith(prefix)) {
                    //开始处理此MappedStatements
                    processMappedStatement(ms);
                }
            }
        }
    }
```

继续处理，找到之前通过扫描缓存的MapperTemplate,所有@SelectProvider注解指定的自定义provider类都会继承MapperTemplate,后续缓存的信息进行和MapperTemplate进行设置处理，类位置tk.mybatis.mapper.mapperhelper.MapperHelper

```java
  public void processMappedStatement(MappedStatement ms){
  		//根据id找到之前缓存的MapperTemplate
        MapperTemplate mapperTemplate = isMapperMethod(ms.getId());
        if(mapperTemplate != null && ms.getSqlSource() instanceof ProviderSqlSource) {
            //替换SqlSource,替换信息从mapperTemplate而来
            setSqlSource(ms, mapperTemplate);
        }
    }
```

继续跟进设置,为每个MappedStatement替换其setSqlSource,类位置tk.mybatis.mapper.mapperhelper.MapperTemplate

```java
public void setSqlSource(MappedStatement ms) throws Exception {
        if (this.mapperClass == getMapperClass(ms.getId())) {
            throw new MapperException("请不要配置或扫描通用Mapper接口类：" + this.mapperClass);
        }
        Method method = methodMap.get(getMethodName(ms));
        try {
            //第一种，直接操作ms，不需要返回值
            if (method.getReturnType() == Void.TYPE) {
                method.invoke(this, ms);
            }
            //第二种，返回SqlNode
            else if (SqlNode.class.isAssignableFrom(method.getReturnType())) {
                SqlNode sqlNode = (SqlNode) method.invoke(this, ms);
                DynamicSqlSource dynamicSqlSource = new DynamicSqlSource(ms.getConfiguration(), sqlNode);
                setSqlSource(ms, dynamicSqlSource);
            }
            //第三种，返回xml形式的sql字符串
            else if (String.class.equals(method.getReturnType())) {
                String xmlSql = (String) method.invoke(this, ms);
                SqlSource sqlSource = createSqlSource(ms, xmlSql);
                //替换原有的SqlSource
                setSqlSource(ms, sqlSource);
            } else {
                throw new MapperException("自定义Mapper方法返回类型错误,可选的返回类型为void,SqlNode,String三种!");
            }
        } catch (IllegalAccessException e) {
            throw new MapperException(e);
        } catch (InvocationTargetException e) {
            throw new MapperException(e.getTargetException() != null ? e.getTargetException() : e);
        }
    }
```

支持在spring容器启动完毕后，所有的MappedStatement的SqlSource都已经被替换完毕。后续的增删等直接调用spring和mybatis的原生接口即可实现。

---

[MyBatis 通用 Mapper 实现原理](https://blog.csdn.net/isea533/article/details/78493852)
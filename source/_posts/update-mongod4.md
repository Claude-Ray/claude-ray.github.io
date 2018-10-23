---
title: MongoDB升级4.0和事务使用小记
date: 2018-10-23 22:08:09
tags: MongoDB
categories: MongoDB
---

4.0正式版已经出了3个多月，相比测试阶段网上有价值的资料日渐丰富，版本升级以及使用事务需要了解的知识都可以在官网找到。在这里记录一下升级本地开发环境的过程，生产环境应当用数据备份再恢复的方案。

总文档：[Release Notes for MongoDB 4.0](https://docs.mongodb.com/manual/release-notes/4.0/)

## 版本升级

单机开发环境，参考[standalone升级文档](https://docs.mongodb.com/manual/release-notes/4.0-upgrade-standalone/)

> 以下升级流程节选自上述文档

确保本地是3.6版本才能继续进行，以及兼容版本`featureCompatibilityVersion`为3.6。在mongo shell中可以执行检查和设置。

```sh
db.adminCommand( { getParameter: 1, featureCompatibilityVersion: 1 } )

db.adminCommand( { setFeatureCompatibilityVersion: "3.6" } )
```

升级前应关闭mongod服务和**备份数据**，之后按照官网所给出对应系统的[安装方法](https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/)执行安装。

例如Ubuntu18，可以按下面依次执行
```sh
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4

echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org
```

升级完成后在mongo shell中重新设置兼容性
```sh
db.adminCommand( { setFeatureCompatibilityVersion: "4.0" } )
```

## 事务使用

### replSet
目前必须在replSet中使用，简单的配置方法是`/etc/mongod.conf`添加设置
```
replication:
  replSetName: rs0
```
然后重启mongod `service mongod restart`，在mongo shell中执行初始化并查看结果
```
rs.initiate()
rs.conf()
```

### API
官方使用教程，内含demo：
https://docs.mongodb.com/manual/core/transactions/

Nodejs相关文档（npm包需更新）：
- node-mongodb-native:
http://mongodb.github.io/node-mongodb-native/3.1/api/ClientSession.html#startTransaction

- mongoose: 
https://mongoosejs.com/docs/transactions.html

手中项目使用事务的场景不多，暂时没有遇到坑，之后遇到再补充。

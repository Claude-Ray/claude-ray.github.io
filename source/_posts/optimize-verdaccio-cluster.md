---
title: Verdaccio 性能优化：单机 Cluster
date: 2019-12-31 19:46:30
tags: [Node.js,Verdaccio,private npm registry,npm]
categories: Node.js
---

本篇将讨论如何解决 [Verdaccio](https://github.com/verdaccio/verdaccio) 官方本地存储方案不支持 Cluster 的问题。

<!--more-->

## 前言

标题为什么叫单机 Cluster 呢？

因为多机 Cluster 已经无法使用默认的本地存储，必须配合一套新的存储方案，而官方只提供了 AWS 和 Google Cloud 的支持。这在国内已经是一道门槛，因此大概率是要用上其他云存储服务的，这意味着必须做一个 Verdaccio 插件实现必备的 add、search、remove、get 功能。

糟糕的是，倘若自己的云存储不支持查询功能，还得基于数据库再造一套轮子，甚至再加一套解决读写冲突的轮子。

一句话来说，Verdaccio 是轻量级好手，不适合也不必要承载太重的装备。重度使用的场景下，与其从头定制的存储体系，不如直接上 cnpm、Nexus 等体积更大、相对成熟的系统。

话说回来，作为尝试，我还是基于 Redis 实现了它的单机 Cluster。虽然修改的 Verdaccio 版本较旧，但其新版 V4 的架构并没有太大变化，思路还是一致的。

## 思路
Verdaccio 默认无法使用 PM2 Cluster 启动，有两大阻碍。

其一，缓存同步。它使用进程级别的内存缓存，没有实现进程间通讯，多进程之间缓存信息不能同步。

其二，写锁。本地存储将内容持久化到本机磁盘，只有进程级别的“锁”，多进程容易出现写文件冲突。

这两个问题处理起来其实非常简单，特别是引入 Redis 之后。

针对第一点，内存缓存可以迁移到 Redis，但是其中有大体积的 JSON 信息，不适合存在 Redis，可以用 Redis 做消息中心，管理各进程的缓存状态。

针对第二点，私服本身属于简单的业务场景，Redis 锁完全可以胜任。

## 实现
本应该是 Show Code 环节，可念在笔者改的版本不存在普适性，索性改成修改要点的简单罗列吧。

- 重写 local storage，本地存储依赖一个叫 `.sinopia-db.json` 或 `.verdaccio-db.json` 的文件，其中保存所有私服的包。这个文件的内容适合使用 Redis 的 set 结构进行替换。

- 查找并替换所有 `fs.writeFile`，加锁处理。在锁的实现上，新手需要多看官方文档，大部分博客的实现都是错误的，比如忽略了解锁步骤的原子化操作。

- 向上回溯修改的链路。

## 额外的补充
想来这可能是专题的最后一期，于是把不太相关的几个小问题也堆到下面吧。

只关心 Cluster 改造的看官可跳过此节，直接看末尾总结。

### 异步风格
由于手上的 Verdaccio 版本较老，整体还是 callback 风格，让改造多了一点工作量。我使用的 Redis 客户端为 ioredis，注意把涉及到的调用链路都改造为 async/await。

### 发布订阅
另一个坑点是我拿到的 Redis 其实是 Codis 集群，这套方案的一个缺点是无法使用 Redis 弱弱的发布订阅功能，也就不能直接拿来订阅更新内存缓存的消息。只好另辟蹊径，将 Redis 作为“缓存中心”，进程取缓存前先查询标志位，如果标志位存在，代表内存缓存需要更新。以进程号等信息做 key 前缀表示区分。

```js
const os = require('os');

class CacheCenter {
  constructor(prefixKey = 'updated') {
    this.data = new Map();
    // 利用 redis 缓存标志位，为空时表示缓存需要更新
    this.prefix = prefixKey;
    // 用 pm2 进程号区分缓存状态
    this.ip = getIPAddress();
    this.id = `${this.ip}:${process.env.NODE_APP_INSTANCE || 0}`;
  }

  async get(key) {
    const isCached = this.data.has(key);
    if (isCached) {
      const isCacheLatest = await redis.hget(this._key(key), this.id);
      if (isCacheLatest) {
        return this.data.get(key);
      }
    }
    return undefined;
  }

  async set(key, value) {
    this.data.set(key, value);
    await redis.hset(this._key(key), this.id, Date.now());
    redis.expire(this._key(key), 7 * 24 * 60 * 60);
  }

  async del(key) {
    redis.del(this._key(key));
  }

  has(key) {
    return this.data.has(key);
  }

  _key(key) {
    return `${this.prefix}:${key}`;
  }
}

function getIPAddress() {
  const interfaces = os.networkInterfaces();
  for (const iface of Object.values(interfaces)) {
    for (const alias of iface) {
      if (alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal) {
        return alias.address;
      }
    }
  }
  return '127.0.0.1';
}

module.exports = new CacheCenter();
```

### 页面搜索优化
最后顺便说一点，Verdaccio web 页面的 /search 接口性能极差，实现也存在诸多问题。这里值得加一层内存缓存，等到新包发布时刷新。并且它原本不支持 @scope 搜索，在创建索引的步骤可以加一行专用于 scope 信息。至于有些情况搜不到，这是它依赖的 lunr 引擎所决定的，就放过 Verdaccio 吧。

```js
class Search {
  /**
   * Constructor.
   */
  constructor() {
    this.index = lunr(function() {
      this.field('name', {boost: 10});
      this.field('unscoped', {boost: 8});
      this.field('description', {boost: 4});
      this.field('author', {boost: 6});
      this.field('readme');
    });
  }

  /**
   * Add a new element to index
   * @param {*} pkg the package
   */
  add(pkg) {
    this.index.add({
      id: pkg.name,
      name: pkg.name,
      unscoped: getUnscopedName(pkg.name),
      description: pkg.description,
      author: pkg._npmUser ? pkg._npmUser.name : '???',
    });
  }
  // ...
}

/**
 * 截取包名中不带 scope 的部分
 * 参照命名规范 @scope/name，直接截取/后的字符串
 */
function getUnscopedName(name) {
  return name.split('/')[1];
}
```

## 总结
为 Verdaccio 开启 Cluster 能力并不是一个轻松的做法，但经过这个系列解读，却可以轻松地作出选择。

如果只是想一定程度上提高处理高并发的性能，可以采取上一篇[代理分流](https://claude-ray.github.io/2019/10/22/optimize-verdaccio-proxy/)的做法，代理可以帮你分担 99%以上的压力。

如果想进一步提升性能，实现应用的平滑重启，本文单机 Cluster 并配合 pm2 reload 的做法不妨一试。

而一但想开启多节点集群的能力，几乎超出了轻量级私服的理念，试着迁移到 cnpm、Nexus 吧。

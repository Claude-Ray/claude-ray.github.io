---
title: PM2 cluster + log4js？并不理想的组合
date: 2018-12-21 20:49:03
tag: [Node.js,log4js,pm2,pm2-intercom]
categories: Node.js
---

# log4js 和 cluster

## 写策略
node cluster 多个进程同时写一个文件是不安全的，通常会只选择一个 master 进程负责写入，其他 worker 进程则将数据传输到 master。

log4js 的写策略正是如此，但默认只适用于 node 原生的 cluster 模式，然而通过 pm2 启动的进程都是 worker。

官方提供的方案是安装 `pm2-intercom`，并在代码配置 log4js 时打开 `pm2: true` 选项，其原理也是选出一个负责写文件的主进程。
```sh
pm2 install pm2-intercom
```

## 选举 master
log4js 选择主进程的[策略](https://github.com/log4js-node/log4js-node/blob/master/lib/clustering.js#L13)：
```js
const isPM2Master = () => pm2 && process.env[pm2InstanceVar] === '0';
const isMaster = () => disabled || cluster.isMaster || isPM2Master();
```

其中 disabled 是 log4js 的 disableClustering 选项，设置为 true 后，所有进程都将作为 master 进而拥有写文件的权限，这并没有解决安全问题。它存在的价值后面再说。

每个 pm2 启动的进程都有唯一的 process.env.NODE_APP_INSTANCE 标识，`process.env.NODE_APP_INSTANCE === '0'` 是常见的选择主从方式。多进程同时记录日志时，也可以用此方式指定唯一的进程负责写文件，避免同时写文件造成的冲突。此外 pm2 支持通过重命名 `instance_var` 来改变 process.env 的标记名，目的是解决和 `node-config` 包共用导致的异常。

> [关于 NODE_APP_INSTANCE 的 pm2 官方说明](http://pm2.keymetrics.io/docs/usage/environment/#specific-environment-variables)

## 问题多多的 pm2-intercom 方案
当下 pm2 的版本是 3.2.x，而 `pm2-intercom` 在 pm2 2.x 版本就已经存在异常了，重复日志甚至丢失日志，或在开发环境运行正常，到了线上莫名失败。更严重的是，当一个 pm2 box 内运行多个 cluster 模式启动的应用时，日志记录会变得混乱，各应用的日志都乱入了最早启动的应用的日志文件中。

log4js 的维护者 nomiddlename 也在 issue 中表示 pm2-intercom 存在着古怪的问题。
> [log4js doesn't work with PM2 cluster mode #265](https://github.com/log4js-node/log4js-node/issues/265#issuecomment-359126674)
>
> pm2-intercom has always seemed a bit dodgy - for some people it never works at all anyway. It didn't need to use git clone when I installed it. Best plan might be to use the disableClustering option in your log4js config, log to stdout and let pm2 handle the files as it normally would.

## option.disableClustering 不是银弹
上面再次提到 `disableClustering` 选项，不错，pm2-intercom 异常的场景可以拿它救场，但要注意它本身不适用于直接写文件，每个进程都被赋予了 master 权限，会再次引发开篇的冲突问题。官方文档也明确警示：`Be careful if you’re logging to files`。

# pm2-intercom 粗解
这个模块是简易的 IPC，借助 `process.send` 方法，将多个进程的数据包统一发送至 pm2 中编号为 0 的 pm2-intercom 进程，此进程再将收到的消息推送至项目进程中的一个。

在log4js的使用场景，表现为各自进程的日志首先发送到 pm2-intercom，由 pm2-intercom 分发到全部进程，但只有 log4js isMaster 才会写文件。

分发代码如下
```js
function(packet) {
  async.forEachLimit(process_list, 3, function(proc, next) {
    sendDataToProcessId(proc.pm_id, packet);
  }, function(err) {
    if (err) console.error(err);
  });
}
```

# 小结

如果想在多进程模式下记录日志到同一个文件，log4js + PM2 显然不是完美的组合。winston 也有人反馈丢日志的[问题](https://github.com/winstonjs/winston/issues/1466)，但没有得到官方回复前，仍需要验证。

如果想安全记录日志，还是得分多个文件，或脱离 pm2，像 egg 一样在框架层面自行 cluster。

## Reference
- [Clustering / Multi-process Logging](https://log4js-node.github.io/log4js-node/clustering.html)

- [to-fix-pm2-intercom-in-pm2-2x](https://www.npmjs.com/package/lj-log4js-pm2intercom)

- [再说打日志你不会，pm2 + log4js，你值得拥有](https://juejin.im/post/5b7d0e20f265da43231f00d4)

- [探索 PM2 Cluster 模式下 Log4js 日志丢失](https://www.jianshu.com/p/20fcb3672723)

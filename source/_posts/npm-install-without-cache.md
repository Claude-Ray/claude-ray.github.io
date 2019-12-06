---
title: 让 npm install 不使用缓存的方法
date: 2019-12-06 12:04:56
tags: [Node.js,npm]
categories: Node.js
---

# Why
npm 的安装出错是屡见不鲜，往往是因为安装的环境不够 "clean"。

通常情况下，只要删除项目目录的 node_modules 和 package-lock.json，重新执行 install 就能解决。

偶尔也会出现上述操作解决不了的问题，譬如 npm 的缓存文件异常，就需要在安装前执行 `npm cache clean --force` 清空缓存目录。

但 npm cache clean 也存在两个未处理的缺陷，使它既不完全可靠又具备风险。

<!--more-->

1. 部分依赖会和 npm 共用缓存目录（终端下通过 `npm config get cache` 命令查看，默认 `~/.npm`），用来存放自己的临时文件。

    而 npm@5 之后，cache clean 只会清除该缓存目录下的 `_cacahce` 子目录，而忽视不在该子目录的缓存。

    例如 @sentry/cli 将缓存放在了和 _cacache 同级的 [sentry-cli](https://github.com/getsentry/sentry-cli/blob/1.49.0/scripts/install.js#L78) 目录，clean cache 不会清除此处缓存。
    > 此例有网友专门记录了[排错经过](https://github.com/sliwey/blog/issues/1)

2. 突然执行 cache clean，将导致正在使用 npm install 的项目丢失部分依赖。

    如果有多个项目在同一环境执行 npm install，此问题的影响会进一步扩大，npm 将抛出各种文件操作错误。

鉴于缓存出错是极小概率事件，若能使用温和的安装方式避开缓存文件，无疑是更好的选择。

可是，npm install 利用缓存的行为是默认且强制的，目前官方还没有提供形如 --no-cache 的选项来做一次忽略缓存的干净安装。

> npm-cache 机制详见[官网文档](https://docs.npmjs.com/cli/cache.html)

# How
尽管 npm cli 还没支持，但这个需求我们自己实现起来却十分简单。

既然 cache 目录是通过 npm config get cache 获取的，也就支持相应的 set 方式。为每个待安装项目重新配置 cache 目录，等于变相地清除了 npm 之前所有的缓存。

当然，直接 npm config set cache 会让 npm 全局生效，为了单独设置缓存目录，在项目内添加 .npmrc 文件，并加入

```
cache=.npm
```

可观察到缓存路径的变更生效

```sh
$ npm config get cache
/Users/claude/.npm

$ cd ~/node-project && echo cache=.npm >> .npmrc

$ npm config get cache
/Users/claude/node-project/.npm
```

再安装就会重新下载依赖啦，还起到了环境隔离的作用。


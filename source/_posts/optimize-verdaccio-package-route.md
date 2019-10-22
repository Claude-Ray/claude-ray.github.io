---
title: Verdaccio 性能优化：上游路径转发
date: 2019-10-22 19:32:39
tags: [Node.js,Verdaccio,private npm registry]
categories: Node.js
---

## 背景
这里的 [Verdaccio](https://github.com/verdaccio/verdaccio) 是指用于搭建轻量级 npm 私有仓库的开源解决方案，以下简称 npm 私服。

有些项目依赖了 npm 自身的包，每次项目部署时都会产生对私服 `/npm` 路由的请求记录，并在监控曲线上呈明显的高耗时，这引起了我们的关注。

<!--more-->

## 原因
Verdaccio 私服对公共（外网）npm 包的处理存在一定程度的性能问题。

其中一个原因是每当通过私服下载公共 npm 包，Verdaccio 都要等上游镜像的响应完整结束之后，才开始响应私服用户的请求。这导致 Verdaccio 的整体速度比直接用上游慢了一截。

至于会慢多少呢，要提到另一个 npm 机制：一个依赖 package 下载之前，要先到镜像地址的 =/:package/:version?= 接口获取完整的包信息，之后才会下载所需的版本。而一个模块历史发布过的版本越多，信息量越大。尤其是 npm 自身这个包，访问一下 http://registry.npmjs.org/npm 便知。

Verdaccio 慢就慢在获取包信息这一步，它必须等待上游接口响应完成，才能做相关 JSON 解析和逻辑处理。因此不仅仅是慢的问题了，还有内存和 CPU 的大量消耗。

## 思路
从上面看，私服接口性能存在很大的优化空间，哪怕只是将几个体积较大的“罪魁祸首” npm 包单独优化，也能缓解私服的压力。

首先想到的是缓存，可惜小机器经不起缓存的资源消耗，不然解决方案就已经找到了。网络带宽倒是相对不缺，低成本、纯网络代理转发是一个可行的目标。

Verdaccio 会对下载的 npm 包信息做解析和记录，但其实我们并不关心那些只属于上游的包，只希望它能承担好转发工作，甚至巴不得所有公共依赖都不经过私服处理。

退一步讲，就是要弱化在私服中对这些公共依赖的处理，减少解析过程 —— 用 stream 完成请求转发。

## 代码
遗憾的是 Verdaccio 自身的接口难以复用，只好直接在其基础上增加路由。简单粗暴，对项目的熵值影响不大。

```js
const _ = require('lodash');
const createError = require('http-errors');
const request = require('request');
const URL = require('url');

const Middleware = require('../../web/middleware');
const Utils = require('../../../lib/utils');

module.exports = function(route, auth, storage, config) {
  const can = Middleware.allow(auth);

  // 优化特定依赖的获取，以 `npm` 举例
  route.get('/npm', (req, res) => {
    // 拼接镜像地址
    const upLinkUrl = _.get(config, 'uplinks.npmjs.url', 'https://registry.npm.taobao.org');
    const packageUrl = URL.resolve(upLinkUrl, req.originalUrl);

    // 利用 Verdaccio 定义的 res.report_error 来采集错误
    const npmRes = request(packageUrl)
      .on('error', res.report_error);

    // 直接将上游结果转发，快速响应请求
    req.pipe(npmRes).pipe(res);
  });

  route.get('/:package/:version?', can('access'), function(req, res, next) {
    // ...
  });
  // ...
};
```

stream 转发减轻了服务的内存压力（节省上百 MB 的临时缓冲），并减少这部分接口 50% 以上的 TTFB 响应时间。

作为尝试，目前这个 patch 笔者只用在了特定依赖。转发所有上游 npm 包的念想还未落地，做起来应该很简单，但需要继续摸索 Verdaccio 结构，才好给出更合适的修改方案。


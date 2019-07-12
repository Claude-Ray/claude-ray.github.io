---
title: elastic-apm-node 扩展篇 —— Egg
date: 2019-07-12 21:18:53
tags: [Node.js,APM,Elastic-APM,Egg]
categories: Node.js
---

# 前言

本篇是为 elastic-apm-node 编写拓展系列的第二篇，主要介绍 egg 框架的定制指南。

单独拿 egg 出来讲，是因为市面主流的 APM 工具几乎都没有为 egg 提供支持。一方面 egg 底层基于 koa ，并且 egg-router 也是 koa-router 的二次封装，两者相似以致插件可以平稳切换，agent 的补丁方式也基本是一致的。另一方面，agent 代码必须早于 egg 和 egg-router 的加载才能生效，egg-bin、egg-script 等生态决定了编写框架之上的插件很难做到零代码入侵。

APM agent 作为 npm package 不适合做这样的事，更好的方法是我们利用 egg 工具链的接口，在引入 agent 的代码层处理好 egg 的配置。

<!--more-->

# 在 egg 前 require
我们先考虑如何将 APM agent 早于 egg 执行，解决 patch 此框架主要问题，然后再完成定制化操作。

好在 egg 是提供了相关方法的，最底层的 API 是 `startCluster` 方法，可以传入 `require` 参数指明你要率先执行模块。

## 方案一：修改启动文件
假设把 APM 的引入和配置放在了根目录 elastic-apm.js 中，新建一个类似下面这样的 app.js 作为 egg 的启动文件，用最原始的 `node app.js` 启动服务就好了。

```js
require('egg').startCluster({
  require: [ require.resolve('./elastic-apm') ],
});
```

> !!! 不推荐：必须放弃 egg-bin 和 egg-scripts 作为启动器，需要自己补上很多操作。

## 方案二：修改 package.json
> 要求 `egg-bin` 版本 >= [4.10.0](https://github.com/eggjs/egg-bin/blob/master/History.md#4100--2019-01-04)

在 `package.json` 中添加 `egg.require` 配置，用法来自 [issue 讨论](https://github.com/eggjs/egg/issues/2844#issuecomment-409457550)。

```json
{
  "egg": {
    "require": [ "./elastic-apm.js" ]
  },
  "scripts": {
    "start": "egg-scripts start"
  }
}
```
这是目前最推荐的做法，不影响 egg 工具链的正常使用。

# 编写补丁

## instrumentation/egg.js

仿照 [instrumentation/koa.js](https://github.com/elastic/apm-agent-nodejs/blob/master/lib/instrumentation/modules/koa.js)，修改框架 name，注意开启 overwrite 选项，为了覆盖引用 koa 带来的标识。

```js
'use strict'

module.exports = function (egg, agent, { version, enabled }) {
  if (!enabled) return egg
  // 注意开启 overwrite，这样才能覆盖 koa 标识
  agent.setFramework({ name: 'egg', version, overwrite: true })
  return egg
}
```

## instrumentation/egg-router.js

唯一需要修改的就是去掉 [instrumentation/koa-router.js](https://github.com/elastic/apm-agent-nodejs/blob/master/lib/instrumentation/modules/koa-router.js) 的版本验证。考虑到 egg 引入的 koa 版本都是同时期最新，无须担心 egg 自身版本问题。

```js
'use strict';

const shimmer = require('elastic-apm-node/lib/instrumentation/shimmer');

module.exports = function (Router, agent, { version, enabled }) {
  if (!enabled) return Router

  agent.logger.debug('shimming koa-router prototype.match function')
  shimmer.wrap(Router.prototype, 'match', function (orig) {
    return function (_, method) {
      var matched = orig.apply(this, arguments)

      if (typeof method !== 'string') {
        agent.logger.debug('unexpected method type in koa-router prototype.match: %s', typeof method)
        return matched
      }

      if (Array.isArray(matched && matched.pathAndMethod)) {
        const layer = matched.pathAndMethod.find(function (layer) {
          return layer && layer.opts && layer.opts.end === true
        })

        var path = layer && layer.path
        if (typeof path === 'string') {
          var name = method + ' ' + path
          agent._instrumentation.setDefaultTransactionName(name)
        } else {
          agent.logger.debug('unexpected path type in koa-router prototype.match: %s', typeof path)
        }
      } else {
        agent.logger.debug('unexpected match result in koa-router prototype.match: %s', typeof matched)
      }

      return matched
    }
  })

  return Router
}
```

# 添加补丁

回到最初的 elastic-apm.js 文件，在其中设置 addPatch，大功告成。

```js
'use strict';
const apm = require('elastic-apm-node').start({
  // options
});

apm.addPatch('egg', require.resolve('./instrumentation/egg'))
apm.addPatch('@eggjs/router', require.resolve('./instrumentation/egg-router'))
```

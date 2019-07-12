---
title: elastic-apm-node 扩展篇 —— Express
date: 2019-07-11 22:54:59
tags: [Node.js,APM,Elastic-APM,Express]
categories: Node.js
---

# Introduction

elastic-apm-node 提供了非常友好的定制化支持，本篇将示范如何为 express 框架添加路由 patch，以满足信息上报的优化。

<!--more-->

许多开发者在定制开源依赖时，都选择了 fork 源码，在此基础上提交修改，作为新的模块来“维护”。这样做的稳定性极高，等于对依赖加上了版本锁，不用担心动态版本的安全问题。

但弊端也非常大，最重要的是需要投入精力定时跟进官方包的更新。除了要小心 `breaking change`，任何你需要的 `fix` 或 `feature`，都要重新更新发布自己的模块。维护成本极高，甚至大部分情况是没人维护的。

幸亏 elastic-apm-node 有不错的扩展性，我们不用 fork，只需要做一个包裹层二次封装。

定制的出发点要立在合理的需求上，我们拿 vue-ssr 官网的 demo 举例：

```js
const createApp = require('/path/to/built-server-bundle.js')

server.get('*', (req, res) => {
  const context = { url: req.url }

  createApp(context).then(app => {
    renderer.renderToString(app, (err, html) => {
      if (err) {
        if (err.code === 404) {
          res.status(404).end('Page not found')
        } else {
          res.status(500).end('Internal Server Error')
        }
      } else {
        res.end(html)
      }
    })
  })
})
```
默认情况下，无论请求 url 是指向哪个页面路由，Kibana apm 界面看到的事务信息永远都是 `GET *`，显然无法满足我们观测请求量的需要。

# route `*`

路由是 * 动态匹配的，要想获取到真实路由，比较容易的方案是读取 `req.path`，但最好的方案是直接拿到原始表达式，这样 `/user/:id` 形式的路由也能较好地折叠呈现。

但 vue ssr 项目通常将页面路由规则存放在前端，这种情况也无法在 express 的 router 上做文章，只能回到原始的 url path 方案了。

在 `node_modules/elastic-apm-node/lib/instrumentation/modules/express.js` 的 `patchLayer` 中加入如下代码
```js
// NOTE: add below this code block
if (!layer.route && layerPath && typeof next === 'function') { }

// NOTE: patch route * up
if (layer.route && layerPath === '*' && layer.path) {
  const name = req.method + ' ' + layer.path
  agent._instrumentation.setDefaultTransactionName(name)
}
```

你也可以对 path 内部加上正则校验，遇到纯数值、32 位或 16 位定长 id，便将其当作 `:id`，将内容掩盖处理，以达成简易的路由还原效果。

最后，由于这个已经修改了 express route 的 wrap，但 shimmer 的代码决定了一个函数只能有一个 wrapper。因此想替换掉原有的 wrapper，必须先 unwrap express 的 route，然后再执行 shimmer.wrap 。

```js
// NOTE: rewarp express router
shimmer.unwrap(routerProto, 'route')

shimmer.wrap(routerProto, 'route', orig => {
  return function route (path) {
    var route = orig.apply(this, arguments)
    var layer = this.stack[this.stack.length - 1]
    patchLayer(layer, path)
    return route
  }
})
```

其他的 patch 同理。

# addPatch

上面介绍了完成需求的方法，但本篇主旨是扩展，而非在源码上直接修改。这就要使用 apm agent 暴露的 [addPatch](https://www.elastic.co/guide/en/apm/agent/nodejs/master/agent-api.html#apm-add-patch) 接口。可在此基础上完成所有定制框架和路由的处理。

特别提示，有别于上面的 wrapper，针对同一个 npm 模块，elastic-apm-node 支持添加多个 patch。因此不必要的时候，无需删除 elastic agent 已经添加的 patch，直接在引入 apm 的地方调用 addPatch 即可。

还是以 express 为例，把 patch 的新方法写在另一个 `instrumentation/express.js` 文件中。
```js
const apm = require('elastic-apm-node').start()

apm.addPatch('express', require.resolve('./instrumentation/express'))
```

./instrumentation/express.js 的实现可以参考原 agent v2.12.1 版本中的 [express](https://github.com/elastic/apm-agent-nodejs/blob/master/lib/instrumentation/modules/express.js)，需要修改的内容上文已经提到了，需要补充代码的位置参考如下：

```js
// Original file: https://github.com/elastic/apm-agent-nodejs/blob/master/lib/instrumentation/modules/express.js
// License: https://github.com/elastic/apm-agent-nodejs/blob/master/LICENSE
'use strict'

const isError = require('core-util-is').isError
const semver = require('semver')

// 工具模块直接引用 agent，不必重复实现
const shimmer = require('elastic-apm-node/lib/instrumentation/shimmer')
const symbols = require('elastic-apm-node/lib/symbols')

// 剩余未经标注的代码均来自原 agent 的 express 文件，只需要复制必要的部分
module.exports = function (express, agent, { version, enabled }) {
  // 框架识别、版本号校验、路由兼容性的一些处理，以及内部函数，从文件原样复制即可
  // 省略代码若干行……
  function patchLayer (layer, layerPath) {
    if (!layer[layerPatchedSymbol]) {
      layer[layerPatchedSymbol] = true
      agent.logger.debug('shimming express.Router.Layer.handle function:', layer.name)
      shimmer.wrap(layer, 'handle', function (orig) {
        let handle

        if (orig.length !== 4) {
          handle = function (req, res, next) {
            if (!layer.route && layerPath && typeof next === 'function') {
              safePush(req, symbols.expressMountStack, layerPath)
              arguments[2] = function () {
                if (!(req.route && arguments[0] instanceof Error)) {
                  req[symbols.expressMountStack].pop()
                }
                return next.apply(this, arguments)
              }
            }
            // NOTE: 在这里添加 `*` 等路由定制代码
            if (layer.route && layerPath === '*' && layer.path) {
              const name = req.method + ' ' + layer.path
              agent._instrumentation.setDefaultTransactionName(name)
            }
            return orig.apply(this, arguments)
          }
        } 
        // 省略若干行……
        return handle
      })
    }
  }
  // 省略若干行……

  // NOTE: 记得加一行 unwrap
  shimmer.unwrap(routerProto, 'route')
  // 并重新 wrap，代码复制过来即可
  shimmer.wrap(routerProto, 'route', orig => {
    return function route (path) {
      var route = orig.apply(this, arguments)
      var layer = this.stack[this.stack.length - 1]
      patchLayer(layer, path)
      return route
    }
  })
  // 剩余代码处理基本到此位置了，不需要处理的 wrapper 保持不动就好

  return express
}
```

# unknown route

在使用中发现，通过 app.use 引入的路由全部被标记为 `unknown route`，正准备在 patch 中修复这个问题的时候，在这个 [issue](https://github.com/elastic/apm-agent-nodejs/issues/1008) 中找到了根源。

此问题在 `v2.11.5` 版本后修复，升级版本就行，不用折腾了~

# Afterword

给 elastic-apm-node 编写拓展时明显体会到高扩展性的优势。在设计工具类时，良好的扩展性给用户带来了非常多的便利，遇到这类第三方依赖的 bug 时，作为用户的我们可以在 **不修改原始代码的情况下自行将其修复**。

特别是近期接触了较多 GNU 精神，向所有在项目中为扩展性挥洒汗水的开发者致敬。

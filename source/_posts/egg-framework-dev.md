---
title: 不靠谱的 Egg.js 框架开发指南
date: 2019-09-17 19:44:02
tags: [Node.js,Egg]
categories: Node.js
---

这是一篇面向 Egg.js 上层框架开发者的科普文。

Egg 官网基本做到了呈现所有“必知必会”的内容，再写一份 Egg 使用教程已经毫无必要，不如聊聊 Egg 上层框架开发过程中可能有用的技巧。

<!--more-->

# 概览

## 文档
深入浅出的官网和专栏分享

- [eggjs.org](https://eggjs.org)
- [yuque.com/egg/nodejs](https://www.yuque.com/egg/nodejs)
- [zhuanlan.zhihu.com/eggjs](https://zhuanlan.zhihu.com/eggjs)

## 核心
阅读源码的必经之路

- egg-core
- egg-cluster

## 命令行工具
- egg-scripts: 用于生产环境的部署工具
- egg-bin: 开发环境的 debug、test、coverage
- ets: egg-ts-helper，用于辅助 egg ts 项目生成 .d.ts 声明文件，为 egg 的 ts 开发提供友好的智能提示，已经被 egg-bin 内部集成
- egg-init: egg 的脚手架初始化工具，框架开发者总是需要搭建自己的脚手架，因此这个可以仅作了解，我们并不会使用。自 npm@6 以后，增加了 npm-init 的新特性
    - npm init foo -> npx create-foo
    - npm init @usr/foo -> npx @usr/create-foo
    - npm init @usr -> npx @usr/create

## 测试工具
- egg-mock: 提供了完整的 mock 代码，测试 API 来自 supertest

# 进阶

进阶 Egg 的步骤包括但不限于通读官网文档，至少要熟悉下面两个话题才能算了解了 Egg。

- [多进程模型](https://eggjs.org/zh-cn/core/cluster-and-ipc.html)

- [loader && 生命周期](https://eggjs.org/zh-cn/advanced/loader.html)

# 深入

接下来是几个或多或少官网没有讲到的话题。

## 平滑重启
Egg 的多进程模型决定了 PM2 这样的进程管理工具对它意义不大。可惜的是没有了 PM2，我们也失去了 pm2 reload 这样轻量的平滑重启方案，鉴于 Egg 应用不短的启动时长，必须在流量进入 Node.js 之前加以控制。

对有强力运维的团队来讲，server 的启动时间不是问题，问题是还有不少 Node.js 项目只有一层代理甚至是裸运行的，又不想给运维加钱。对此最基本的建议是前置 nginx ，在配置多个节点的 upstream 之后，默认的选服策略就带上了容错机制。

```nginx
upstream backend {
    server backend1.example.com       weight=5 max_fails=3 fail_timeout=60s;
    server backend2.example.com:8080  weight=2;

    server backup1.example.com:8080   backup;
    server backup2.example.com:8080   backup;
}

server {
    location / {
        proxy_pass http://backend;
    }
}
```

简单来说，fail_timeout 默认 (10s) 就可以提供一个 “server backend 被 nginx 判定不可用之后，10s 之内不会有新的请求发送到该地址” 的缓冲期。

参考 nginx 的配置说明，酌情调整 `max_fails`、`fail_timeout` 等参数，为服务提供一个基本但可靠的稳定保障吧。

## 路由

### egg-router vs koa-router

egg-router 的逻辑基于 koa-router，早期直接引用 koa-router，在其基础上封装了 Egg.js 应用的路由注册，以及其他小特性。 后来 egg-router 从 egg-core 中剥离，并更改维护方式为 fork（koa-router 的维护度太低了），但没有做 breaking changes。两者的主要差别如下，稍后会做详细介绍：

- RESTful
- 默认大小写敏感

### RESTful

koa-router 提供了比较基础的 RESTful API 支持，`.get|put|post|patch|delete|del`。

Egg 实现了一套应用较广的约定，以便在 Egg 应用中快速编写 RESTful CRUD。

`app.resources('routerName', 'pathMatch', controller)`

| Method | Path            | Route Name | Controller.Action             |
|--------|-----------------|------------|-------------------------------|
| GET    | /posts          | posts      | app.controllers.posts.index   |
| GET    | /posts/new      | new_post   | app.controllers.posts.new     |
| GET    | /posts/:id      | post       | app.controllers.posts.show    |
| GET    | /posts/:id/edit | edit_post  | app.controllers.posts.edit    |
| POST   | /posts          | posts      | app.controllers.posts.create  |
| PUT    | /posts/:id      | post       | app.controllers.posts.update  |
| DELETE | /posts/:id      | post       | app.controllers.posts.destroy |

举例如下，根据以上映射关系，在 `app/controller/post.js` 中选择性地实现相应方法即可。

```js
app.resources('/posts', 'posts')
```

> route name 是 koa-router 就定义了的可选参数，如果指定了 route name，当路由匹配成功时，会将此 name 赋值给 ctx._matchedRouteName

### sensitive

Egg 在创建 router 的时候传递了 sensitive=true 的选型，在 koa-router 中开启了大小写敏感。
 [sensitive=true](https://github.com/eggjs/egg-core/blob/master/lib/egg.js#L301)

### Radix Tree

Radix Tree 是一种基于前缀的查找算法，Golang 的 echo、gin 等 web 框架的路由匹配都使用了该算法。

而 egg-router(koa-router) 以及 express router 均采用传统的正则匹配，具体做法是用 path-to-regexp 将路由转化为正则表达式，路由寻址就是遍历查找符合当前路径的路由的过程。

对比基于两种算法的路由查找效率，Radix Tree 更占优势，并且 url 越长，路由数量越多，性能差距越大。

以下是 10000 个路由情况下主流路由中间件的性能比拼，数据截选自 `koa-rapid-router` 。

静态路由

| Architecture       | Latency   | Req/Sec | Bytes/Sec |
|--------------------|-----------|---------|-----------|
| `koa + koa-router` | 245.07 ms |  394.25 | 56 kB     |
| `fastify`          | 1.96 ms   |   49324 | **7 MB**  |

动态路由

| Architecture       | Latency   |  Req/Sec | Bytes/Sec   |
|--------------------|-----------|----------|-------------|
| `koa + koa-router` | 220.29 ms |   441.75 | 62.7 kB     |
| `fastify`          | 1.9 ms    | 50988.65 | **7.24 MB** |

那为什么不全面使用 Radix Tree 呢？其实只有少数涉及大量路由和性能的场景，如 npm registery。

如果项目真的有如此性能需要，恐怕你不得不考虑用该算法编写的路由中间件来取代默认的 egg-router 了。

## 引入 Elastic APM

### 如何支持 egg 框架

需求：elastic-apm hook 必须在 Egg 和 egg-router 被 require 前完成加载。

之前有一篇更详细的文章《[elastic-apm-node 扩展篇 —— Egg](http://claude-ray.com/2019/07/12/elastic-apm-node-egg/)》，适用于 Egg 应用层的 APM 接入。而在框架层则简单许多，可以直接在框架入口文件做此处理，应用开发者无须再关心这个包的处理细节。

### ts 项目启动卡住

由于 egg-bin 内置的 ets (egg-ts-helper) 会用子进程同步地预加载一部分 ts 代码用作检查，apm 会被顺势加载，如果配置的环境变量或 serverUrl 字段有误，导致访问无法连通的 apm-server，最终会让该子进程挂起，ets 无法正常退出。

> ets 只在 `egg-bin start/dev/debug` 启动 ts 项目时生效，不会影响线上经过编译的 js `egg-script start` 启动。

针对上述情况，增加了默认不在 ets 编译过程启动的处理，特征是存在 `ETS_REGISTER_PID` 环境变量。因此实际上运行调试和测试时都不会开启 apm。

同时单独运行 `ets` 时没有上述变量，因此将 NODE_ENV 为 undefined 的环境也排除。

```ts
const enableAPM = process.env.APM_ENABLE || (!process.env.ETS_REGISTER_PID && process.env.NODE_ENV);
if (enableAPM) {
  const isDev = process.env.APM_DEV === 'true' || process.env.NODE_ENV !== 'production';
  apm.start({ isDev });
}
```

## 框架仓库管理

在 npm 官方提供 momorepo 的正式支持之前，我们可以使用 Lerna 作为统一的框架、插件管理工具。

对于我们日常需要的 npm 管理操作，Lerna 并没有引入太多额外的使用成本，并且可以通过 npm 指令一一封装。

使用方式其实非常灵活，按团队的习惯来就好。如果之前没有使用过，可以参考 midway/scripts 下的 Lerna [脚本](https://github.com/midwayjs/midway/blob/master/scripts)，并且可以在 CI 构建过程中执行版本更迭和发布。

## 获取实时 ctx

框架开发时遇到了一个少见情况，需要通过 Egg 的 app 对象获取当前上下文的 ctx 对象，用于在特别插件的中间件函数中定位 Egg 的上下文，以实现插件日志挂载到 ctx 对象。

> 其实这是一个没什么用的需求 :)

听起来比较绕，举个例子，在 egg 中使用 dubbo2.js —— 引入的方式参考 dubbo2.js 和 egg 的集成指引文档，并在其中使用中间件扩展

```js
// {plugin_root} ./app.js
module.exports = app => {
  const dubbo = Dubbo.from({....});
  app.beforeStart(async () => {
    dubbo.use(async (ctx, next) => {
      const startTime = Date.now();
      await next();
      const endTime = Date.now();
      console.log('costtime: %d', endTime - startTime);
    });
    await dubbo.ready();
    console.log('dubbo was ready...');
  })
}
```
上述的 ctx 并不属于 egg 创建的 ctx，两者之间相互隔离。唯一能让两者产生联系的，就是使用闭包中的 app。

于是有了 `egg-current-ctx` 这个模块，借助 app.currentCtx 方法，可以将两种 ctx 联系起来。

```js
module.exports = app => {
  const dubbo = Dubbo.from({....});
  app.beforeStart(async () => {
    dubbo.use(async (ctx, next) => {
      const startTime = Date.now();
      const eggCtx = app.currentCtx;
      // 对 eggCtx 处理
      console.log('', eggCtx.query);
      await next();
      const endTime = Date.now();
      console.log('costtime: %d', endTime - startTime);
    });
    await dubbo.ready();
    console.log('dubbo was ready...');
  })
}
```

如果想把 dubbo2.js 中 ctx 的属性挂载到 egg 的 ctx 上，这个没什么卵用的插件就能散发一点温度。

感兴趣的可以看 egg-current-ctx 的[代码实现](https://github.com/Claude-Ray/egg-current-ctx)，基于 async_hooks。

## 发布加速
Egg + ts 应用具备 150M 起步的 node_modules，再加上网络原因（和小水管 npm 私服），安装、拷贝速度十分感人。

如何提速？

> 这里旨在提供解决思路，一定有更好的方案，欢迎交流指正

1. node_modules 不再每次都安装，打包平台和线上环境缓存第一次安装的依赖。(参考 travis-ci)

2. 针对前一点的改进，node_modules 安装在代码目录上层，发布平台只拷贝代码，版本号式迭代。

    可是目录层级的处理在 Egg 项目上略显吃力，需要一套完整的项目和测试用例协助试错。因为 egg-utils 等工具类的底层代码将 node_modules 目录层级写得太死了。

    举个例子，`egg-utils/lib/framework.js 66L` ，导致无法查找上层 node_modules 里的 egg 依赖

    ```js 
    function assertAndReturn(frameworkName, moduleDir) {
      const moduleDirs = new Set([
        moduleDir,
        // find framework from process.cwd, especially for test,
        // the application is in test/fixtures/app,
        // and framework is install in ${cwd}/node_modules
        path.join(process.cwd(), 'node_modules'),
        // prevent from mocking process.cwd
        path.join(initCwd, 'node_modules'),
      ]);
      for (const moduleDir of moduleDirs) {
        const frameworkPath = path.join(moduleDir, frameworkName);
        if (fs.existsSync(frameworkPath)) return frameworkPath;
      }
      throw new Error(`${frameworkName} is not found in ${Array.from(moduleDirs)}`);
    }
    ```

3. npm 私服优化。修改上游镜像是一方面，自建的服务如果无法支持多节点多进程，也很容易成为安装依赖的性能瓶颈。假如使用 verdaccio 的本地存储模式，将很难得到官方 cluster 方案支持，除非你购买了 google cloud 或 aws s3。

# Reference

- [chenshenhai/eggjs-note](https://github.com/chenshenhai/eggjs-note)
- [koa-rapid-router](https://github.com/cevio/koa-rapid-router)

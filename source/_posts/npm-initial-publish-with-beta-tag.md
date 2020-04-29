---
title: 分享一个 npm dist-tag 的冷知识
date: 2020-04-29 21:13:15
tags: [Node.js,npm]
categories: Node.js
---

dist-tag 是广为 npm 包开发者所熟知的属性，如果不是今天碰到一个有趣的问题，我根本没想过拉它出来玩。

为了照顾不曾了解 dist-tag 的用户，我先用一句话介绍 —— dist-tag 是 npm 版本号的命名空间，而 latest 则是默认的命名空间。想必大家不会陌生 `npm install <name>@latest` 这样的用法吧。

更重要的是，除非 package.json 中有所指定，所有安装默认在 latest 空间下匹配版本号。而处在 latest 空间时，也不会去名为 beta 的 dist-tag 下查找版本号。

那么问题来了！设想一个 npm 包首次发布就使用 beta 作为 dist-tag，它可以被 `npm install <name>` 安装吗？

<!--more-->


答案是肯定的。

我还发布了一个空白的 npm beta 包作为验证。

![publish](/image/npm-dist-tag/publish.png)

![install](/image/npm-dist-tag/install.png)

明明 beta 和 latest 属于不同的命名空间，为啥这里用 latest 就把 beta 装了？

原因很简单，npm 服务端在初始化一个包时，不论发布者使用了什么 dist-tag，都会同时把它添加到 latest 上。这的确是个不成文的 feature，甚至 Verdaccio 等私服方案也按此逻辑来实现了。

> 为了不污染 npm 环境（或承接相应的骂名），上面测试发布的包已经被笔者下架了 :P

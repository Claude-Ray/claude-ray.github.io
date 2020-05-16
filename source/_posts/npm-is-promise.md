---
title: 从 is-promise 事件我们可以学到什么
date: 2020-05-16 19:35:30
tags: [Node.js,npm,is-promise]
categories: Node.js
---

## 前言

4 月 25 日，NPM 社区又一次因更新事故引燃技术圈的讨论，导火索便来自名为 is-promise 的包。

网上盛传一个单行代码的包影响到了谷歌、FaceBook、亚马逊等众多大咖的知名项目，也有人扬言它使几乎整个 JavaScript 生态陷入了混乱。

不过“雪崩”之时，我和身边人都没有体会到震感，不禁疑惑，平时很少有场景需要判断某个值是否为 Promise，如此名声不显、功能又不重要的 NPM 包，真的有这么大的影响和破坏力吗？

既是好奇心的驱使，也是不认同部分夸张的言辞，我决定向前一探究竟。

<!--more-->

## is-promise 简介

先解读一下事故发生之前，is-promise 2.1.0 版本的完整代码。

```js
module.exports = isPromise;

function isPromise(obj) {
  return !!obj && (typeof obj === 'object' || typeof obj === 'function') && typeof obj.then === 'function';
}
```

这是一个比较宽松的 Promise Like 检查函数，虽然包名叫 is-promise，其实更像 is-thenable。别看只有一行的逻辑，需要不浅的功力才能准确写出。

例如，前置的 `typeof` 能有效过滤 `String.prototype.then = function () {}` 这样不合规范的 thenable 字符串。

我们可以不使用，但不该贬低这个包的价值。Promise/A+ 是一个自由的规范，而非语言特性，长久以来有着众多版本实现，采取这种具有包容性的判断方式是合情合理的。

类似的 NPM 包还有 Sindre Sorhus 的 p-is-promise，它增加了 catch 方法的检查。

## 回顾

让我们一起回到那个周末，重新审视整个事件的始末。

### 时间线

is-promise 作者 Forbes Lindesay 回顾了当时的主要历程：

2020–04–25T15:03:25Z — 发布存在问题的 2.2.0
2020–04–25T17:16:00Z — Ryan Zimmerman 提交了修复 [PR](https://github.com/then/is-promise/pull/15)
2020–04–25T17:48:00Z — 在社交软件上收到告警
2020–04–25T17:54:00Z — 合并 Ryan 的 PR，发布 2.2.1
2020–04–25T17:57:00Z — 阅读并关闭 BUG 相关的 issues，重新开了一帖以便集中[沟通](https://github.com/then/is-promise/issues/20)
2020–04–25T18:06:00Z — Jordan Harband 提到 "exports" 字段仍然存在[问题](https://github.com/then/is-promise/issues/20#issuecomment-619418975)
2020–04–25T18:08:08Z — 从 package.json 中移除 "exports" 字段，发布 2.2.2
2020–04–25T19:20:00Z — 撤销 2.2.0 和 2.2.1

可见，作者收到告警信息后的反应是非常迅速的，但撤销操作滞后的问题仍需要指责。

接下来，我们逐个分析 2.2.x 版本的更迭。


### 2.2.0

- 添加 Typescript 声明文件
- 支持 ES Module 风格的 import

站在上帝视角，我们明确知道问题出在这里，作者在 package.json 中新增了两个字段

```json
{
  "type": "module",
  "exports": {
    "import": "index.mjs",
    "require": "index.js"
  }
}
```

很快，就有人反馈 BUG，一共有两类报错

错误一：exports 的文件路径遗漏了 './'，在 Node.js 中

```
Error [ERR_INVALID_PACKAGE_TARGET]: Invalid "exports" main target "index.js" defined in the package config /xxx/node_modules/is-promise/package.json; targets must start with "./"
```

错误二：添加了 `type: module`，导致 require 被禁用，必须使用 import 才能引入。

```
Error [ERR_REQUIRE_ESM]: Must use import to load ES Module: /xxx/node_modules/is-promise/index.js
```

以及被隐藏的错误三：没有更新 package.json 中的 files 字段，导致 index.mjs、index.d.ts 没有一起打包发布。


### 2.2.1

- 修复错误的 ESM 用法

改动后的 package.json 包含如下

```json
{
  "exports": {
    "import": "./index.mjs",
    "require": "./index.js"
  }
}
```

然而，如果使用 require('is-promise/package.json') 引入模块下其他文件，则会抛出

```
Error [ERR_PACKAGE_PATH_NOT_EXPORTED]: Package subpath './package.json' is not defined by "exports" in /Users/claude/Workspace/test/is-p/node_modules/is-promise/package.json
```

甚至不允许引用 'is-promise/index' 和 'is-promise/index.js'。

### 2.2.2

- 从 package.json 删除 exports 字段

为了彻底解决 2.2.0 带来的 Breaking Change，终于在 2.2.2 删掉了 exports 字段。


### 问题字段解析

本次事故源于两个少见的 package.json 字段，我们已经见识到了其副作用，但还没搞明白为什么会被作者引入，不妨进一步明确它们的概念。

官网文档在 12.x 及以上版本都包含这些字段的描述，但是并不代表 12.x 用户一定享受到了这个特性。


#### type

它决定当前 package.json 层级目录内文件遵循哪种规范，包函两种值，默认为 commonjs。

- commonjs: js 和 cjs 文件遵循 CommonJS 规范，mjs 文件遵循 ESM 规范
- module: js 和 mjs 文件遵循 ESM 规范，cjs 文件遵循 CommonJS 规范

要正常使用这个特性，在 Node.js v12.x 的早期版本，必须主动开启 --experimental-modules。但是从 v12.16.0 以后就有些混乱，不开启选项的情况下错误使用该字段会立即抛出异常。直到了 v13.2.0 正式引入，取消了实验特性的标识，才算恢复正常。

is-promise 将 type 显式指定为 module，显然会影响到特定版本的 CommonJS 用户。


#### exports

`type` 是相对较老的特性，`exports` 则是鲜有人知。

功能来自 [proposal-pkg-exports](https://github.com/jkrems/proposal-pkg-exports) 提案，以实验特性 --experimental-exports 加入 v12.7.0，于 v12.16.0 正式引入。具体时间线可以通过这个 [PR](https://github.com/nodejs/node/pull/29867) 追溯。

下面看它的具体作用。

通常，我们用 main 字段指定包的入口文件，但也仅限于指定唯一的入口文件。

exports 字段是 main 的补充，支持定制不同运行环境、不同引入方式下的入口文件，也支持导出其他文件，看下面的例子便知。

```json
{
  "main": "./main.js",
  "exports": {
    ".": "./main.js",
    "./feature": {
      "browser": "./feature-browser.js",
      "default": "./feature.js"
    }
  }
}
```

但值得注意的是，在支持 exports 的 Node.js 版本中，exports 会覆盖 main.js。

exports 一旦被指定，只能引用 exports 中显示导出的文件。

用下面这种特殊写法，才能允许项目内所有文件被导出（未经过充分测试）。
但缺点是无法使用 `import isPromise from 'is-promise/index’`，而必须带上文件后缀 `import isPromise from 'is-promise/index.mjs'`。

```json
{
  "exports": {
    ".": ".",
    "./": "./",
  }
}
```

此外，作者想当然以为 exports 和 main 字段一样，支持省略 "./"，这在文档中并没有交代。


### 作者复盘

事后，作者发布了一篇 [《is-promise post mortem》](https://medium.com/javascript-in-plain-english/is-promise-post-mortem-cab807f18dcc)，他公开说明了上述的一部分错误，还总结了致使犯错的几个因素

- 习惯于本地发布，不经过 CI 验证
- 使用新特性，CI 却没有添加支持新特性的 Node 版本
- 只验证了代码，没有验证实际发布到 NPM 的包
- 本人不在，其他维护者没有途径发布修复补丁

总结下来就两点，测试不充分，流程不规范。


### 再谈影响

我翻找了相关 ISSUES，发现 [create-react-app](https://github.com/facebook/create-react-app/issues/8896)、[@angular/cli](https://github.com/angular/angular-cli/issues/17549)、[firebase-tools](https://github.com/firebase/firebase-tools/issues/2179) 等项目的确受到影响，具体表现则为安装、构建失败。

再回看 NPM 生态，is-promise 周下载量在千万级，存在直接引用关系的就有 766 个包（现只剩 561，受事故影响，许多包取消了引用），GitHub 显示依赖它的项目更是有 3.5m 之众。

从问题版本 2.2.0 发布，到 2.2.2 修复，历时约 3 个小时，考虑到 NPM 的缓存机制，实际影响时间会被拉长。

因此，它的影响范围的确很广，但实际没有那么夸张。

一方面，Node.js 12.16.0 以前的 LST 和更早版本才是主流，这些运行时可被认定为安全。

另一方面，遭到辐射的项目（大多为 CLI 工具）并不具备整个生态的代表性，也不会危及生产环境。

## 旁观者的思考

看过了问题，也借此反思一下如何避免悲剧发生在自己身上吧。

### 锁定版本

加锁可以 100% 避免本次意外，尤其面向应用开发者，这是一直在呼吁的工作，却很少真正落地。

不要吐槽 package-lock.json 会自己变，因为只有一个 lock 文件是不成气候的，如果 package.json 没有锁定版本，NPM 才会使用浮动的版本覆盖 package-lock.json。

但对于 NPM 包的开发者，除非是对稳定性有所要求的工具链、产品，还是不建议滥用版本锁定。如果所有的 NPM 包都这么做，一定会加大 node_modules 的混乱程度，也不利于及时享受到相关依赖的修复补丁，反而提高了维护难度。


### 单元测试

测试的重要性无须多言。

is-promise 的新增更改根本没有得到测试覆盖，甚至连 require 引入都会报错。除了开发者要完善 CI，NPM 是否也有提供内置检测服务的义务呢？


### 该不该使用小型代码库

小型库背后是众多开源人士的努力贡献，优质的文档、测试用例远超代码的原始价值。

is-promise 的问题不在于它有几行代码，并且代码逻辑没有变更。

个人认为，NPM 包开发者有必要减少依赖数量，应用开发者则可以自由决定。引用也好，套用也罢，但至少请给这些代码的作者和协议应有的尊重。


### 文档不济

2.2.0 这个版本号的使用是否得当，如果只从功能上看，它是向下兼容 2.1.0 的一次更新吗？

看过上面 exports 字段的介绍可以得知，它当然属于 Breaking Change，但 Node.js 文档的描写是模糊的，让 is-promise 的作者认为 exports 是无害的。

官网通篇没有一个警告字样，如果没有这次事故后才提交的 [PR](https://github.com/nodejs/node/pull/33074/files)，恐怕会有更多的人掉入坑中。


### Yarn or NPM

曾经有不少人倾向于 Yarn 的机制，时至今日，Yarn 和 NPM 的差距已经大大收缩，两者都是不错的选择，我唯一建议是不要混合使用。

![publish](/image/npm-is-promise/benchmark.svg)
> Yarn 的速度已经没有特别大的优势

还有像 [PNPM](https://github.com/pnpm/pnpm) 这类致力于改进 NPM 生态的努力，值得我们持续关注。

## 总结

当前仍在批判 NPM 生态的人群，大部分不会参与 JS 社区的建设，愿改善现状而贡献的更是凤毛麟角。

各位 NPM 用户无须危言耸听，人有失手，马有失蹄，只要规范流程，能够有效降低负面影响。

逆耳未必是忠言，希望更多有价值的声音能被发出。

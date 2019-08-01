---
title: 警惕 Travis CI 的 npm 缓存
date: 2019-08-01 21:56:25
tags: [Travis,CI]
categories: CI
---

从 2019 年 7 月份开始，Travis CI 默认开启 npm 缓存。这意味着 node_module 和 package-lock.json 会在初次构建时缓存，倘若后续更新 npm 依赖而不刷新该缓存，可能带来构建失败的问题。

<!--more-->

下面是发现问题的源头。

在为一个项目添加了新的依赖 rimraf 之后，Travis CI 意外地报错：
```
sh: 1: rimraf: not found
```

此时 `.travis.yml` 配置为
```yml
sudo: false
language: node_js
node_js:
  - '8'
  - '10'
before_install:
  - npm i npminstall -g
install:
  - npminstall
script:
  - npm run ci
after_script:
  - npminstall codecov && codecov
```

很明显新增的 npm 依赖没有安装上，但本地测试没有问题，于是替换 npminstall 为原生的 npm install，降低问题排查范围。

```yml
sudo: false
language: node_js
node_js:
  - '8'
  - '10'
script:
  - npm run ci
after_script:
  - npm install codecov && codecov
```

然而移除 npminstall 之后，报错变为
```
Unhandled rejection RangeError: Maximum call stack size exceeded
    at RegExp.test (<anonymous>)
    at /home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/node_modules/aproba/index.js:38:16
    at Array.forEach (<anonymous>)
    at module.exports (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/node_modules/aproba/index.js:33:11)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:37:3)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
    at flatNameFromTree (/home/travis/.nvm/versions/node/v8.16.0/lib/node_modules/npm/lib/install/flatten-tree.js:39:14)
```

之后，去掉 rimraf 依赖于事无济，重跑其他 node 项目的 ci 却一切正常，因此最终确定是 travis 运行环境带来的问题。

果然，寻找刷新方法的过程中发现了右侧 `More options` 中的 `Caches` 选项，点击里面的删除键后，CI 重新运行成功。


# Reference
https://docs.travis-ci.com/user/caching/#npm-cache

> Please note that as of July 2019, npm is cached by default on Travis CI

To disable npm caching, use:
```yml
cache:
  npm: false
```

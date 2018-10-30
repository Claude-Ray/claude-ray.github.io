---
title: Jest共享server和tests的上下文环境
date: 2018-10-30 22:05:19
tags: Jest Test
categories: Node.js
description: 本文首先简单介绍Jest关于启动的配置项，阐述Jest测试生命周期，之后粗略总结不同情况的server应该何时启动，最终使用略粗鄙的办法解决本次问题。
---

# 背景
单元测试，test文件的加载顺序尤为关键。对于服务端，通常先启动http server，再通过发起接口请求的方式展开后续测试。

但仅仅controller层测试不能满足复杂业务的校验，需要对service及以下层级编写测试时，需要切入server的上下文环境才能做出恰当处理。

笔者尝试一番发现Jest并不能优雅地使用配置支持node.js server和test cases共享上下文环境，具体情况将在下文交代。

# Jest配置项说明
jest倾向于将测试执行前的运行环境都加载配置(package.json的jest)中。因此我也先在官网[文档](https://jestjs.io/docs/en/configuration)中查询了相关配置项。

## globalSetup [string]

> This option allows the use of a custom global setup module which exports an async function that is triggered once before all test suites. This function gets Jest's globalConfig object as a parameter.

通过字符串指定一个文件，其exports的函数作为初始化脚本，并支持异步操作。

jest运行测试过程中，此函数只会在所有测试用例加载前执行一次。用途可以是执行安装脚本，初始化数据库等。

需要特别注意的是，此函数运行的上下文环境与接下来的测试用例并无关联。

> 详见issue https://github.com/facebook/jest/issues/6007

```js
// test/setup.js
module.exports = async () => {
  // 这个变量并不会传到test case中
  global.setup = 'setup';
};
```

## globalTeardown [string]
> This option allows the use of a custom global teardown module which exports an async function that is triggered once after all test suites. This function gets Jest's globalConfig object as a parameter.

同globalSetup，该异步函数只会在整个测试生命周期末执行一次。用途可以是运行环境重置，还原或drop数据库等。

```js
// test/teardown.js
module.exports = async () => {
  console.log(`这里和${global.setup}运行环境一致`);
  return process.exit(0);
}
```

## testEnvironment [string]
通常是指定运行环境，默认浏览器，nodejs需要指定为`node`。

当然也可以指定为一个文件。该文件需要继承自`jest-environment-node`，并实现`setup`、`teardown`和`runScript`三个方法。

以官文的demo举例
```js
// test/env.js
const NodeEnvironment = require('jest-environment-node');

class CustomEnvironment extends NodeEnvironment {
  constructor(config) {
    super(config);
  }

  async setup() {
    await super.setup();
    await someSetupTasks();
    this.global.someGlobalObject = createGlobalObject();
  }

  async teardown() {
    this.global.someGlobalObject = destroyGlobalObject();
    await someTeardownTasks();
    await super.teardown();
  }

  runScript(script) {
    return super.runScript(script);
  }
}

module.exports = CustomEnvironment;
```
这里上下文环境支持通过`this.global`将变量共享到每个测试文件。

`jest-environment-node`方法说明：
- setup: 每个test suit（通常指测试文件）执行一次，支持异步方法。

- teardown: 每个test suit执行一次，支持异步方法。

- runScript: 每个小的test都会执行一次，要求用同步，若为异步则执行顺序不可控制。

## setupFiles [array]
同env的setup。

## setupTestFrameworkScriptFile [string]
同env的runScript。

# Jest生命周期

了解jest常用的一些启动配置后，应该对加载顺序有了大概的认知。

```
1.
globaSetup ->

  2.
  env.setup (every test suit) ->
  env.runScript (every test case) ->
  env.teardown (every test suit) ->

  3.
  repeat...

    n.
    -> globalTeardown
```

# Context共享

## 调整Server启动位置
根据不同的测试场景，选择合适的server启动位置：

1. 仅接口层测试。对测试代码的加载流程要求最低，只需要保证测试用例执行前启动http服务即可。可以加在jest的任何一环。如无特殊处理，http服务启动一次就好，放在globalSetup为妙。

2. 多层测试，但controller和service之前耦合度较低，用global存储了少量运行信息。这种情况也简单，可以手动挂在this.global，使测试脚本和server的上下文环境相似。

3. 多层测试，各模块耦合严重，上下文挂载了较多内容，不止global中存储的变量，对原生JS对象方法也做了修改。这时，通过jest的配置无法传递上下文。

针对第三种情况，我选择将测试入口限制为单个文件(test suit)，其他测试文件用`require()`引入。此时，jest的env.setup和setupGlobal效果一致，因为jest认为只是启动了单个测试文件。如下，index.test.js的`beforeAll`具备了所有测试用例的最高优先级，保证server启动早于测试执行，并实现测试用例和server共享上下文。

```js
// test/index.test.js

beforeAll(async () => {
  // launcher server
  await load();
});

// require all test files
require('./file.test.js');

```
综上，总的package.json
```json
{
  "name": "demo",
  "version": "0.0.1",
  "scripts": {
    "test": "jest ./test/index"
  },
  "jest": {
    "testEnvironment": "./test/env.js",
    "globalSetup": "./test/setup.js",
    "globalTeardown": "./test/teardown.js",
    "globals": {
      "testBoolean": true
    }
  }
}
```

## 其他方法
参考egg的做法，统一将上下文放在app，并通过`egg-mock`来获取。

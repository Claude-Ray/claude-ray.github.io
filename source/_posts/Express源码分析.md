---
title: Express源码分析
date: 2017-07-24 22:54:05
tags: [Node.js,Express]
categories: Node.js
description: 新坑，基于 Express@4.15.3 的源码分析，慢慢填
---

# Express源码分析
## 项目整体结构
相较于 ``4.15.2`` ， ``4.15.3`` 又一次移除了所有内部``node_modules``，目录结构恢复整洁。
> ``4.15.2`` 中的内置的 ``node_modules`` 是 ``debug``。

## Express 内部文件
### 1 程序入口 ``index.js``
只是一个简单的入口，导出了``lib/express``。
### 2 应用创建 ``express.js``
1. 从入口程序进入这里，第一句就是
```
exports = module.exports = createApplication;
```
 对这个写法进行总结：
 - API文档中有详细解释， ``exports`` 就是一个shortcut。所有供外部调用的方法或变量均需挂载在exports变量上，
当需要将一个文件当做一个类导出时，就需要通过 ``module.exports`` 而不是 ``exports``。
 - 进一步讲讲， ``exports`` 是 ``module.exports`` 的引用，他们的初值都是空对象 ``{}``。
require加载模块时使用的是 ``module.exports`` 而不是 ``exports``。
搞不清楚关系的一直使用``module.exports``也没问题。
 - module.exports 指向新的对象时，exports 断开了与 module.exports 的引用。
而API上的说法不然， ``When the module.exports property is being completely replaced by a new object, it is common to also reassign exports`` 。
起初我从直观上理解，认为两者说辞是相反的，且经过验证，exports 确实会断开引用。因此是对API说明的理解有偏差。

 ```javascript
// 上面写法等价于

// module.exports 指向新的对象时，exports 断开了与 module.exports 的引用
module.exports = createApplication;
// 若还想使用exports添加属性，让 exports 重新指向 module.exports 即可
exports = module.exports;
 ```

2. ``express.js`` 返回一个 app 作为 ``createApplication`` 的回调函数每个http请求都可以触发执行 ``app.handle`` 来执行中间件。
``app.handle`` 调用了router组件的 ``handle(req, res, out)`` 函数链式执行中间件。
通过 [``merge-descriptors``](#merge-descriptors) 中间件将 ``application`` 和 ``events.EventEmitter`` 合并(类似于继承)到 app 中。
而 ``app.request`` 和 ``app.response`` 通过 ``Object.create`` 方式继承request和response得到。完成以上操作后，调用 ``application.init()`` 进行初始化。
3. 通过 ``exports`` 暴露出 express 内主要的构造器、原型。
4. 末尾处遍历的数组内是已经移除的 ``Express 3.x`` 内置模块，当使用者不知情而直接使用时，提醒他们需要额外安装，提供了更友好的报错信息。
```javascript
[
  'json',
  'urlencoded',
  'bodyParser',
  'compress',
  'cookieSession',
  'session',
  'logger',
  'cookieParser',
  'favicon',
  'responseTime',
  'errorHandler',
  'timeout',
  'methodOverride',
  'vhost',
  'csrf',
  'directory',
  'limit',
  'multipart',
  'staticCache',
].forEach((name) => {
  Object.defineProperty(exports, name, {
    get         : () => {
      throw new Error('Most middleware (like ' + name + ') is no longer bundled with Express and must be installed separately. Please see https://github.com/senchalabs/connect#middleware.');
    },
    configurable: true
  });
});
```
### 3 应用 ``application.js``
#### 初始化 ``app.defaultConfiguration``
1. 虽然在 ``createApplication`` 中调用的是app.init()，但查看 ``application.js`` 的init就会发现，init只是在初始化应用之前为一些属性赋了空值。
```javascript
/**
 * Initialize the server.
 *
 *   - setup default configuration
 *   - setup default middleware
 *   - setup route reflection methods
 */
app.init = () => {
  this.cache = {};
  this.engines = {};
  this.settings = {};
  // 调用真正的初始化方法
  this.defaultConfiguration();
};
```
2. defaultConfiguration解析。
> 在这里单步执行，可以直观查看所有默认默认信息。

 ```javascript
/**
 * initialize application configuration.
 */
app.defaultConfiguration = () => {
  // 初始化app的默认配置
  let env = process.env.NODE_ENV || 'development';

  // default settings
  this.enable('x-powered-by');
  this.set('etag', 'weak');
  this.set('env', env);
  this.set('query parser', 'extended');
  this.set('subdomain offset', 2);
  this.set('trust proxy', false);

  Object.defineProperty(this.settings, trustProxyDefaultSymbol, {
    configurable: true,
    value       : true
  });

  debug('booting in %s mode', env);

  // 监听 mount 事件：当向express添加中间件时就会触发
  this.on('mount', function onmount(parent) {
    // inherit trust proxy
    if (this.settings[trustProxyDefaultSymbol] === true
      && typeof parent.settings['trust proxy fn'] === 'function') {
      delete this.settings['trust proxy'];
      delete this.settings['trust proxy fn'];
    }

    // inherit protos
    // 将每个中间件的request, response, engine, settings对象的__proto__形成原型链
    // 最顶层的request, response对象是Node原生的request和response对象，在createApplication中定义
    // 源码是: setPrototypeOf(this.request, parent.request); ...
    // 等价于
    this.request.__proto__ = parent.request.__proto__;
    this.response.__proto__ = parent.response.__proto__;
    this.engine.__proto__ = parent.engine.__proto__;
    this.settings.__proto__ = parent.settings.__proto__;
  });

  // setup locals
  this.locals = Object.create(null);

  // top-most app is mounted at /
  this.mountpath = '/';

  // default locals
  this.locals.settings = this.settings;

  //default configuration
  this.set('view', View);
  this.set('views', resolve('views'));
  this.set('jsonp callback name', 'callback');

  if (env === 'production') {
    this.enable('view cache');
  }
  Object.defineProperty(this, 'router', {
    get: () => {
      throw new Error('\'app.router\' is deprecated!\nPlease update your app.');
    }
  });
};
 ```
#### 添加中间件 ``app.use``

#### 渲染视图 ``app.render``

### 请求扩展 ``request.js``
### 响应扩展 ``response.js``

## 关联的其他模块
### merge-descriptors
- 源码很简单，通过foreach循环，依次将源对象的元素合并给目标对象。没有用到``Object.defineProperties`` ，而是对每个操作符进行判断。
如果 ``redefine`` (undefined则赋值为true)设置为false并且某一属性目标对象已经包含，则不再进行处理。
```javascript
// merge-descriptors 的简化实现

let hasOwnProperty = Object.prototype.hasOwnProperty;
module.exports = (dest, src, redefine) => {
  // check
  if (!dest || !src) throw new TypeError('dest or src is required');
  if (redefine === undefined) redefine = true;
  Object.getOwnPropertyNames(src).forEach(function forEachOwnPropertyName(name) {
    // skip
    if (!redefine && hasOwnProperty.call(dest, name)) return;
    // copy
    let descriptor = Object.getOwnPropertyDescriptor(src, name);
    Object.defineProperty(dest, name, descriptor);
  });
  return dest;
}
```

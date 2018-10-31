---
title: koa之Content-Type与Content-Length
date: 2018-10-18 22:16:05
tags: [Node.js,JavaScript,Koa]
categories: Node.js
description: 透过ctx.body setter的执行过程，分析koa如何设置响应头content-type和content-length，以及一些注意事项。
---

# Content-Type
众所周知，koa可以方便地通过`ctx.type=`来设置响应头的`Content-Type`。

但下面这段代码，当响应体ctx.body为`object`时，无论怎么设置ctx.type，收到的Content-Type都是`application/json`。

```js
ctx.type = 'text/html';
ctx.body = { type: 'json' };

// 得到的content-type依然为application/json
```

为什么设置被覆盖了，要通过一小段koa源码来解释。

```js
// koa/lib/response.js

set body(val) {
  const original = this._body;
  this._body = val;

  if (this.res.headersSent) return;

  // no content
  if (null == val) {
    if (!statuses.empty[this.status]) this.status = 204;
    this.remove('Content-Type');
    this.remove('Content-Length');
    this.remove('Transfer-Encoding');
    return;
  }

  // set the status
  if (!this._explicitStatus) this.status = 200;

  // set the content-type only if not yet set
  const setType = !this.header['content-type'];

  // string
  if ('string' == typeof val) {
    if (setType) this.type = /^\s*</.test(val) ? 'html' : 'text';
    this.length = Buffer.byteLength(val);
    return;
  }

  // buffer
  if (Buffer.isBuffer(val)) {
    if (setType) this.type = 'bin';
    this.length = val.length;
    return;
  }

  // stream
  if ('function' == typeof val.pipe) {
    onFinish(this.res, destroy.bind(null, val));
    ensureErrorHandler(val, err => this.ctx.onerror(err));

    // overwriting
    if (null != original && original != val) this.remove('Content-Length');

    if (setType) this.type = 'bin';
    return;
  }

  // json
  this.remove('Content-Length');
  this.type = 'json';
}
```
熟悉koa源码的同学可能还记得，如果ctx.type未设置，会根据传给body的值类型赋予`Content-Type`默认值。

- `null/undefined`：type什么的不存在的，即使有也会被删掉，并设置'No Content' 204状态码
- `string`：正则`/^\s*</`匹配，分情况设为html或text
- `Buffer`：如果未设置type，那么会被改为`bin`(application/octet-stream)
- `Stream`：同Buffer，当然逻辑上会多个绑定结束时destroy和异常处理，如果和旧body不同，还会删掉content-length
- 以上都不是：即使设置过`ctx.type`，也会重新标记为json，并删除content-length

可想而知，既然已经过每一步判断，body的内容一般就是`boolean`、`object`或`number`之流，标记为`json`合情合理。当然没忘`symbol`，它是无法被JSON序列化的，会抛出TypeError。

综上，如果接口返回值满足上述几个json类型，又想更改响应头的content-type，最简单的方法其实是`ctx.type=`放在`ctx.body=`之后，以重新覆盖响应头的内容。但一些路由中间件封装的时候没有考虑这层面，把接口返回值作为ctx.body，添加这种在body后设置type的操作可能会遇到困难。

另一种常规方法是调整数据格式后再对ctx.body赋值，例如对object进行JSON.stringify处理后，之前设置的content-type才不会被覆盖为`application/json`。

> ctx.type的设置支持各类缩略词，每次set前都会通过`mime-types`和`mime-db`依赖匹配完整名称，并挂上charset。

Wait，好像还漏了什么？

content-type既然在最后给定为json，为什么执行了一个`this.remove('Content-Length')`？且听下面分解。

# Content-Length

在`set body`的string和Buffer步骤，都会主动判断字节长度（不是字符，所以string用Buffer.byteLength判断），并对this.length即content-length赋值。而json和stream则相反，不但没有设置length，反而把设置过的删掉了。

简单分析一下，stream步骤的删除不难理解，二进制数据流只有传输完毕才能计算长度，不需要从响应头判断length。另一方面，content-length是允许胡乱设置的，koa为了避免它被设置一个错误的值，所以才有了的重新赋值与删除。甚至在异常捕获中也加上了这个fix：[Content-Length not reset if error is thrown after body is set](https://github.com/koajs/koa/issues/199)。

那么json返回值的length被删掉之后，它是从哪里重新被设置呢？

> 最初我错想为交给了node底层处理，而且确实在http模块中有对content-length的设置，但它只有在完全未指定headers时才会添加。[https://github.com/nodejs/node/blob/master/lib/_http_outgoing.js]

实际对json类型的值判断字节长度非常容易，JSON.stringify加Buffer.byteLength即可。目录内搜索一下对this.length或ctx.length的赋值，果然，在响应的最终res.end()之前看到了该处理。
```js
// koa/lib/application.js
function respond(ctx) {
  // ...

  // responses
  if (Buffer.isBuffer(body)) return res.end(body);
  if ('string' == typeof body) return res.end(body);
  if (body instanceof Stream) return body.pipe(res);

  // body: json
  body = JSON.stringify(body);
  if (!res.headersSent) {
    ctx.length = Buffer.byteLength(body);
  }
  res.end(body);
}
```
那为什么不在最后一步重新对content-length进行赋值呢？

我的理解是，set body和onerror时完成自动设置已经是仁尽义至了，会在之后主动设置content-length的人未免不是怀有特殊目的，否则开放的`ctx.length=`功能也毫无用武之地。因此反而能为使用者的发挥留有余地，即使改出了差错也不能怪罪到koa头上。保持目前的写法，恰到好处。

## 小结
koa的源码解析文章实在太多了，所以早先没有打算像express那样写一篇逐句分析，而且确实简单易读，~~恐怕没写完就太监了~~。但时间一久，很多细节就忘掉了，会遇到此类问题说明对其底层不够熟悉。就此写一篇笔记，发出来加深记忆。[真香.jpg]

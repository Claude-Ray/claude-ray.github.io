---
title: 总结node处理GBK编码
date: 2018-12-12 22:49:00
tags: [Node.js,String,GBK编码]
categories: Node.js
---

# 概述
Node内部不支持直接操作GBK字符串，而实际也并不需要如此。

总的原则是，gbk的逻辑仅保留在输入和输出，内部处理一律使用utf8。编码转换主要基于`iconv-lite`库。

总结已经写在了前头，下面再列举几种http服务中常见的处理场景。

# 常见场景

## 请求返回值
最常用且容易处理，通常我们使用`request`发起http请求，options中设置`encoding: null`，这样返回的res.body为buffer，再对buffer进行解码`iconv.decode(res.body, encoding)`。

> 引用：[request返回值中文乱码问题](https://claude-ray.github.io/2018/02/26/request%E4%B8%AD%E6%96%87%E4%B9%B1%E7%A0%81%E9%97%AE%E9%A2%98/#%E7%BC%96%E7%A0%81)

## 请求参数
这里直接用`iconv-lite`处理略显复杂，建议上[urlencode](https://github.com/node-modules/urlencode)。

post请求时stringify整个body对象，用options.form提交。
```js
urlencode.stringify(body, {charset: 'gbk'});
```
querystring则stringify后再拼到url中。
```js
urlencode.stringify(qs, {charset: 'gbk'}); 
```

## 接口返回值
以koa举例，返回值先使用`iconv-lite`转为gbk Buffer，随后设置响应头的content-type。
```js
ctx.body = iconv.encode('你好', 'gbk');
ctx.type = 'text/plain; charset=gbk';
```

## 接口参数
同样以koa举例，结合`koa-bodyparser`，一般http method的原始参数分布在ctx.request.rawBody和ctx.request.querystring中，使用`urlencode.parse`解析。
```js
urlencode.parse(ctx.request.rawBody, {charset: 'gbk'});
urlencode.parse(ctx.request.querystring, {charset: 'gbk'});
```

特别地，当请求格式为multipart或json时需要结合具体情况具体分析。

例如，使用`busboy`等multipart解析库会将请求body挂在`ctx.request.body`上，规范的请求方式是会对字符进行url encode的，这时可以按gbk编码对字段decode（由于不能直接url decode，实际处理方法为转hex后再经buffer解码）。

如果请求参数是经过binary处理的，则binary decode。

综上，处理姿势大致如下。
```js
lodash.mapValues(ctx.request.body, value => {
  if (!value) return value;

  const buff = /^(%\w{2})+$/.test(value)
    ? Buffer.from(value.replace(/%/g, ''), 'hex')
    : Buffer.from(value, 'binary');

  return iconv.decode(buff, 'gbk');
});
```
想兼容更多情况是比较复杂的，即使做基础服务也不必包容所有不规范的传值，大可以拒绝解析，因此按需调整即可。

如果能约定使用十六进制传参更好，处理hex就不需要在参数获取上额外操作了。可惜一般用到gbk的场景都是难以变更的、需要兼容的，否则肯定是让调用方改传utf8，皆大欢喜。

## 读写文件
默认方式（`encoding: null`）就是操作buffer，iconv转换无压力。

读：
```js
const buff = fs.readFileSync('test.txt');
console.log(iconv.decode(buff, 'gbk'));
```
写：
```js
const buff = iconv.encode('你好', 'gbk');
fs.writeFileSync('test.txt', buff);
```

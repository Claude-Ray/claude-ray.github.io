---
title: request中文乱码问题
date: 2018-02-26 22:16:20
tags:
categories: Node.js
description: Node中使用request请求得到的数据为乱码，分析可能的情况并列举解决方案。
---

## gzip
可能是需要开启`gzip: true`
```js
request({url, gzip: true});
```

## 编码

### buffer decode
可以考虑使用`iconv-lite`转换buffer。request设置`encoding: null`时，会返回buffer形式的body。

```js
request({url, gzip: true, encoding : null}, (err, res, body) => {
  const str = iconv.decode(body, 'gb2312');
});
```
> 有个别网站编码不统一，时而gb2312时而utf8，这种情况需要自己判断处理。
可以参考[cnode的回帖](https://cnodejs.org/topic/545de1e1a68535a174fe51b5)——
先请求下来 Buffer, 也就是 request 的时候指定 encoding: null ，得到 Buffer, 用ASCII解码前一千个字符，用正则，匹配出 ; charset=(\w+)"，得到正确的 charset, 再用 iconv-lite 解码出全部的  buff。

### stream pipe
简化一下过程，`iconv-lite`也支持pipe
```js
request(url).pipe(iconv.decodeStream(code));
```

Demo

```js
const request = require('request');
const iconv = require('iconv-lite');

async function name(url, code = 'gb2312') {
  const filename = 'something.txt';
  const tempname = `${Date.now()}.txt`;

  try {
    const writeStream = fs.createWriteStream(tempname);
    await new Promise((resolve, reject) => {
      request(url)
        .pipe(iconv.decodeStream(code))
        .pipe(writeStream)
        .on('close', () => {
          fs.renameSync(tempname, filename);
          resolve();
        });
    });
  } catch (err) {
    console.error(`${url}文件下载失败,${err.message}`);
  }
}
```
---
title: Node获取GBK编码字符串
date: 2017-10-05 08:50:46
tags: String
categories: Node.js
description: Node下如何获取GBK编码的字符串
---

# UTF8 to GBK Hex String
## iconv-lite
通常都会使用 `iconv-lite` 这个包实现Node的编码转换，但是这个包是基于 `Buffer` 的，如果传递给其他语言的系统，需要先转换为 `String` 字符串。

在网上查阅了相关资料，并没有给出很好的解答。一些比较老的回答都在说，Node中无法把Buffer转换成gbk字符串。

俗话说有问题找师兄，果然，咨询同组师兄后得到了期望的结果。转换过程很巧妙，在此分享出来：

```js
const iconv = require('iconv-lite');

function toGBKString(str) {
  return iconv.encode(str, 'gbk')
    .reduce((pre, cur) => `${pre}${cur.toString(16)}`, '');
}
```
以上是不加百分号的，如果需要可以在模板字符串中自行加上。
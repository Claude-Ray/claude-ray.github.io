---
title: Node获取GBK编码字符串
date: 2017-10-05 08:50:46
tags: String
categories: Node.js
description: Node下如何获取GBK编码的字符串
---

# Node.js的编码转换
## iconv-lite
通常都会使用 `iconv-lite` 这个包实现Node的编码转换，但是这个包是基于 `Buffer` 的，如果传递给其他语言的系统，需要先转换为 `String` 字符串。

在网上查阅了相关资料，并没有给出很好的解答。一些比较老的回答都在说，Node中无法把Buffer转换成字符串。

但是师兄教了我一招

```js
const iconv = require("iconv-lite");

function toGBKString(str){
  return iconv.encode(str, 'gbk')
    .reduce((pre, cur) => `${pre}${cur.toString(16)}`, '');
}
```

还有这种操作？？

真的要好好学习JS了
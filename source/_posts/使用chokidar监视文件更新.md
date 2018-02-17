---
title: 使用chokidar监视文件更新
date: 2018-01-27 12:57:42
tags: 
categories: Node.js
description: 为了提高文件读取效率，有时会将文件内容缓存到内存再使用。但是当文件发生更改，如何将改动更新到缓存而又不重启Node进程。
---

## 监视文件

使用`chokidar`，可以监视指定路径下目录、文件的变动。由于我只关注更改，因此监视`change`事件即可。
```js
'use strict';

const fs   = require('fs');
const path = require('path');

const chokidar = require('chokidar');

module.exports = watchChange;

/**
 * 监听目录或文件变动
 * @param {string|array} paths    目录或文件路径
 * @param {function}     onChange 回调函数
 * @return {Promise.<*>}
 */
function watchChange(paths, onChange) {
  if (typeof onChange !== 'function') throw Error(`onChange (${onChange}) is not a function`);

  if (!Array.isArray(paths)) paths = [paths];

  paths.forEach(path => {
    if (!(path && fs.existsSync(path))) throw Error(`can't find path ${path}`);
  });

  chokidar.watch(paths)
    // .on('add', filepath => {console.log('you can watch more events by chains')})
    .on('change', filepath => {
      const filename = path.basename(filepath);
      onChange(filename);
    });
}
```

## 更新缓存

为了避免每次取内容都读文件，使用了`lodash.memoize`缓存读取结果。

```js
async function readFile(params) {
  return;
}

const getFile = _.memoize(readFile);
```
要更新这部分缓存，可以使用如下方法。用大文件测试了内存占用，没有泄露产生。

```js
getFile.cache.set(file, readFile(file));
```

完整部分，加上了try catch。
```js
function watchTpl() {
  try {
    watchFiles('./test', file => {
      getFile.cache.set(file, readFile(file));
    });
  } catch (err) {
    console.error(err);
  }
}

watchTpl();
```

## 小结
由于使用场景明确，代码实现较简单，没有考虑太多情况，也算不上热更新。但借这种思路，可以完成配置文件甚至功能模块的更新。

## References
[Node监视文件以实现热更新](https://ngtmuzi.com/Node监视文件以实现热更新/)
[Node.js Web应用代码热更新的另类思路](http://fex.baidu.com/blog/2015/05/nodejs-hot-swapping/)
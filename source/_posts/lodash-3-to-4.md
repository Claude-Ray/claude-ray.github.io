---
title: lodash3升级4踩坑
date: 2017-10-05 09:15:09
tags: [Lodash,npm]
categories: Node.js
description: 记录lodash升级过程中不兼容的点，以及偶遇的npm包安装异常。
---

## lodash版本问题

近期更新了lodash包，`3.x` 到最新的 `4.17.x`，然后就发现系统拿不到数据了。

最终定位到 `lodash.merge` 方法。

lodash.merge有一个常用的特性，即._merge(source, [...abc])，merge会自动过滤到后面参数中undefined的属性。然而，`4.17.x` 的 lodash 不再支持。这个是根据论坛其他人的评论和官方的history.md发现的，然而一年过去了，lodash的官方文档却没有更新这一点……

如果仍想用到过滤 `undefined` 的特性，就需要使用 `_.omitBy(myObj, _.isNil)` 或者 `_.pickBy(myObj)` 包装或替换原使用 `_.merge(myObj, [...source])` 的地方。

## npm安装失败

升级lodash的过程中，在某个服务器失败了，报错内容为：

> nnpm ERR! path /var/xxx/node_modules/fs-extra_back/node_modules/graceful-fs/node_modules/natives npm ERR! code ENOENT npm ERR! errno -2 npm ERR! syscall access npm ERR! enoent ENOENT: no such file or directory, access '/var/xxx/node_modules/fs-extra_back/node_modules/graceful-fs/node_modules/natives' npm ERR! enoent This is related to npm not being able to find a file. npm ERR! enoent npm ERR! A complete log of this run can be found in: npm ERR! /root/.npm/_logs/2017-09-29T07_39_30_928Z-debug.log

google了一下 `ENOENT` 相关错误，提取众人反映问题的共同点就是，npm5。在npm4甚至3的环境下是没有这种情况的，服务器也是近期升级了npm版本。
不过比起npm降级，采取了更简便的方法，将access '/xxx'的npm包删除就好啦~

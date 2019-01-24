---
title: Nginx改写$args未生效踩坑
date: 2019-01-24 21:45:26
tags: [Nginx]
categories: Nginx
---

## 问题
原始需求是通过 nginx 在请求链接中增加一个固定参数 custom_param，方法很简单，在 location 中重设 `$args`。

```sh
# in location xxx
set $args $args&custom_param=test;
proxy_pass http://remote_host;
```

顺便说一下，即使链接中没有参数也不影响一般服务端解析，符号`?`会自动加上，如上例子 proxy_pass 后会路径将变成 http://remote_host/xxx?&custom_param=test。

但问题是在服务器如此配置 nginx 后，custom_param 参数并没有如约发给 remote_host……

<!--more-->

最终在 nginx change log 中找到了原因。

> http://nginx.org/en/CHANGES Changes with nginx 1.7.1          27 May 2014
>
> Bugfix: a "proxy_pass" directive without URI part might use original
  request after the $args variable was set.
  Thanks to Yichun Zhang.

可以看出是nginx很早就修复的 bug，可以肯定到手的 nginx 版本太旧了，又试了版本 1.6.2 果然也存在问题，bug 存在的版本不多，相关资料很少。

在不升级 nginx 的情况下，修复方案是采用旧的参数附加方式`$uri$is_args$args`，如下

```sh
set $args $args&custom_param=test;
proxy_pass http://remote_host$uri$is_args$args;
```

## 小结
很多软件包的疑难杂症都可以试着查阅 change log，而且有些情况下检索历史变更比查 issue 更方便。之前[《lodash3升级4踩坑》](https://claude-ray.github.io/2017/10/05/lodash-3-to-4/) 一文提到的 lodash 升级大版本导致 merge 用法变更，也是查 history 定位到了问题。

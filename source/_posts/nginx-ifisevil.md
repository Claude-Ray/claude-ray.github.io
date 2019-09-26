---
title: Nginx 的 if 使用须知
date: 2019-01-09 22:42:14
tags: [Nginx, If Is Evil]
categories: Nginx
---

有关被 nginx 官方自我批判的 if 语句，《[If Is Evil](https://www.nginx.com/resources/wiki/start/topics/depth/ifisevil/)》—— 着实应成为每位开发者初次使用 nginx if 之前必读的文章。

即使笔者一年前就开始接触使用 nginx 和 if 的组合做 url 跳转，但涉及的功能太简单，一直没能见识到它的真面目。直到近期在多个 if 内处理 proxy_pass 时，噩梦果真就降临了……希望大家仔细阅读上面的文章，引以为戒。

如果想快速知道为什么 “if is evil”，以及如何避免被坑，可以向下阅读一探究竟。
<!--more-->

# Why
nginx if 语句其实是 rewrite 模块的一部分，尽管在非 rewrite 环境下也可以用，但必须要意识到这是一种误用，因此才能理解为何它会引发众多意料之外的问题。

# How
下面的示例代码引自 If Is Evil 的 [Example 部分](https://www.nginx.com/resources/wiki/start/topics/depth/ifisevil/#examples)，用 30 秒即可浏览大部分 evil 场景。

1. 只有 X-Second 会被设置
```nginx
location /only-one-if {
    set $true 1;

    if ($true) {
        add_header X-First 1;
    }

    if ($true) {
        add_header X-Second 2;
    }

    return 204;
}
```
2. proxy_pass 不会生效
```nginx
location /proxy-pass-uri {
    proxy_pass http://127.0.0.1:8080/;

    set $true 1;

    if ($true) {
        # nothing
    }
}
```
3. try_files 不会生效
```nginx
location /if-try-files {
     try_files  /file  @fallback;

     set $true 1;

     if ($true) {
         # nothing
     }
}
```
4. nginx 将发出段错误信号 SIGSEGV
```nginx
location /crash {

    set $true 1;

    if ($true) {
        # fastcgi_pass here
        fastcgi_pass  127.0.0.1:9000;
    }

    if ($true) {
        # no handler here
    }
}
```
5. alias 无法正确地被继承到由 if 创建的隐式嵌套 location 中
```nginx
location ~* ^/if-and-alias/(?<file>.*) {
    alias /tmp/$file;

    set $true 1;

    if ($true) {
        # nothing
    }
}
```

# 如何避免
既然 if 如此之坑，最好的办法就是乖乖禁用 if，但拗不过诸位喜欢折腾的灵魂，特殊场景还是可以用的。下面列举最常见的避坑方案。

## 官方认可的两种用法
再怎么说，if 是为 rewrite 服务的，在正确的场合做正确的事，没毛病。
```nginx
#The only 100% safe things which may be done inside if in a location context are:

return ...;
rewrite ... last;
```

## proxy_pass 中及时 break
当处理各种跳转逻辑时，假设你不期望因为多传了个等于 "hi" 的参数 parma2，就导致 `param1 ~ "hello"` 的跳转失败，那么应该在合适的地方增加 break。
```nginx
location /proxy-pass-uri {
    set $true 1;

    if ($arg_param1 ~ "hello") {
      proxy_pass http://127.0.0.1:8080/;
      # 这里的 break 将阻止下面 if 的执行
      break;
    }

    if ($arg_param2 ~ "hi") {
      # anything
    }

    proxy_pass http://127.0.0.1:8082/;
}
```
> 此外，也可以通过调整 if 的顺序来规避风险，但是容错率比 break 低了很多

## 使用 lua
> https://github.com/openresty/lua-nginx-module

具体来说，通过安装 lua 和 lua-nginx-module( 或 OpenResty ) 来增强 nginx 的逻辑处理，可以称为目前最流行有效的处理方案。lua 扩展带来的好处远不止 if 语句的避坑，例如带来方便地读取 POST 请求体的内容等便利操作。网上资料齐全，这里不多赘述。

## 使用 njs
> http://nginx.org/en/docs/njs/index.html

nginScript (njs) 是 nginx 在 2015 发布的 javascript 配置方案。类似于 lua-nginx-module，它也需要安装相关依赖模块。但有官方做后盾的 njs，比起 lua 要更为轻量，不需要完整的语言运行环境。并且针对 nginx 环境进行设计，理论上有更高的优化空间。

# 小结
到此，坑点和避坑的方法都阐明了，如果还想了解 nginx if 背后的机制，或有其他疑问，请继续探寻《If Is Evil》原文吧！

# Reference
- https://www.nginx.com/resources/wiki/start/topics/depth/ifisevil/

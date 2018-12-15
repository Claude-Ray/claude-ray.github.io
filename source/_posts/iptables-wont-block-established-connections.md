---
title: iptables不会主动断开已有连接
date: 2018-12-15 18:48:24
tags: [iptables,Linux]
categories: Linux
---

## What?

源于一次mongodb超时问题查证。具体表现是服务响应异常缓慢，mongodb查询甚至报出`cursor id not found`。

在排除网络连通性和主机自身因素后，继续回归mongo连接异常的点上，直到发现mongo集群的iptables没有开放mongo端口，开墙后一切恢复正常。

## Why?

据查证，防火墙关闭mongo端口已经有一段时间了，为什么很久之后才出现连接不上的问题？

因为iptables不会主动断开已经建立的连接，这不是`packet filter`的职责所在。

但它依然有办法阻止现有连接的数据包（iptables的过滤基于数据包而非连接）。只不过，通常我们配置防火墙时都会加上一句：
```
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
```
这就导致了已建立的连接可以无障碍地继续传输。

正因如此，mongodb的连接早已建立，被iptables置于ESTABLISHED中，所以不会受到仅ip规则更新的影响。当业务进程重启、网络波动等情况导致旧的连接断开时，将无法重新连接。

## Reference

https://linux.die.net/man/8/iptables

https://serverfault.com/questions/785691/how-does-one-close-all-existing-tcp-connections-on-some-ports-using-iptables

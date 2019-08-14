---
title: Nginx SWRR 算法解读
date: 2019-08-10 13:13:49
tags: [Nginx, load balance]
categories: Nginx
---

Smooth Weighted Round-Robin (SWRR) 是 nginx 默认的加权负载均衡算法，它的重要特点是平滑，避免低权重的节点长时间处于空闲状态，因此被称为平滑加权轮询。

> 该算法来自 nginx 的一次 commit：[Upstream: smooth weighted round-robin balancing](https://github.com/phusion/nginx/commit/27e94984486058d73157038f7950a0a36ecc6e35)

在阅读之前，你应该已经了解过 nginx 的几种负载均衡算法，并阅读了 SWRR 的实现。

介绍此算法的文章有很多，但还没发现哪里用数学角度给出证明过程的，虽然并不复杂，这里把自己粗劣的思路分享一下。为了便于理解，只考虑算法核心的 current_weight，忽略受异常波动影响的 effective_weight。

<!--more-->

---

假设有三个服务器节点 A B C，它们的权重分别为 Wa、Wb、Wc 并保持不变。根据 SWRR 算法，用 CWa CWb CWc 分别表示每台服务器的当前权重，初始值均为 0。Wn 表示所有服务器节点权重的总和，即 Wn = Wa + Wb + Wc。

每次开始选择，各节点的 CW 会增加对应 W 值的大小。从中选择 CW 最大的节点，并将其值减去 Wn。

不妨设 A 为权重最大的节点，首次开始选择时，当前权重均为 0

|CWa|CWb|CWc|
|---|---|---|
|0|0|0|

经过加权

|CWa|CWb|CWc|
|---|---|---|
|Wa|Wb|Wc|

W 中最大值为 Wa，减去 Wn，可以表示为 CWa = Wa - Wn = 0 - (Wb + Wc)

|CWa|CWb|CWc|
|---|---|---|
|1 * Wa - Wn * 1|Wb|Wc|
|-(Wb+Wc)|Wb|Wc|

依此类推，第二次选择之后，CW 变为

|CWa|CWb|CWc|
|---|---|---|
|2 * Wa - Wn * 2|2 * Wb|2 * Wc|

根据算法，无论选择哪个节点，每次轮询的操作等于降低最大的权重，逐步提高最小值的权重，但 CW 的总和始终为 0。

不妨设 n = n1 + n2 + n3，每次选择的结果都可以表示为
```
0 = n * Wa + n * Wb + n * Wc - n * Wn
  = (n * Wa - n1 * Wn) + (n * Wb - n2 * Wn) + (n * Wc - n3 * Wn)
  = (n ＊ Wa - n * Wn) + Wb + n * Wc
```

第 n 次选择之后，CW 等同于

|CWa|CWb|CWc|
|---|---|---|
|n * Wa - Wn * n|n * Wb|n * Wc|


因此当选择次数达到 Wn 时，平衡关系为

```
Wn * 0 = Wn * (Wa + Wb + Wc - Wn)
       = (Wn * Wa - Wa * Wn) + (Wn * Wb - Wb * Wn) + (Wn * Wc - Wc * Wn)
```

此时 CW 又重新回到 0 的起点，证得此轮询是一个周期，且周期长度等于权重之和，每个节点分别被选中了等于各自权重值的次数。

更多节点的证明同上。

---

相比普通的轮询选择，高权重的节点在此过程中不断让权给低权节点，实现平滑轮询。

至于增加了的 effective_weight 概念，变数在于每次选中后 CW 减去的 Wn 总权重变为总当前权重。随着代码阅读很容易理解，就不单独证明了。

## update
碰巧读到了这篇 [nginx平滑的基于权重轮询算法分析](https://tenfy.cn/2018/11/12/smooth-weighted-round-robin/)，里面证明严谨多了，XD，是我之前想看的数学推理，在此推荐。

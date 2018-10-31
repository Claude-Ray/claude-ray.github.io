---
title: 阿里云验证码node接入
date: 2018-07-31 22:51:14
tags: [Node.js,Captcha]
categories: Node.js
description: 分享接入过程和心得
---

## 文档地址
首先放出~~不是那么~~重要的文档地址。

我认为值得看的是使用说明中的流程图，其他感兴趣的信息可以在文档左侧菜单查找。
- [滑动验证使用说明](https://help.aliyun.com/document_detail/66306.html)
- [签名机制](https://help.aliyun.com/document_detail/66349.html)
- [阿里云全部SDK](https://develop.aliyun.com/tools/sdk)

明明很重要的参数说明，太坑了，看不看都一样。
- [验证码服务端API](https://help.aliyun.com/document_detail/66340.html)
- [公共参数](https://help.aliyun.com/document_detail/66348.html)

## 接入流程
不得不说接入过程比geetest痛苦多了，后续会上传相关代码以供参考。关键是阿里云验证码版本号太多，我不想维护一个非官方SDK，因此也不会发布npm。

### 1. 阿里云控制台
- 添加用户，拿到`AccessKeyID`和`AccessKeySecret`
- 在`安全`->`数据风控`配置验证码，拿到`AppKey`，同时可获取接入demo。(虽然配置时要选择使用场景，而且只能靠单选生成一个`original scene`，实际使用时`Scene`参数可以自定义传递。)

### 2. 下载其他版本SDK
很有必要，踩的坑全靠这一步来填。这里选择了php版sdk，前面提到阿里文档的参数并不准确，重点看以下文件补全参数。
- `aliyun-php-sdk-afs/afs/Request/V20180112/AuthenticateSigRequest.php`
- `aliyun-php-sdk-core/RpcAcsRequest.php`

### 3. 计算签名
官方文档还算详细，更方便的是直接参考阿里云node-sdk的开源实现，如`https://github.com/willin/waliyun`。
> 请求方式的不同，会决定signature是否需要经过编码。

### 4. HTTPS请求
GET和POST都支持，只需留意签名计算的区别。
为了避免各种请求模块对参数的编码进行再次转换，省心的做法是拼接完整url后使用GET请求。

### 5. 付费模式
友情提示一下，官网明说`免费调用周期7天`，结果试用两天就收到0.08元欠费通知，找了半天没看到扣费明细，心塞T_T

应该是直接进入了后付费模式，因此测试时请做好心理准备。

## 心得

不可轻信文档，特别是神奇的日期格式版本号Version，公共参数居然给定了取值`2016-11-23`，但没给验证地址。

事实上新旧Version的验证地址并不相同。在不知情时用错误地址进行校验，一直提示InvalidVersion，并且没有对应的错误返回值文档。

除了验证地址，不同Version下需要提交的必选参数也不同，详情需要去其他版本SDK挖掘。

看得出文档内容比前人吐槽的时候丰富了不少，望相关开发人员及时更新。

### SDK实现

[aliyun-captcha](https://github.com/Claude-Ray/aliyun-captcha)
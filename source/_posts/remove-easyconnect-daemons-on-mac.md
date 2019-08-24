---
title: Mac 上移除 EasyConnect 常驻后台进程
date: 2019-08-24 1:20:41
tags: [EasyConnect,EasyMonitor,ECAgent]
categories: Mac
---

想必大家已经知道，EasyConnect 会在后台强行添加名为 EasyMonitor 的开机自启守护进程，网上已经有关闭教程了

```sh
# 权限不足时补上 sudo
launchctl unload /Library/LaunchDaemons/com.sangfor.EasyMonitor.plist
```

可实际上 EasyConnect 还启动了另一个“杀不掉”的后台进程 ECAgent，活动频率很低，似乎不会造成内存泄漏，略显不起眼。但这无法作为它肆意常驻的理由。
<!--more-->

# 禁用

首先找到 plist 文件，在 `/Library/LaunchAgents/com.sangfor.ECAgentProxy.plist`。它无法被 launchctl unload，不过没关系，你可以直接把它挪走或删除，并且今后都不再需要它。

```sh
sudo mv /Library/LaunchAgents/com.sangfor.ECAgentProxy.plist ~
```

当然这时候它还是不能被 kill 掉，要想从 launchctl 中删除而不重启电脑，可以采用 launchctl remove。

```sh
launchctl remove com.sangfor.ECAgentProxy
```

# 启用

关闭后台进程之后，启动 EasyConnect 会弹出警告：

```
Alert

Initialization failed. Please try reinstalling!
```

没办法，只能向恶势力低头，需要使用时，必须重新加载 EasyMonitor。

```sh
launchctl unload /Library/LaunchDaemons/com.sangfor.EasyMonitor.plist
```

而 ECAgent 就没这么麻烦了，它根本不必后台常驻 —— EasyConnect 启动时会自己创建一个，并且会随着 EasyConnect 进程一起退出。最终我删掉了 `com.sangfor.ECAgentProxy.plist` 文件的备份。

# Reference
- [Mac 下禁用开机自启软件](https://blog.jiayx.net/archives/274.html)

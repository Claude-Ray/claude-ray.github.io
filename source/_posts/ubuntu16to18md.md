---
title: ubuntu16.04升级18.04LTS
date: 2018-08-23 21:16:15
tags: Ubuntu
categories: Linux
description: 上个月第一次收到升级推送，当时工作较重又担心出现问题就拒绝了。今天又收到推送，恰好本地没有怕丢的代码，但是经验不足，直接通过推送窗口点击了同意，接下来虚惊一场。次日，桌面系统再次崩溃，强烈建议不要升级而是彻底重装!
---

## 踩坑

### - 进度缓慢
部分软件需要手动输入y/n来决定一些新旧配置项的取舍，长时间不去查看就会一直卡着。

### - 桌面崩溃
由于加了一些界面美化插件，非常担心桌面崩溃，果然更新了三分之一就跪了。

尝试注销桌面系统，过一会儿屏幕上只剩一个鼠标，凉凉。
```
sudo pkill Xorg
```

为了恢复工作，尝试重新安装
```
sudo apt install --reinstall ubuntu.desktop
```
但提示`Could not get lock /var/lib/dpkg/lock`，尝试强制获取lock
```
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock
```
这时再执行reinstall ubuntu.desktop时，提示需要
```
sudo dpkg --configure -a
```
电脑硬盘不好，漫长的等待。此时一边在命令行工作，一边，等到上面指令终于执行完毕，基本上心态已崩，揣着重装系统的念头，(此时一定要做好数据备份)。

继续尝试重启`shutdown now -r`无效，按提示`systemctl reboot -i`成功启动

## 善后
惊喜是一次重启就成功了，部分软件如redshift提示无法使用，原因是缺了一些依赖，重新下载即可。

但是打开浏览器发现无法上网，但系统提示网线已连接，第一反应是dns，修改了`/etc/resolv.conf`没效果，又习惯性用ssh测远程连接，再次失败陷入误区。当发现使用ip和端口可以访问服务时才彻底意识到是dns的问题。

### - 修改dns
ubuntu修改dns两种方式，并不包含直接修改`/etc/resolv.conf`。

编辑`/etc/resolvconf/resolv.conf.d/base`，文件初始内容为空，加上`nameserver 8.8.8.8`，之后需执行
```
resolvconf -u
```
才会正确生效并写入`/etc/resolv.conf`。

另一种方式是直接修改`/etc/network/interfaces`。

### - 修复ssh
升级之后使用ssh提示`permission denied (publickey)`，最快排查办法是带上参数`-vvv`，我这里的错误是未指定私钥文件，使用`-i`加私钥路径可解。

当然不想每次都-i，因此可以将公钥私钥放在id_rsa，id_rsa.pub。同时不想每次都输入密码，执行`ssh-add ~/.ssh/id_dsa`。

注意密钥权限只能属于使用者，文件400权限就好，超过权限范围会提示Permissions too open。

### - 18.04部署攻略
重装redshift时发现有人整理了一些安装指令，可以方便大家部署新系统。

[https://github.com/erikdubois/Ultimate-Ubuntu-18.04](https://github.com/erikdubois/Ultimate-Ubuntu-18.04)


## 小结
由于桌面系统相当脆弱，一定要通过命令行来完成升级，也方便处理异常。出现问题升级不一定中断，不要急着重启，避免让问题严重到系统无法访问。

不要听信网上的无痛升级论，做好数据备份，谨慎操作。

### 16-08-24更新
桌面系统再次崩溃，详情可以看这个[Bug](https://bugs.launchpad.net/ubuntu/+source/gdm3/+bug/1779476)，并且在论坛找到了非常相似的[遭遇](https://ubuntuforums.org/showthread.php?t=2391542)。

起初还不清楚是什么状况，试过了swapoff，gnome重装，gdm3降级，切换lightdm等等，看到bug反馈时终于决定接受了各位前人的重装解决方案。

顺便碰到了双系统不能上网问题，修复较容易，BIOS 关闭`wake on lan`，如果已经关闭就重新打开再关闭。
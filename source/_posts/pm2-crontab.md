---
title: crontab 中使用 pm2
date: 2019-01-03 21:56:48
tags: [pm2,crontab]
categories: Linux
---

本篇不是讲如何处理代码内的定时任务，而是聊聊怎么借助 crontab 等工具，定时操作 pm2 (指令)。例如，定时重启 pm2 中的进程、定时执行 pm2 save 保存运行状态，等等。
<!--more-->

# 重启进程

`pm2 --help` 可以看到 pm2 自带 cron 功能，但功能仅限于重启进程。

```sh
Usage: pm2 [cmd] app

Options:

-c --cron <cron_pattern>     restart a running process based on a cron pattern
```

# 执行指令

执行指令包括重启 pm2 内的进程，并且可以定时调用 pm2 做任何它支持的事。这种情况下，使用系统层面的 `crontab` 就对啦。

需要注意的是，pm2 在 crontab 中的运行 PATH 和 在 命令行 shell 中直接执行并不一样，因此会报 `pm2: command not found` 之类的错。

```sh
# 错误示范
*/1 * * * * pm2 flush > /var/log/pm2flush.log 2>&1
```

解决方法是在使用pm2的脚本中指定环境变量，参考`which pm2`，找出pm2的bin路径。

一般是通过`npm i pm2 -g`全局安装，环境变量是`/urs/local/node/bin`。如果你使用nvm，那可能是`/home/yourname/.nvm/versions/node/vX.X.X/bin`。

# 举例
## pm2 flush
例如我们要定时清除 pm2 的 log 文件，节省磁盘空间，可以使用 pm2 自带的 flush 命令。

## 直接执行
一种是直接在定时器执行 pm2 flush
> PATH 的指定要结合具体情况，常见的做法是命令行 `echo $PATH`，把输出内容补到指令的 PATH 中

```sh
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/node/bin

*/1 * * * * pm2 flush > /var/log/pm2flush.log 2>&1
```

## 间接执行
另一种是定时调用任务脚本，通过脚本间接执行 pm2 flush，这样方便我们同时做其他处理，如删除日志前先打包备份。

在 crontab 中，内容如下
```sh
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/node/bin

*/1 * * * * sh /home/root/pm2flush.sh > /var/log/pm2flush.log 2>&1
```

再来看它执行的 `pm2flush.sh` 文件
```sh
# 如果crontab中不指定node bin的PATH，也可以在这里通过如下方式指定
# PATH=$PATH:/usr/local/node/bin
pm2 flush
```
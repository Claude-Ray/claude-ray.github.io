---
title: Ubuntu配置ss-local客户端
date: 2018-12-01 22:03:28
tags: [Ubuntu,proxy]
categories: Linux
description: 近期Evernote因为局域网问题不能使用了，作为重要工具不能离手，于是借助ss代理方式应急一下。ubuntu18没有特别好用的ss GUI，故选择了命令行工具ss-local。部署没难度，操作流程是翻文档加自己探索，个人认为比网上其他攻略简单，分享出来希望有助于大家解决网络疑难杂症。同时声明，本文只涉及客户端部署，evernote.com截止文章发布时间并没有被墙，请使用国内云服务器代理合规站点。
---

ss-local是[shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)提供的客户端工具，若想正常使用需先准备一台机器部署shadowsocks服务端以作为代理。

## 一、安装准备
Ubuntu 16以上直接用apt安装，其他发行版可以查阅文档https://github.com/shadowsocks/shadowsocks-libev#installation
```sh
sudo apt update
sudo apt install shadowsocks-libev
```

## 二、编辑配置文件
### 配置代理服地址
参考config.json修改local.json，填写代理服务器的地址。
```sh
sudo cp /etc/shadowsocks-libev/config.json /etc/shadowsocks-libev/local.json
sudo vi /etc/shadowsocks-libev/local.json
```
建议`local_port`不要使用默认的1080，例如改为1081。主要是避免和ss-server（在安装后默认作为`shadowsocks-libev.service`启动）抢占端口，或者选择手动停掉ss-server。
```json
{
  "server": "代理服地址",
  "server_port": "代理服端口",
  "local_port": 1081,
  "password": "代理服密码",
  "timeout": 60,
  "method": "chacha20-ietf-poly1305"
}
```

### 配置systemd service
```sh
sudo vi /lib/systemd/system/shadowsocks-libev-local@.service
```
替换其中ExecStart的配置路径
```
ExecStart=/usr/bin/ss-local -c /etc/shadowsocks-libev/local.json
```

## 三、启动服务
使用systemctl或service管理服务
```sh
#启动
sudo systemctl start shadowsocks-libev-local@.
#或 $ sudo service shadowsocks-libev-local@.service start
#查看运行情况
sudo systemctl status shadowsocks-libev-local@.
#配置开机自启
sudo systemctl enable shadowsocks-libev-local@.
```

## 四、配置PAC文件
PAC的语法是js，规则非常简单。核心点是实现`FindProxyForURL`函数，判断当前域名是否使用代理，不需要代理的域名直接返回`DIRECT`。

因此内容自己实现就可以，但不支持es6及以上特定，这里参考[genpac](https://github.com/JinnLynn/genpac)加上endsWith的polyfill。

```js
// 端口号按之前配置local.json的local_port来填写，默认1080
var proxy = 'SOCKS5 127.0.0.1:1081';

// 走代理的host
var hosts = [
  'evernote.com'
];

function FindProxyForURL(url, host) {
  for (var i = 0; i < hosts.length; i++) {
    if (host.endsWith(hosts[i])) return proxy;
  }
  return 'DIRECT';
}

/**
 * REF:
 * genpac 2.1.0
 * https://github.com/JinnLynn/genpac
 * https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/endsWith
 */
if (!String.prototype.endsWith) {
  String.prototype.endsWith = function(searchString, position) {
    var subjectString = this.toString();
    if (typeof position !== 'number' || !isFinite(position) || Math.floor(position) !== position || position > subjectString.length) {
        position = subjectString.length;
    }
    position -= searchString.length;
    var lastIndex = subjectString.indexOf(searchString, position);
    return lastIndex !== -1 && lastIndex === position;
  };
}
```

## 五、配置系统代理
这一步可以通过export来设置，但没找到automatic的配置方法，干脆用系统自带的proxy来处理。按如下步骤一路点，最后填上PAC文件的路径。

Network -> Network proxy -> Automatic -> Configuration URL -> `/etc/proxy/my.pac`

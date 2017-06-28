---
title: Hexo搭建过程
date: 2017-06-18 22:09:28
tags: Hexo
categories: Hexo
description: 使用Hexo打造个人GitHub Pages的简要过程
---

### 安装
这里只列出 hexo 的简明搭建方法，不讲“是什么”和“为什么”，关于 hexo 的更多配置和用法请前往 [Hexo Docs](https://hexo.io/docs/)  了解。

#### Node.js 环境
必须安装Node，方式任选，不多说
#### 安装 Hexo
通过 Node 的 npm 安装 Hexo，命令行输入
```bash 
$ npm install -g hexo-cli 
```

#### Hexo 初始化
```bash
$ hexo init <folder> # 初始化项目名称 
$ cd <folder> 
$ npm install # 安装模块 
```

#### 预览
```bash
$ hexo clean # 必要时，清除上次生成页面时造成的缓存 
$ hexo g  # 生成静态页面 
$ hexo s  # 在本地启动Hexo，可以在浏览器访问 localhost:4000 来预览
```

#### GitHub 支持
首先在 GitHub 按照 ``username.github.io`` 的格式新建仓库，之后在项目根目录下执行
```bash
$ npm i hexo-deployer-git --save  
```
打开 ``_config.yml`` ，编辑 ``deploy``字段，注意替换用户名
```
deploy:
  type: git
  repo: git@github.com:yourusername/yourusername.github.io.git
  branch: master
```
配置完成后，只需执行
```bash
$ hexo d
```
即可将本地内容部署在 GitHub 中，输入域名 ``username.github.io`` 进行访问

### 配置主题

> 如果不喜欢默认主题，可以参考如下方式更改。

要把主题更换为Next，先定位到Hexo站点目录进行安装
```bash
$ cd your-hexo-site
$ git clone https://github.com/iissnan/hexo-theme-next themes/next
```
之后打开站点配置文件 ``_config.yml``，修改 ``theme`` 字段值为 ``next``
```
theme: next
```
#### 修改Scheme

Next主题提供了3种Scheme，也决定了外观细节，需要在主题配置文件 ``themes/next/_config.yml`` 中进行修改，通过注释和反注释三选一。
```
# Schemes
#scheme: Muse
scheme: Mist
#scheme: Pisces
```
#### 修改菜单
在主题配置文件中，找到 ``menu`` 字段并进行适当修改
```
menu:
  home: /
  archives: /archives
  about: /about
  #categories: /categories
  tags: /tags
  #commonweal: /404.html
```
#### 设置头像
同样在主题配置文件中修改 ``avatar`` 字段，可以参照注释把avatar图片存在 ``next/source/images`` 目录
```
# Sidebar Avatar
# in theme directory(source/images): /images/avatar.jpg
# in site  directory(source/uploads): /uploads/avatar.jpg
avatar: /images/avatar.jpg
```
#### 阅读统计
为文章增加字数统计和阅读时长字段，需要安装wordcount
```
npm i hexo-wordcount --save
```
最新的2017 next主题已经内置了``hexo-wordcount``，接下来就可以在主题配置文件``_config.yml``中，修改如下配置
```
# Post wordcount display settings
# Dependencies: https://github.com/willin/hexo-wordcount
post_wordcount:
  item_text: true
  wordcount: true
  min2read: true
  separated_meta: true
```
关于单篇博客阅读人数的统计，我使用了``LeanCloud``，而非``不蒜子``，同样都在next主题中内置。主要原因是``不蒜子``不能在首页显示阅读统计，此外``LeanCloud``还提供了一定的管理功能。需要在主题配置文件中修改如下字段

```
# Show number of visitors to each article.
# You can visit https://leancloud.cn get AppID and AppKey.
leancloud_visitors:
  enable: true
  app_id: 
  app_key: 
```

#### 进阶设定
官方文档介绍的很详细，请首先查阅[Next使用文档](http://theme-next.iissnan.com/getting-started.html)

### 遇到的坑和问题汇总

#### 404页面配置

常规的方法是在主题目录即 ``theme/next/source`` 下新建 ``404.html`` 文件，修改主题配置文件中的``commonweal``字段，在本地预览404就能看到对应界面。但是，这么配置到GitHub pages就访问不到404页面了。

> 网上给出原因是404页面只能绑定顶级域名，如果只用github.io，404页面就失去效果。

其实，主要原因是Github Pages强制使用https，所以文档内对js和css的请求也都需要经过https才能传输，而腾讯公益404页面默认使用http。
所以，只要把出问题的js文件拿到本地进行修改就好了~
- 原本的search_children.js

```javascript
var _base = 'http://qzone.qq.com/gy/404/';
document.write('<script type="text/javascript" src="' + _base + 'data.js" charset="utf-8"></script>');
document.write('<script type="text/javascript" src="' + _base + 'page.js" charset="utf-8"></script>');
```

初次修改为

```javascript
var _base = 'https://qzone.qq.com/gy/404/';
```

- 控制台发现仍然有js文件没有加载进来，阅读 ``page.js`` 的代码后明白了，于是 ``page.js`` 也拿到本地，修改必要的url为https，终于显示正常了
但是有一行貌似没什么用的代码，注释掉了

```javascript
// getData("http://boss.qzone.qq.com/fcg-bin/fcg_zone_info");
```

- 为了增强可读性，移除上述js文件，代码直接写入HTML。但出现新问题，返回链接变成默认的腾讯主页了。
解决办法是修改 ``page.js`` 中如下判断语句条件， ``search_children.js`` 改为 ``data.js``

```javascript
if (scs[i].src.indexOf("/404/search_children.js") > -1) {
  if (scs[i].getAttribute("homePageUrl")) {
    homePageUrl = scs[i].getAttribute("homePageUrl");
  }
  if (scs[i].getAttribute("homePageName")) {
    homePageName = scs[i].getAttribute("homePageName");
  }
  break;
}
```

- 虽然页面能正常显示了，但控制台提示提取到的儿童图片url仍然是http，解决这个问题需要在 ``page.js`` 中的 ``resolveData(d)`` 函数中对数据格式化。
在其中的for循环添加一行

```
d.data[i].child_pic = d.data[i].child_pic.replace(/^http/, "https");
```

- Finally! 发现了新版的 ``http://www.qq.com/404/`` ，logo也更美观了，果断修改。代码再次整洁了，完整如下：

```
<!DOCTYPE HTML>
<html>
<head>
  <title>Claude's Home - 404</title>
  <meta http-equiv="content-type" content="text/html;charset=utf-8;"/>
  <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1"/>
  <meta name="robots" content="all"/>
  <meta name="robots" content="index,follow"/>
</head>
<body>

<script type="text/javascript"
        src="https://qzonestyle.gtimg.cn/qzone/hybrid/app/404/search_children.js"
        charset="utf-8"
        homePageUrl="https://claude-ray.github.io/"
        homePageName="回到我的主页">
</script>

</body>
</html>
```
感觉瞎折腾了 XD ！

#### About页面

相同主题下，查看他人的 ``about`` 页面时，侧栏 ``sidebar`` 不会自动弹出，而我的居然会弹出……
难道因为 ``#`` 标题被当做post了？强迫症下查阅了很多相关文章，还没有发现官方的解决方案，看他们博客的意思是搭建的过程中也仅用了``hexo new page about``。
但回头一想，反正也不难看，就舒舒服服地按 ``Markdown`` 的习惯写着吧。

临时解决方案：
可以通过在 Markdown 中插入 HTML 标签的方法，移除Markdown的标题判定。

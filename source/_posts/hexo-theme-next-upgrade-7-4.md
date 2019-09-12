---
title: Hexo NexT 主题升级 7.4
date: 2019-09-12 20:06:19
tags: [Hexo]
categories: Hexo
---

使用 7.1.2 才过了不到 3 个月，我又将博客主题升级了，不过这次是因为 sidebar 出现了统计隐藏的样式 bug，没想到意外赶上了几个特别明显的优化。这次是真的值得所有 NexT 老用户去尝试了。

<!--more-->

## 性能优化

从我的体验来看，生成页面的耗时直接减半，对比 5 -> 7.1.2 版本升级的提速，效果相当可观。

## 定制代码注入

这个是绝对好评了！目前最常见的维护主题代码的方式就是人工 clone theme-next 到 `themes/next` 目录，除非 fork 一份仓库自己维护，所有定制的内容必须在 `themes/next` 目录修改，版本管理混在一起，一旦想升级主题，得挨个检查被自己修改过的文件。

现在可以将定制代码和原 NexT 主题代码完全隔离，自己添加的修改全都提取到 hexo 站点的 `source/_data` 目录下。只需要保管好 `_config.yml`，以后的主题更新方式就轻松地变为一键拉取最新代码。

注意需要配置开启对应的 `custom_file_path`，支持的模块如下，几乎全面满足定制需要。

```yml
custom_file_path:
  # 页面
  #head: source/_data/head.swig
  #header: source/_data/header.swig
  #sidebar: source/_data/sidebar.swig
  #postMeta: source/_data/post-meta.swig
  #postBodyEnd: source/_data/post-body-end.swig
  #footer: source/_data/footer.swig
  #bodyEnd: source/_data/body-end.swig
  # 样式
  #variable: source/_data/variables.styl
  #mixin: source/_data/mixins.styl
  #style: source/_data/styles.styl
```

可以参考我迁移后的扩展代码：https://github.com/Claude-Ray/claude-ray.github.io/tree/hexo/source/_data

## 使用 em 取代 px

扩大了自适应的范围，但我实在接受不了它在高分屏下的超大字体，没关系，上面提供的`source/_data/variables.styl` 可以用来重写 base.styl 中的变量。

```styl
// Font size
$font-size-large          = 1em;
$font-size-larger         = 1.125em;
$font-size-largest        = 1.25em;

// Headings font size
$font-size-headings-base  = 1.6em;
```

以上配置差不多就可以恢复原来的视觉效果了。

## 配置结构优化

关于 `sidebar` 位置的配置终于可以在所有主题中统一生效了，还有一些其他的简化，迁移配置的时候务必注意对照着修改。

## 其他

除了以上明显的特性更新，还有一堆 bug 修复、渲染优化等等，没毛病！

## 结论

这次的更新不用等了，尤其前两个优化解决了长久以来的痛点，值得升级。

## Reference

- [Hexo NexT 主题升级 7.1.2](https://claude-ray.github.io/2019/06/28/hexo-theme-next-upgrade-7/)
- [theme-next.org](https://theme-next.org/)

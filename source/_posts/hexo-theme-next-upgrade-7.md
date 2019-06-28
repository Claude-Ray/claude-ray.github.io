---
title: Hexo NexT 主题升级
date: 2019-06-28 22:58:34
tags: Hexo
categories: Hexo
---
# 前言
苦于 `hexo g` 的效率问题，与其重新折腾框架，决定在彻底忍受不了之前再实行一点儿补救措施——依赖升级。

Hexo 主题 NexT 5.1.x 已经很久不维护，传说新版本 7.1.x 的速度有显著提升，它是本次的重点升级对象。这里只记录 Next 主题的变更，因为 Hexo 主体和其他依赖的升级都十分平滑，没有明显的 breaking changes。

<!--more-->
# 安装

参考 [5.1.x升级指南](https://github.com/theme-next/hexo-theme-next/blob/master/docs/zh-CN/UPDATE-FROM-5.1.X.md)，问题不大，主要痛点在于忘了曾经做过哪些定制的改动，再次提醒自己 init 和 custom 提交区分开的重要性。

直接在博客根目录执行 git clone，把最新版主题放到 next7 下。
```sh
git clone https://github.com/theme-next/hexo-theme-next themes/next7
```
为了清理 NexT 仓库原有的 git 信息，继续执行
```sh
cd themes/next7 && rm -rf .git && git rm --cache . -f
```

# 切换主题
在站点 _config.yml 中替换主题为 next7，便成功替换到新主题。启动站点之前，先参考迁移文档把主题下定制过的样式复制过来（以及其他曾经定制过的文件）。
```yml
#theme: next
theme: next7
```

# 主要配置

1. favicon，记得把图片也拷贝到新主题目录
```yml
favicon:
  small: /images/favicon.ico #/images/favicon-16x16-next.png
  medium: /images/favicon.ico #/images/favicon-32x32-next.png
  apple_touch_icon: /images/favicon.ico #/images/apple-touch-icon-next.png
  safari_pinned_tab: /images/favicon.ico #/images/logo.svg
  #android_manifest: /images/manifest.json
  #ms_browserconfig: /images/browserconfig.xml
```
2. footer，如果觉得主题信息冗余，可以 false 去掉
```yml
footer:
  since: 2017 # 站点起始日期
  icon:
    name: bolt # 替换footer中的图标
  powered:
    enable: false
  theme:
    enable: false
```
3. creative_commons，打开许可协议
```yml
creative_commons:
  license: by-nc-sa
  sidebar: false
  post: true
  language:
```
4. menu，和 next 5 略有不同，icon 的设置和目录放在一起了，按需开启
```yml
menu:
  home: / || home
  about: /about/ || user
  tags: /tags/ || tags
  categories: /categories/ || th
  archives: /archives/ || archive
```
5. scheme 切换，和 next 5 一样的配置姿势
```yml
scheme: Mist
```
6. social，同 menu
6. links 友链，和之前相比也没什么变化
7. avatar，默认可以设置圆角和旋转了，好评
```yml
avatar:
  url: /images/avatar.jpg
  rounded: true
  opacity: 1
  rotated: true
  animation: false
```
8. symbols_count_time。这个算是 next 性能优化的一大“改进”。按作者的描述，其性能比 `hexo-wordcount` 好，效果比 `hexo-reading-time` 强（主要强在支持字数统计？）。

    可惜性能上去了，准确度堪忧，3k 字的文章被统计成了 8k 字，看源码似乎是标点也统计进去了，修改了 awl (Average Word Length) 也没解决问题，这让我接受不能。同时还与 NexT 主题存在版本不兼容的[问题](https://github.com/theme-next/hexo-symbols-count-time/issues/31)。
    
    顺便瞅了眼 hexo-wordcount 的源码，并不存在 NexT 升级文档上描述的“存在外部依赖”问题，因为作者在此之后进行了整改，目前代码量也非常小。并且在亲自对比生成静态文件的速度后……打扰了，果然还是 hexo-wordcount 香。

    最终，套用了 NexT 内置的 symbols_count_time 模板，参考着 hexo-wordcount 的[文档](https://github.com/willin/hexo-wordcount/blob/master/README.md)把它重新装回来了！有兴趣更改的小伙伴，可以参考我的这次[提交](https://github.com/Claude-Ray/claude-ray.github.io/commit/c7caef597aff31f9eb5b1107672f539ca96c3d53)。



9. 字数统计。这里笔者选择了关闭，原本 Leancloud 用着好好的，但最近发出公告，必须通过认证才能继续使用服务，懒得手持身份证去审核，于是考虑迁移到国际版。但经过一番尝试，国际版的 app id 无法直接用于替换。由于没有对博客做过宣传，这个阅读量对自己或别人的参考价值不大，因此放弃接入。:)

## 附 hexo-wordcount 的配置
### themes/next7/_config.yml
```yml
post_wordcount:
  item_text: true
  wordcount: true
  min2read: true
  totalcount: true
  separated_meta: true
```

### themes/next7/layout/_macro/post.swig
busuanzi_count 模板下添加
```swig
          {# Custom word count with hexo-wordcount #}
          {% if theme.post_wordcount.wordcount or theme.post_wordcount.min2read %}
            <br>
            <div class="post-wordcount">
              {% if theme.post_wordcount.wordcount %}
                {% if not theme.post_wordcount.separated_meta %}
                  <span class="post-meta-divider">|</span>
                {% endif %}
                <span class="post-meta-item-icon">
                  <i class="fa fa-file-word-o"></i>
                </span>
                {% if theme.post_wordcount.item_text %}
                  <span class="post-meta-item-text">{{ __('symbols_count_time.count') + __('symbol.colon') }}</span>
                {% endif %}
                <span title="{{ __('symbols_count_time.count') }}:">
                  {{ wordcount(post.content) }}
                </span>
              {% endif %}

              {% if theme.post_wordcount.wordcount and theme.post_wordcount.min2read %}
                <span class="post-meta-divider">|</span>
              {% endif %}

              {% if theme.post_wordcount.min2read %}
                <span class="post-meta-item-icon">
                  <i class="fa fa-clock-o"></i>
                </span>
                {% if theme.post_wordcount.item_text %}
                  <span class="post-meta-item-text">{{ __('symbols_count_time.time') }} &asymp;</span>
                {% endif %}
                <span title="{{ __('symbols_count_time.time') }}">
                  {{ min2read(post.content) }} mins.
                </span>
              {% endif %}
            </div>
          {% endif %}
          {# Custom word count with hexo-wordcount #}
```

### themes/next7/layout/_partials/footer.swig
symbols_count_time 下面添加

```swig
  {# Custom word count with hexo-wordcount #}
  {% if theme.post_wordcount.totalcount %}
    <span class="post-meta-divider">|</span>
    <span class="post-meta-item-icon">
      <i class="fa fa-area-chart"></i>
    </span>
    <span class="post-meta-item-text">{{ __('symbols_count_time.count_total') + __('symbol.colon') }}</span>
    <span title="{{ __('symbols_count_time.count_total') }}">{#
    #}{{ totalcount(site) }}{#
  #}</span>
  {% endif %}
  {# Custom word count with hexo-wordcount #}
```

### themes/next7/source/css/_common/components/post/post-meta.styl
```styl
// Custom word count with hexo-wordcount
.post-wordcount {
  if !hexo-config('post_wordcount.separated_meta') { display: inline-block; }
}
```

# 小结

升级过程比预想中的还要折腾，并且没有达到性能优化的目的，5.1.x 的稳定用户没有必要升级。

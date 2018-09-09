---
title: node图形验证码实现
date: 2018-09-02 21:46:55
tags: JavaScript
categories: Node.js
description: JS的图形验证码已有很多开源实现，可以直接用npm引入，但如果综合考虑性能和契合度时，还是亲自动手造一个好。当然实现起来并不复杂，且方便结合自身需求调整，在此分享一下使用node-canvas绘制验证码的几个心得。
---

## Requirements
参考文档安装基础图形库，[node-canvas](https://github.com/Automattic/node-canvas)。

建议使用`npm install canvas@next`安装2.x版本，兼容Windows开发环境，接口功能更完善。

此外，MDN的[canvas相关文档](https://developer.mozilla.org/zh-CN/docs/Web/API/CanvasRenderingContext2D)也可以作为重要参考。

## Tips

> `opts.*`标注的是需要自行完善的属性或方法。图形验证码作为系统安全的一环，就不开放源码了，请谅解。

### 1. 创建canvas ctx
```js
const canvas = new Canvas(opts.width, opts.height);
const ctx = canvas.getContext('2d');
```

### 2. 透明度
```js
ctx.globalAlpha = opts.opacity;
```

### 3. 背景色填充
```js
ctx.fillStyle = opts.bgc;
ctx.fillRect(0, 0, opts.width, opts.height);
```

### 4. 写字
```js
for (let i = 0; i < opts.length; i++) {
  // 字体和随机字号
  ctx.font = `${opts.fontSize}px ${opts.font}`;
  // 颜色
  ctx.fillStyle = opts.randomColor();

  // 旋转角度，使用save/restore保存之前填充的状态
  ctx.save();
  ctx.rotate(opts.randomAngle());
  // 填充字体
  ctx.fillText(opts.text[i], opts.wordSpaceX, opts.wordSpaceY);
  ctx.restore();
}
```

### 5. 干扰线
```js
// 干扰线宽度
ctx.lineWidth = opts.lineWidth;
for (let i = 0; i < length - 2; i++) {
  ctx.strokeStyle = opts.randomColor();
  // 绘制路径起始点
  ctx.beginPath();
  // 移动画笔
  ctx.moveTo(opts.x1, opts.y1));
  ctx.lineTo(opts.x2, opts.y2));
  // 画线
  ctx.stroke();
}
```

### 6. 干扰点
```js
// 根据密度计算个数
for (let i = 0; i < opts.pixelNum; i++) {
  ctx.fillStyle = opts.randomColor();
  ctx.beginPath();
  // 用实心圆作为点
  ctx.arc(opts.x, opts.y, opts.radius, 0, 2 * Math.PI);
  ctx.fill();
}
```


最后的图片产出分多种：`Buffer`，`DataUrl`和`Stream`，就从官方文档上看例子吧，注意1.x和2.x的版本差异。

## 应急方案

### 背景色
挑选一些对人眼友好的颜色，随机筛选几个拼接成渐变色背景，可以略微提高识别成本。但对于成熟的破解算法无意义，如果和字体颜色过接近，用户识别也会特别痛苦。

举个简单的3段式，抛砖引玉。
```js
const gradient = ctx.createLinearGradient(0, 0, opts.width, opts.height);

gradient.addColorStop(0, opts.randomBGC());
gradient.addColorStop(0.5, opts.randomBGC());
gradient.addColorStop(1, opts.randomBGC());

ctx.fillStyle = gradient;
ctx.fillRect(0, 0, opts.width, opts.height);
```

### 空心字体
canvas原生支持的几个字体差别实在不大，有个技巧是绘制空心字体，在验证码被攻击时，可以加入支持应急，在攻击者没有准备的情况下，可以立刻起到拦截效果。

用法很简单，将上面写字用到的`fillStyle`替换为`strokeStyle`，`fillText`替换为`strokeText`。

## Lib选择

起初，使用`gm`和`GraphicsMagick`的组合，但经压测发现了严重的性能问题，在[StackOverFlow](https://stackoverflow.com/questions/23795669/graphicsmagick-for-node-js-gm-module-performance)上也看到了原因，于是决定更换绘图方案。

> The gm module calls out to a command-line tool. You might look at using graphicsmagick2 instead, which is an actual binding to the graphicsmagick library. Unfortunately there is no documentation, so you'll have to read the source for that (which isn't too long).

测试了npm上几个热门验证码模块，有两种相对高效的实现
1. c++调用canvas运行环境（node-canvas）
2. 无外部依赖，纯js绘图（trek-captcha）

两年以上没人维护的包没有进行测试，有个自称1200/s的ccap，按我的需求出图，效率不及上面的一半。

最终选择了性能出色的node-canvas。

## 结语

以上用法是作者半年前尝试推行AI验证无果的无奈产物，终于在近期被大举攻破时宣告灭亡。

在AI面前，图形验证码的防御力是非常低的，建议处理验证码业务的各位趁早接入行为识别。

希望可以帮到有需要的同学。

Last but not least，附两篇他人的精彩调研：

- [验证码WEB端产品调研（一）：Google reCAPTCHA](https://www.jianshu.com/p/c63b78a373ad)

- [验证码WEB端产品调研（二）：极限验证](https://www.jianshu.com/p/c64902f60c7c)
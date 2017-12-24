---
title: Array.map(parseInt)为什么返回了NaN
date: 2017-12-23 19:29:48
tags: JavaScript
categories: Node.js
description: 简单来说，当调用`['1', '2', '3'].map(parseInt)`的时候，会返回什么结果？答案是`[1, NaN, NaN]`。
---


为什么没有得到想要的`[1, 2, 3]`？先来看parseInt的[文档](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/parseInt)。

## parseInt

```
parseInt(string, radix);
```
### 参数
- `string`是必传参数，要被解析的字符串，排在起始处的空格会被忽略。
- `radix`这是可选参数，但不了解的话就容易踩坑。它是一个介于2和36之间的整数(数学系统的基础)，表示上述字符串的基数。例如10代表十进制。此外，不指定该参数或0，均表示为以十进制。如果以`0x` 或 `0X` 开头，表示十六进制。

### 描述
parseInt 函数将其第一个参数转换为字符串，解析它，并返回一个整数或NaN。如果不是NaN，返回的值将是作为指定基数（基数）中的数字的第一个参数的整数。

基数大于 10 时，用字母表中的字母来表示大于 9 的数字。例如十六进制中，使用 A 到 F。

### 一些细节（keng）
1. 一些数中可能包含e字符（例如6.022e23），使用parseInt去截取包含e字符数值部分会造成难以预料的结果。例如：

  ```js
  parseInt('6.022e23', 10); // 返回 6
  parseInt('6.022e2', 10);  // 返回 602
  ```

2. 当parseInt遇到不属于radix参数所指定的基数中的字符（eg: 有人告诉你`  0103101  `是2进制），那么该字符（3）和其后的字符（101）都将被忽略，接着返回已经解析的整数部分（010）。parseInt 将截取整数部分，开头和结尾的空白符允许存在，会被忽略。那么NaN的出现情况就是，`string`的第一个字符（除空白）不属于radix指定进制时，因为parseInt什么都没有解析到。
  ```js
  parseInt('123', 'afdsaf'); // 返回123
  ```

3. 在没有指定基数，或者基数为 0 的情况下，JavaScript 作如下处理：

  - string 以'0x'或者'0X'开头, 则基数是16 (16进制).
  - string 以'0'开头, 基数是8（八进制）或者10（十进制），那么具体是哪个基数由实现环境决定。ECMAScript 5 规定使用10，但是并不是所有的浏览器都遵循这个规定。因此，永远都要明确给出radix参数的值。
  - string 以其它任何值开头，则基数是10 (十进制)。

4.  将整型数值以特定基数转换成它的字符串值可以使用 `intValue.toString(radix);`

## Array.map
其实看完parseInt的文档就已经清晰了，再来看[map](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map)

```js
const new_array = arr.map(function callback(currentValue[, index[, array]]) {
    // Return element for new_array
}[, thisArg])
```

### 参数
通常情况下，`callback` 只需要接受一个参数，就是正在被遍历的数组元素本身。但这并不意味着 map 只给 callback 传了一个参数。

- `callback`: 生成新数组元素的函数，使用三个参数：
  - `currentValue`: 正在处理的当前元素。
  - `index`: 当前元素的索引。
  - `array`: map 方法被调用的数组。
- `thisArg`: 可选，执行 callback 函数时 使用的this 值。

> 返回值是一个新数组，每个元素都是回调函数的值。

## 最终分析

调用`['1', '2', '3'].map(console.log)`观察，列举出当`['1', '2', '3'].map(parseInt)`的时候发生了什么。
  ```js
  parseInt('1', 0, ['1', '2', '3']);
  parseInt('2', 1, ['1', '2', '3']);
  parseInt('3', 2, ['1', '2', '3']);
  ```

由于parseInt只接受了前两个参数，过滤掉array得到如下。
  ```js
  parseInt('1', 0); // radix为0，按十进制输出1
  parseInt('2', 1); // radix为1，不满足2到36范围
  parseInt('3', 2); // radix为2，将3看成二进制数，但3并不是二进制，无法转换
  ```

再换一个数组，也可以按照此逻辑推算正确结果了。

---
title: CSAPP DataLab 题解
date: 2019-10-02 23:19:44
tags: [DataLab,CSAPP]
categories: Computer System
---

# DataLab

近来开始读 CS:APP3e 第二章，但干看书做课后题太乏味，于是提前把 DataLab 拉出来练练。不一定是优解，趁热记录一下思路吧。

<!--more-->

> 如果读者是那种还没做完 lab 就想借鉴答案的，还请收手，坚持独立完成吧，正如课程作者所说，`Don't cheat, even the act of searching is checting.`

## bitXor

```c
/* 
 * bitXor - x^y using only ~ and & 
 *   Example: bitXor(4, 5) = 1
 *   Legal ops: ~ &
 *   Max ops: 14
 *   Rating: 1
 */
int bitXor(int x, int y) {
  return ~(~(x & ~y) & ~(~x & y));
}
```

简单的公式可以写作 `(x & y) | (~x & y)` ，但题目要求只能用 ~ & 两种操作，换句话就是考察用 ~ & 来实现 | 操作，和逻辑与或非类似。

## tmin

```c
/* 
 * tmin - return minimum two's complement integer 
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 4
 *   Rating: 1
 */
int tmin(void) {
  return 1 << 31;
}
```

这个题目就是计算出 `0x80000000` ，基本的移位操作即可，不用复杂化。

## isTmax

```c
/*
 * isTmax - returns 1 if x is the maximum, two's complement number,
 *     and 0 otherwise 
 *   Legal ops: ! ~ & ^ | +
 *   Max ops: 10
 *   Rating: 1
 */
int isTmax(int x) {
  return !(~(1 << 31) ^ x);
}
```

上面已经知道怎么获取 TMIN，TMAX 可以用 ~TMIN 表示，因此主要考察两个数是否相等 —— `^`。

## allOddBits

```c
/* 
 * allOddBits - return 1 if all odd-numbered bits in word set to 1
 *   where bits are numbered from 0 (least significant) to 31 (most significant)
 *   Examples allOddBits(0xFFFFFFFD) = 0, allOddBits(0xAAAAAAAA) = 1
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 12
 *   Rating: 2
 */
int allOddBits(int x) {
  int odd = (0xAA << 24) + (0xAA << 16) + (0xAA << 8) + 0xAA;
  return !((x & odd) ^ odd);
}
```

先构造 `0xAAAAAAAA`，利用 & 操作将所有奇数位提出来，再和已构造的数判等。

## negate

```c
/* 
 * negate - return -x 
 *   Example: negate(1) = -1.
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 5
 *   Rating: 2
 */
int negate(int x) {
  return ~x + 1;
}
```

二进制基础扎实的话，可以秒出结果。

## isAsciiDigit

```c
/* 
 * isAsciiDigit - return 1 if 0x30 <= x <= 0x39 (ASCII codes for characters '0' to '9')
 *   Example: isAsciiDigit(0x35) = 1.
 *            isAsciiDigit(0x3a) = 0.
 *            isAsciiDigit(0x05) = 0.
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 15
 *   Rating: 3
 */
int isAsciiDigit(int x) {
  /* (x - 0x30 >= 0) && (0x39 - x) >=0 */
  int TMIN = 1 << 31;
  return !((x + ~0x30 + 1) & TMIN) & !((0x39 + ~x + 1) & TMIN);
}
```

主要思路可以用逻辑运算表示，`(x - 0x30 >= 0) && (0x39 - x) >=0`，这里新概念是如何判断数值是否小于 0。

## conditional

```c
/* 
 * conditional - same as x ? y : z 
 *   Example: conditional(2,4,5) = 4
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 16
 *   Rating: 3
 */
int conditional(int x, int y, int z) {
  int f = ~(!x) + 1;
  int of = ~f;
  return ((f ^ y) & of) | ((of ^ z) & f);
}
```

这里我用 `~(!x) + 1` 构造了 x 的类布尔表示，如果 x 为真，表达式结果为 0，反之表达式结果为 ~0。

## isLessOrEqual

```c
/* 
 * isLessOrEqual - if x <= y  then return 1, else return 0 
 *   Example: isLessOrEqual(4,5) = 1.
 *   Legal ops: ! ~ & ^ | + << >>
 *   Max ops: 24
 *   Rating: 3
 */
int isLessOrEqual(int x, int y) {
  /* (y >=0 && x <0) || ((x * y >= 0) && (y + (-x) >= 0)) */
  int signX = (x >> 31) & 1;
  int signY = (y >> 31) & 1;
  int signXSubY = ((y + ~x + 1) >> 31) & 1;
  return (signX & ~signY) | (!(signX ^ signY) & !signXSubY);
}
```

核心是判断 `y + (-x) >= 0`。一开始我做题时被 `0x80000000` 边界条件烦到了，所以将其考虑进了判断条件。

具体做法是判断 Y 等于 TMIN 时返回 0，X 等于 TMIN 时返回 1。此外也考虑了若 x 为负 y 为 正返回 1，x 为正 y 为负返回 0。

这样想得太复杂了，使用的操作有点多，而题目对 ops 限制是 24，担心过不了 dlc 的语法检查。 所以又花更多时间想出更简单的方法。用逻辑操作可以写作 `(y >=0 && x <0) || ((x * y >= 0) && (y + (-x) >= 0))`。不过我后来在 linux 上运行了一下第一种方法，dlc 并没有报错。

## logicalNeg

```c
/* 
 * logicalNeg - implement the ! operator, using all of 
 *              the legal operators except !
 *   Examples: logicalNeg(3) = 0, logicalNeg(0) = 1
 *   Legal ops: ~ & ^ | + << >>
 *   Max ops: 12
 *   Rating: 4 
 */
int logicalNeg(int x) {
  int sign = (x >> 31) & 1;
  int TMAX = ~(1 << 31);
  return (sign ^ 1) & ((((x + TMAX) >> 31) & 1) ^ 1);
}
```

x 小于 0 时结果为 1，否则检查 `x + TMAX` 是否进位为负数。

## howManyBits

```c
/* howManyBits - return the minimum number of bits required to represent x in
 *             two's complement
 *  Examples: howManyBits(12) = 5
 *            howManyBits(298) = 10
 *            howManyBits(-5) = 4
 *            howManyBits(0)  = 1
 *            howManyBits(-1) = 1
 *            howManyBits(0x80000000) = 32
 *  Legal ops: ! ~ & ^ | + << >>
 *  Max ops: 90
 *  Rating: 4
 */
int howManyBits(int x) {
  int sign = (x >> 31) & 1;
  int f = ~(!sign) + 1;
  int of = ~f;
  /*
   * NOTing x to remove the effect of the sign bit.
   * x = x < 0 ? ~x : x
   */
  x = ((f ^ ~x) & of) | ((of ^ x) & f);
  /*
   * We need to get the index of the highest bit 1.
   * Easy to find that if it's even-numbered, `n` will lose the length of 1.
   * But the odd-numvered won't.
   * So let's left shift 1 (for the first 1) to fix this.
   */
  x |= (x << 1);
  int n = 0;
  // Get index with bisection.
  n += (!!(x & (~0 << (n + 16)))) << 4;
  n += (!!(x & (~0 << (n + 8)))) << 3;
  n += (!!(x & (~0 << (n + 4)))) << 2;
  n += (!!(x & (~0 << (n + 2)))) << 1;
  n += !!(x & (~0 << (n + 1)));
  // Add one more for the sign bit.
  return n + 1;
}
```

这里我利用了之前 conditional 的做法，讲 x 为负的情况排除掉，统一处理正整数。统计位数可以采取二分法查找最高位的 1，但做了几轮测试就会发现二分法存在漏位的问题。

不过这只在偶数位发生，奇数位不受影响。因此为了排除这个影响，我暴力地用 `x |= (x << 1)` 的办法让最高位的 1 左移 1 位。 

## floatScale2

```c
/* 
 * floatScale2 - Return bit-level equivalent of expression 2*f for
 *   floating point argument f.
 *   Both the argument and result are passed as unsigned int's, but
 *   they are to be interpreted as the bit-level representation of
 *   single-precision floating point values.
 *   When argument is NaN, return argument
 *   Legal ops: Any integer/unsigned operations incl. ||, &&. also if, while
 *   Max ops: 30
 *   Rating: 4
 */
unsigned floatScale2(unsigned uf) {
  int exp = (uf >> 23) & 0xFF;
  // Special
  if (exp == 0xFF)
    return uf;
  // Denormalized
  if (exp == 0)
    return ((uf & 0x007fffff) << 1) | (uf & (1 << 31));
  // Normalized
  return uf + (1 << 23);
}
```

只需要简单地取出指数部分，甚至不需要拆解，排除 INF、NaN、非规格化的情况之后，剩下规格化的处理是指数部分的位进一。

## floatFloat2Int

```c
/* 
 * floatFloat2Int - Return bit-level equivalent of expression (int) f
 *   for floating point argument f.
 *   Argument is passed as unsigned int, but
 *   it is to be interpreted as the bit-level representation of a
 *   single-precision floating point value.
 *   Anything out of range (including NaN and infinity) should return
 *   0x80000000u.
 *   Legal ops: Any integer/unsigned operations incl. ||, &&. also if, while
 *   Max ops: 30
 *   Rating: 4
 */
int floatFloat2Int(unsigned uf) {
  int TMIN = 1 << 31;
  int exp = ((uf >> 23) & 0xFF) - 127;
  // Out of range
  if (exp > 31)
    return TMIN;
  if (exp < 0)
    return 0;
  int frac = (uf & 0x007fffff) | 0x00800000;
  // Left shift or right shift
  int f = (exp > 23) ? (frac << (exp - 23)) : (frac >> (23 - exp));
  // Sign
  return (uf & TMIN) ? -f : f;
}
```

首先拆分单精度浮点数的指数和基数，指数部分减去 127 偏移量，用来排除临界条件。大于 31 时，超过 32 位 Two's Complement 的最大范围，小于 0 则忽略不计，根据题意分别返回 0x80000000 和 0。

之后根据指数部分是否大于 23 来判断小数点位置。如果大于，说明小数部分全部在小数点左边，需要左移；如果小于则需要右移。最后补上符号位。

## floatPower2

```c
/* 
 * floatPower2 - Return bit-level equivalent of the expression 2.0^x
 *   (2.0 raised to the power x) for any 32-bit integer x.
 *
 *   The unsigned value that is returned should have the identical bit
 *   representation as the single-precision floating-point number 2.0^x.
 *   If the result is too small to be represented as a denorm, return
 *   0. If too large, return +INF.
 * 
 *   Legal ops: Any integer/unsigned operations incl. ||, &&. Also if, while 
 *   Max ops: 30 
 *   Rating: 4
 */
unsigned floatPower2(int x) {
  int exp = x + 127;
  // 0
  if (exp <= 0)
    return 0;
  // INF
  if (exp >= 0xFF)
    return 0x7f800000;
  return exp << 23;
}
```

加 127 得到指数阶码，超过表示范围则返回 0 和 INF。由于小数点后面都是 0，只需左移指数部分。

# 小结
现在 Mac 已无法运行 32 位的代码检查工具 dlc，不过可以先跑逻辑测试，等写完再放到 Linux 机跑一遍 dlc 测试。

原以为这点知识在学校掌握得还可以，随书习题和前几道 lab 也的确简单，实际做到后面有许多卡壳的点，浮点数的概念都模糊了，真是一边翻书一边做，快两天才完成。书本的这章我还是甭跳了，继续刷去吧。


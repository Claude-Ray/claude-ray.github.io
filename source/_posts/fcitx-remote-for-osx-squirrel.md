---
title: fcitx-remote-for-osx 设置 Squirrel 输入法切换
date: 2019-07-17 20:55:30
tags: [squirrel,Vim,emacs evil,input method]
categories: Mac
---

初衷是解决中文输入法在 vim/evil 键位下的 `insert` 模式和 `normal` 模式的切换问题，实现 `normal` 模式自动切英文、`insert` 模式回复之前的输入状态。

当然各编辑器都有各自知名的解决方案，本次主要吐槽 Mac 平台 fcitx-remote-for-osx 和 squirrel 输入法间的“摩擦”。

<!--more-->

在读本篇之前，默认你已经按照 fcitx-remote-for-osx [文档](https://github.com/xcodebuild/fcitx-remote-for-osx)进行了相关操作，并最终遇到了切换失败的问题，否则下文将对你没有帮助。

本来文档中指定的安装方法很简单
```sh
brew install fcitx-remote-for-osx --with-input-method=<method>
```

可是目前 homebrew 的 formula 移除了 options，无法指定 `--with-input-method`，上面指令的直接结果将是
```
Error: invalid option: --with-input-method=squirrel-rime
```

最初参考这个 [issue](https://github.com/xcodebuild/fcitx-remote-for-osx/issues/38#issuecomment-468114160)，通过 brew cap 安装 fcitx-remote-for-osx
```sh
brew tap codefalling/fcitx-remote-for-osx
brew install codefalling/fcitx-remote-for-osx/fcitx-remote-for-osx --with-squirrel-rime
```

但是安装版本太老，引发了新的问题，无论是在 terminal，还是在 vim、emacs、vscode 中，只能切换到英文，无法切回 squirrel。

> 可以执行 `fcitx-remote -t` 来测试能否反复切换中英文输入法。

这时候通过 fcitx-remote-for-osx 的 [build](https://github.com/xcodebuild/fcitx-remote-for-osx/blob/master/build.py) 文件，发现 squirrel 有两种 bundle identitier
```py
InputMethod = {
    'squirrel-rime': 'com.googlecode.rimeime.inputmethod.Squirrel.Rime',
    'squirrel-rime-upstream': 'im.rime.inputmethod.Squirrel.Rime',
}
```

查看已安装rime的 Identifier
```sh
osascript -e 'id of app "squirrel"'
```

结果可能是 `im.rime.*` 或 `com.googlecode.rimeime.*`。我这里的输出为 `im.rime.inputmethod.Squirrel`，说明要使用 `squirrel-rime-upstream` 作为编译选项。

可惜 tap 安装的旧版没有这个选项，最后决定直接用源码编译，等新版本修复了再回归 homebrew 管理。`build.py` 文件内容本来就简单，并且作者在 [special-input-method分支](https://github.com/xcodebuild/fcitx-remote-for-osx/tree/feature/special-input-method#install) 提供了编译安装的文档，效果和 homebrew install 是一致的。

```sh
git clone https://github.com/dangxuandev/fcitx-remote-for-osx
cd fcitx-remote-for-osx
./build.py build squirrel-rime-upstream
cp ./fcitx-remote-squirrel-rime-upstream /usr/local/bin/fcitx-remote-squirrel-rime
ln -snf /usr/local/bin/fcitx-remote-squirrel-rime /usr/local/bin/fcitx-remote
```

基本可以正常使用了，也没有出现切换延迟较高的问题，但偶尔遇到 squirrel 卡住，无法切换中英，在 squirrel issues 可以看到了有许多相关 bug。但是并没有人给出终极的解决方案，佛振认为这是其他软件的问题，暂不予关注，等他参与修复可能遥遥无期。详见这个已关闭的 [issue](https://github.com/rime/squirrel/issues/292)

在写这篇文章的过程中，就触发了一次卡死状态……但切换输入法、或切换窗口就可以恢复。而在 VSCode 配置 vim 插件的[自动切换](https://github.com/VSCodeVim/Vim#input-method)后 100% 重现。

毕竟中文输入场景很少，完美输入方案在个人看来是不存在的，也就不再多折腾它了，暂且容忍一段时间，等出现频率高了再找解决方案吧。

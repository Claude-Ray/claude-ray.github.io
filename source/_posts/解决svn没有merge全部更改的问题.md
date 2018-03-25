---
title: 解决svn没有merge全部更改的问题
date: 2018-03-19 11:53:52
tags: SVN
categories: SVN
description: 记一次svn merge individual files导致后续merge遗漏更改的解决方案。
---

## 问题描述
今天使用svn合并主干到发布分支时，发现即使没有冲突，也出现了文件错误。检查后发现，文件内有一部分历史更改被遗漏了。

准确的说，上一次合并开发分支到主干后，由于只想发布个别文件（individual files），在发布分支merge拉取后只选择性的commit了4个文件，其他的文件（并非首次创建）更改自此忽略。记本次为操作A。

正常情况下，重新执行merge，仍然可以看到未提交的改动文件，但本次merge隔操作A数个版本之后，`mergeinfo`也并不会显示操作A漏掉的提交。

## 解决过程

### 1. ignore ancestry
除了操作A之外，也有很多其他只提交特定文件的merge记录，所以直接加`--ignore-ancestry`，甚至出现了以下错误导致无法合并。
```sh
svn: E200004: Cannot merge automatically while ignoring mergeinfo
```

### 2. 指定版本号
指定被漏掉更改的那个版本号（例如r233），可以只找回当时漏提交的文件(使用参数`-c`, 限定ARG-1:ARG的修改)。

完整命令如下：
```sh
svn merge --ignore-ancestry -c 233 http://localhost/svn/url
```

## 小结

笔者对svn使用仍不够熟练，一直使用命令行操作，可能这也是触发霉头的根源。 XD

粗略浏览了Stack Overflow，没看到期望的答案，但有些回答也给我一些启发，捡一条附在了下面。

#### 相关问题
[Merging across branches in Subversion isn't adding all the new files. Why not?
](https://stackoverflow.com/questions/754082/merging-across-branches-in-subversion-isnt-adding-all-the-new-files-why-not)


The following statement is not true:

> Files that were added to a branch and then changed on the branch don't get added when doing a merge across number of revisions

That would imply merging is totally broken.

When you do the merge, you need to make sure that you do merge the revision that created the file, otherwise you'll get those warnings about no target.

The other thing to watch out for is if you do a merge into a working copy, then decide you're not happy with it and revert everything, the newly added files will still be in the working copy, so if you merge again, the unversioned files will prevent the merge of new files there, so you will miss them. So running "svn status" and removing unversioned files will ensure the merge works properly.

The comment about adding an empty file should not be done, because then the new file has no history of where it came from. In other words, it's not a copy, so "svn log" will not show its history. And finally, if the file were a gigabyte photo, you wouldn't want to merge it into a new file, because then the repository would have two copies of the exact same context. Merging and copying with history saves repository storage (at least until rep-sharing is put in).

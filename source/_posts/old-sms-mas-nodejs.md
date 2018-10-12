---
title: Nodejs使用MySQL 4.1的问题解决
date: 2018-10-12 22:04:17
tag: MySQL
categories: Node.js
description: 近期新同事在处理短信业务，用到了一台存放久远的移动mas机，MySQL版本为同样久远的4.1，改动数据库是不要想了，并且不提供node的sdk，留下的接入文档也不靠谱。好在要到了一份java sdk源码，可以运行起来参照着接入。本篇分享一下帮忙时填的坑，主要涉及“数据库连接”和“编码转换”的问题。
---

## 数据库连接

如果使用`old authentication`方式连接4.1版本之前的mysql，`sequelize`和`mysql2`无法通过认证：
```sh
{ Error: Access denied for user: '@127.0.0.x' (Using password: NO)
    at Packet.asError (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/packets/packet.js:714:13)
    at ClientHandshake.Command.execute (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/commands/command.js:28:22)
    at Connection.handlePacket (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/connection.js:513:28)
    at PacketParser.onPacket (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/connection.js:81:16)
    at PacketParser.executeStart (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/packet_parser.js:76:14)
    at Socket.<anonymous> (/home/claude/Workspace/packages/sql/node_modules/mysql2/lib/connection.js:89:29)
    at Socket.emit (events.js:182:13)
    at addChunk (_stream_readable.js:283:12)
    at readableAddChunk (_stream_readable.js:264:11)
    at Socket.Readable.push (_stream_readable.js:219:10)
    at TCP.onread (net.js:639:20)
  code: 'ER_ACCESS_DENIED_ERROR',
  errno: 1045,
  sqlState: '',
  sqlMessage:
   'Access denied for user: \'@127.0.0.x\' (Using password: NO)' }
```
处理倒不困难，在不能改动数据库的情况下，可以改用npm包`mysql`。

## 编码转换
文档描述如下：
> mysql使用ISO8859-1编码，往db接口写入数据时应先把编码格式转化为ISO8859-1...

上述编码实际为`latin1`，为早期mysql的默认编码。实际文档存在误导，未指出mas机的db接口是使用gbk编码写入的，因此将字符进行转化gbk再使用该接口即可，无需再将编码转为`latin1`。

但如果想从数据库中读取，同事在创建连接时指定了`charset=latin1`获取到的中文是乱码。

这涉及到mysql如何用`latin1`存储中文的问题：`latin1`为0x00 to 0xFF范围的单字节编码（`ASCII`是它的子集），理论上单字节范围可以无损存储数据，任意编码均可以用字节流形式存储。

也就是说，mas机写入之前用的是gbk字节流，读取时直接用nodejs默认的utf8编码自然不行。那么怎样读出二进制数据呢？在npm `mysql`库的README中搜索`buffer`字样，找到了如下方法。

mysqljs支持在query中自定义[typeCast](https://github.com/mysqljs/mysql#string)方法，可用于提取数据的步骤进行编码转换。
```js
const mysql = require('mysql');
const iconv = require('iconv-lite');
const connection = mysql.createConnection({
  host     : 'localhost',
  user     : 'me',
  password : 'secret',
  database : 'my_db',
  charset  : 'latin1'
});

connection.connect();

connection.query({
  sql: 'SELECT * FROM tbl_user',
  typeCast: (field, next) => {
    // converting `tbl_user.name` to utf8 string:
    if (field.name === 'username') {
      return iconv.decode(field.buffer(), 'gbk');
    }
    return next();
  }
}, (error, results, fields) => {
  //
});
```

其中typeCast的参数field包含
- type 字段类型，`VARCHAR`等（[详情链接](https://github.com/mysqljs/mysql/blob/master/lib/protocol/packets/RowDataPacket.js#L41)）
- name 字段名
- length 字段长度
- table 表名
- db 数据库名
- ...

依此，其他更多问题都可以迎刃而解。

### 参考资料：
- [mysql中的latin1支持中文](https://blog.csdn.net/css_good/article/details/8809016)，CSDN有很多一样的文章，不清楚谁是原作者。
- [What are the differences between ASCII, ISO 8859, and Unicode?](https://kb.iu.edu/d/ahfr)

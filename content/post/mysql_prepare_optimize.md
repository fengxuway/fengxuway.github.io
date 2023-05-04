---
title:       "MySQL Prepare 性能分析和优化"
subtitle:    ""
description: ""
date:        2023-05-04
author:      "冯旭"
image:       ""
tags:        ["MySQL", "Golang", "Prepare", "sqlx"]
categories:  ["Tech" ]
---

通常，我们开发与 MySQL 数据库交互过程中，经常使用 prepared（预处理编译） 语句防止 sql 注入。那么 prepared statement 和数据库是如何交互的，有哪些细节是可以优化的呢？本文借住 Wireshark 抓包工具来详细了解。

 <!--more-->

## 抓包分析

Golang 常用的 ORM 框架或数据库操作框架，如 gorm 和 sqlx，都提供了基于通配符`?`的检索方案，主要应对 sql 注入等安全问题。但我们在开发过程中，对 prepared 理解不足，可能会写出检索效率较低的代码。
下面的例子针对sql语句通过 Wireshark 抓包测试:
```
select `key`, version from versions where `key` = 'form'
```
本机ip：30.17.71.15
mysql ip：9.134.211.217

以 sqlx 框架为例，这是带通配符的写法：
```
func TestSQLXPrepare(t *testing.T) {
	db := initSQLXDB()
	key := "form"
	sql, args, err := squirrel.Select("`key`, version").From("versions").Where("`key` = ?", key).ToSql()
	if err != nil {
		t.Fatal(err)
	}
	var v Versions
	err = db.Get(&v, sql, args...)
	if err != nil {
		t.Fatal(err)
	}
	fmt.Println(v)
}
```
这是抓包内容：

![](/media/2023/05/04/16831892665963.jpg)


可以看到请求查询时，客户端向 mysql 服务端请求两次，分别为创建 prepared 语句和执行语句查询。

而如果直接使用不带`?`的方式（可能存在sql注入风险），代码：
```
func TestSQLXDirect(t *testing.T) {
	db := initSQLXDB()
	var v Versions
	err := db.Get(&v, "select `key`, version from versions where `key` = 'form'")
	if err != nil {
		t.Fatal(err)
	}
	fmt.Println(v)
}
```
抓包内容：
![](/media/2023/05/04/16831892791861.jpg)

则只有一次请求响应。另外也使用 GORM 框架测试，结果和 sqlx 类似。

根据抓包结果，我们可以得知：sql 语句中使用了 `?` 通配符则启动 prepared 功能，会和数据库交互两次：
- 首先请求数据库创建 prepare 语句
- 第二次请求，将 `?` 对应个数的参数传入，执行对应的 statement 语句

## MySQL sql 执行步骤

一个普通的 sql 查询的步骤大致如下：
连接器 -> 分析器 -> 优化器 -> 执行器

其中分析器负责 sql 语句的语法分析和语义分析。那么问题来了，如果一条 sql 语句执行非常频繁，而每次只变动 where 条件的值，或者 update set 值，使用普通 sql 查询则会把部分服务端资源用在无意义的语法分析中了。

而使用了预处理编译后，创建 prepared 则会仅执行分析器，并将 sql 分析结果缓存起来，直到会话关闭或手动调用`DEALLOCATE PREPARE` 才会释放。

## 性能优化

像 sqlx（gorm也类似）常用的执行方式，每次执行都会创建一个预处理语句，再执行语句：
```
db.Get(&v, sql, args...)
```
无形中增加了服务端的资源占用，以及两次请求所带来的网络延迟。那么，减少相同结构 sql 语句的分析步骤、减少一次网络请求将是很有意义的优化方案了。

如下代码，将 `sqlx.Stmt` 实例缓存到 store 层结构体的字段中，在创建 store 对象时初始化；在执行时直接引用 stmt 实例：
```go
type caseStore struct {
	db                         *db.DB
	stmtStatPassRate           *sqlx.Stmt
}

func NewCaseStore(db *db.DB) (core.CaseStore, error) {
	c := &caseStore{db: db}
	return c, c.init()
}

func (c *caseStore) init() error {
	return c.db.View(func(db *sqlx.DB) error {
		var err error
		c.stmtStatPassRate, err = db.Preparex(`SELECT status FROM mytable WHERE case_id = ? and branch != '' ORDER BY time DESC LIMIT ? OFFSET ?`)
		return err
	})
}

func (c *caseStore) QueryStatus(caseHashID string, opt model.Option) ([]int, error) {
    var statusList []int
    err := c.stmtStatPassRate.Select(&statusList, caseHashID, opt.Limit, opt.Offset)
    return statusList, err
}
```

抓包分析发现，建立 mysql 连接后立即创建了预处理语句。在查询操作里，只有`Execute Statement`这一个请求。

经过优化后，我们可以在使用预处理语句，保证 sql 无注入风险的同时，尽可能将请求次数降低，合理利用预处理的特性。

> GORM 初始化的配置有个参数`PrepareStmt bool`，是一种本地缓存机制，但由于这个配置是全局生效，在拼接 where 条件的逻辑时，可能会创建很多预处理对象，导致本地资源占用过多，慎用。
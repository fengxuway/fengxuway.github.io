---
title:       "简易版 Golang 依赖倒置、依赖注入框架：go-construction"
subtitle:    ""
description: ""
date:        2023-05-05
author:      "冯旭"
image:       ""
tags:        ["Golang"]
categories:  ["Tech" ]
---

略

 <!--more-->

框架代码链接：<https://github.com/fengxuway/go-construction>

该框架从 [drone](https://github.com/harness/drone) 仓库提炼出，可以作为常见的 Golang “六边形架构”的平替架构。

六边形架构往往适用于大型项目，具有很高的扩展能力。但代价是入门成本较高，需要了解`domain`、`aggregate`、`controller`、`infra` 等概念。
而其核心宗旨是“依赖倒置“和”依赖注入“，将基础架构、控制层、逻辑层都扁平化为接口。所以本着 Golang 大道至简的思路，再结合 Drone 优秀的代码结构，提炼出一套简单的结构。

框架结构及注释：

```
├── README.md
├── cmd
│   └── 定义wire依赖注入和main函数
├── config
│   └── 配置文件结构体定义和加载
├── core
│   ├── 存放所有模块的接口如dao层service层
│   ├── 存放接口入参和返回值的entity实体
│   └── 这里是依赖倒置的接口权限定义区
├── docker
│   └── 声明构建的dockerfile
├── handler
│   ├── api
│   │   ├── api.go
│   │   ├── api.go_定义整体路由表
│   │   └── 定义各模块子目录，处理http请求或rpc请求基础逻辑handler
│   ├── health
│   │   └── 健康检查handler
│   └── web
│       ├── 使用esc等工具（github.com_mjibson_esc）将前端页面统一代理
│       └── 内置html页面的请求
├── logger
│   ├── http日志中间件
│   └── 日志初始化
├── metrics
│   ├── repos.go
│   ├── 如repos.go传入core接口实例，在 wire 的 provider 中 new 实例并注入指标中
│   └── 基于prometheus的监控指标
├── mock
│   └── 使用mockgen生成core包所有接口的mock代码
├── server
│   └── 启动http和rpc服务
├── service
│   ├── 业务逻辑
│   └── 按模块划分二级目录，尽量只两级目录
└── store
    ├── shared
    │   ├── db
    │   │   ├── conn.go
    │   │   ├── db.go
    │   │   ├── mysql
    │   │   │   └── mysql.go
    │   │   ├── nop.go
    │   │   ├── 封装gorm或sqlx的orm
    │   │   └── 初始化数据库连接
    │   └── migrate
    │       └── mysql
    │           ├── ddl.go
    │           ├── ddl.go使用togo命令可生成migrate函数
    │           ├── files
    │           │   ├── 002_create_table_user.sql
    │           │   └── 数字编号开头的数据库变更脚本，用于记录每次上线的数据库变更
    │           └── 在程序启动需要同步数据库结构的情况时，可调用生成的migrate函数
    ├── 也就是dao层，对象实例建议用Store结尾
    └── 建立和数据库相关的各模块的子目录
```

框架使用的工具：
- 依赖注入：[wire](https://github.com/google/wire)
- sql 转 go migrate：[togo](https://github.com/fengxuway/togo)

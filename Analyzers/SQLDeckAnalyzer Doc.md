# 后台 API 单卡统计接口
## 枚举
### Type（查询类别）
name | desc
---|---
day | 当日统计
week | 最近7天统计
halfmonth | 最近15天统计
month | 最近30天统计
season | 本赛季统计
default | 当与以上任一均不匹配，当做 day

### Source（统计数据来源）
name | desc
---|---
mycard-athletic|竞技匹配
mycard-entertain|娱乐匹配
mycard-custom|自由对战
mycard-tag|TAG 对战
233-athletic|随机M房
233-entertain|随机S房
233-custom|自由对战
233-tag|TAG 对战
unknown | 未分类
default | 当与以上任一均不匹配，当做 unknown

### TagStats（标签统计结果）
name | desc
----|----
name | 标签名
count | 使用数

    标签名中含有形如「卡组名-」的前缀。

### DeckStats（卡组统计结果）
name | desc
----|----
name | 卡组名
count | 使用数
tags | 卡组热门标签前三

## API
### 一并查询
#### URI
name | desc
---|---
Request URL | /analyze/deck
Request Method | GET
Content-Type | application/json

#### Param
param | desc
---|---
N/A | N/A

#### Return
desc | innerType
--- | ---
整个 Cache 内容 | { *Type*: { *Source*: { [_DeckStats_ length = 50] } } }
### 按类别查询
#### URI
name | desc
---|---
Request URL | /analyze/deck/type
Request Method | GET
Content-Type | application/json

#### Param
param | desc
---|---
type | *Type*
source | *Source*

#### Return
desc | innerType
--- | ---
所查询类别的统计结果 | [_DeckStats_ length = 50]
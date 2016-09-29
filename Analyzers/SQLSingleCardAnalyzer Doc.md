# 后台 API 单卡统计接口

## Stucture Define
### Card
name | desc | note | innerType
---|---|---|---
id | 卡片 ID ||"int"
category | 卡片分类 | *Category* | "str"
time | 入库时间 | 不用管 | "yy-mm-dd"
timeperiod | 入库时统计的天数 | 不用管 | "int"
frequency | 投入频次 | frequency = putone + puttwo + putthree | "int"
numbers | 投入卡次 | 不用管 | "int"
putone | 投入1张的频度 | | "int"
puttwo | 投入2张的频度 | | "int"
putthree | 投入3张的频度 | | "int"
name | 卡名 | | "str"
main_type_desc | 卡片类别 | | "str"

## Enum Define
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
atheletic | 竞技场
entertainment | 娱乐匹配
handwritten | 手动输入
unknown | 未分类
default | 当与以上任一均不匹配，当做 unknown

### Category（统计分类）
name | desc
---|---
monster | 主卡组怪兽
spell | 主卡组魔法
trap | 主卡组陷阱
side | 备牌
ex | 额外
unknown | 未知卡片
default | 当与以上任一均不匹配，当做 unknown

## API

### 按给定分类查询
#### URI
name | desc
---|---
Request URL | /analyze/single/type, **未上线**
Request Method | GET
Content-Type | application/json 

#### Param
param | desc
---|---
type | *Type*
category | *Category*
source | *Source*

#### Return
name | desc | innerType
---|---|---
N/A|所查询的统计，从频率高到低|[*Card*, length = 50]

#### 备注
+ 所查询之时间不可选，均为服务器收到查询之当前时间。
+ 所查询之内容来自 Cache，不会对数据库进行查询。

### 一并查询
#### URI
name | desc
---|---
Request URL | /analyze/single, **未上线**
Request Method | GET
Content-Type | application/json

#### Param
param | desc
---|---
N/A | N/A

#### Return
name | desc | innerType
--- | --- | ---
N/A | 整个 Cache 内容 | { *Type*: { *Source*: { *Category*: [*Card*, length = 50] } } }

#### 备注
+ 所查询之时间不可选，均为服务器收到查询之当前时间。

### 查询单卡相关
**这是备用 API**
#### URI
name | desc
---|---
Request URL | /analyze/single/card, **未上线**
Request Method | GET
Content-Type | application/json

#### Param
param | desc
---|---
type | *Type*
time | 截止时间，输入格式 yyyy-mm-dd，无则当前时间
card | 要查询的卡片 ID

## Return Structure
name | desc | innerType
---|---|---
N/A|查询的卡片使用情况|[*Card*, Length 未知]

#### 备注
+ 会对数据库进行查询

# 备注
+ 数字长度 50 可能会改变
+ Card 的相关字段可以根据需要加减
+ 字段的名字**不出意外不再变动**。
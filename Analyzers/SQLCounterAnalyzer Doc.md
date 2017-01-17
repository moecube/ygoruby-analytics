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
athletic | 竞技场
entertainment | 娱乐匹配
handwritten | 手动输入
unknown | 未分类
default | 当与以上任一均不匹配，当做 unknown


## API
### 一并查询
#### URI
name | desc
---|---
Request URL | /analyze/counter
Request Method | GET
Content-Type | application/json

#### Param
param | desc
---|---
N/A | N/A

#### Return
desc | innerType
--- | ---
整个 Cache 内容 | { *Type*: { *Source*: { "Integer" } } }
### 按类别查询
#### URI
name | desc
---|---
Request URL | /analyze/counter/type
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
所查询类别的计数 | "Integer"
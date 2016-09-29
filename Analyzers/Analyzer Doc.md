# 后台 API 统计提交接口
## Struct Define

### Card
int --> id

### Deck
name | type | desc
---|---|---
main|[*Card*]|主卡组
side|[*Card*]|副卡组
ex|[*Card*]|额外卡组，可以放在main中

## APIs
### 上传卡组
#### URI
name | desc
---|---
Request URL | /analyze/deck/file, **未上线**
Request Method | POST
Request body | .ydk file

#### Return
"Deck read"

#### 备注
*request body* < 3KB

### 上传卡组
#### URI
name | desc
---|---
Request URL | /analyze/deck/json, **未上线**
Request Method | POST
Request body | *Deck*

#### Return
"Deck read"

#### 备注
*request body* < 3KB

### 上传录像
#### URI
name | desc
---|---
Request URL | /analyze/record, **未实现**
Request Method | POST
Request body | .yrp file

#### Return
501

### 上传压缩包
#### URI
name | desc
---|---
Request URL | /analyze/deck/tar, **未实现**
Request Method | POST
Request body | .yrp file

#### Return
501

## Inner APIs
> **这些 API 当由镜像自行调用，如无问题则无需关心**

### 将缓存输入数据库

#### URI
name | desc
---|---
Request URL | /analyze/finish, **未上线**
Request Method | POST

#### Return
"Finished"

### 根据日表计算各表
#### URI
name | desc
---|---
Request URL | /analyze, **未上线**
Request Method | DELETE

#### Return
"Cleared"
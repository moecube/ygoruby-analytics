# RecordStat
`RecordStat`是一项用于对录像和卡组进行统计分析的工程。
## 构成
它包括三个部分：
+ RecordUnzipper 用于打开录像和卡组文件，并提供了一系列有用的函数。
+ RecordAnalyzer 提供了一个用于进行单卡统计的分析器 `SQLSingleCardAnalyzer`。
+ HTMLGenerator 将结果输出为 HTML 页面。
## 使用方法
> ruby Main.rb "command"

command可以是以下任何内容的排列组合：
+ R(folder) 分析此目录下的所有录像。
+ r(record_path) 分析给定的录像。
+ D(folder) 分析此目录下的所有卡组。
+ d(deck_path) 分析给定的卡组。
+ C/c([time]) 清空数据库。请注意在`SQLSingleCardAnalyzer`中这一动作会将每日统计提交到周表中。
+ O/o([time]) 输出统计数据到`config.json`中所指定的位置。
+ F/f 在`手动模式`下，将内存中的数据提交到数据库。
+ G/g 输出 HTML 到`config.json`中所指定的位置。

上文所标识的[time]是希望按照处理的时间。不标识 time 参数的话，会使用当前的时间。

例如：
> ruby Main.rb "D(./Data/Test2/decks\_save\_bak)FO(2015-4-6)G"

分析`./Data/Test2/decks_save_bak`下的所有录像，并将它们当做2015年4月6日的数据输出并生成 HTML。

> ruby Main.rb OGC

使用当前时间输出并生成 HTML，然后清空数据库。

## 配置
待完成
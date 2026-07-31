# Session 库

Session 库是已保存 Session 和已处理文件的归档。

## 如何打开

使用主界面底栏的 :material-music-box-multiple-outline: 按钮。

## 库中显示什么

每个条目概括一组已保存的结果，包括类型、日期、时长、物种数和检测数。

Session 类型使用与主界面相同的图标：

- :material-microphone: — Live 模式的 Session
- :material-file-music: — 文件分析的 Session
- :material-map-marker: — Point Count 模式的 Session
- :material-routes: — Survey 模式的 Session

## 应用栏控件

- :material-magnify: — 按日期、Session 类型、地名、坐标、常用名或学名搜索
- 视图模式菜单 — 在**详细**、**紧凑**和**按物种**之间切换
- :material-swap-vertical: — 更改排序方式

## 视图模式

### 详细

显示包含更多元数据的完整 Session 卡片。

### 紧凑

显示更紧密的行，便于快速浏览。每行右侧有一个 :material-chevron-down: 按钮，可就地展开为详细视图的完整卡片内容——当您想快速看一眼某个 Session 的统计数据又不想丢失滚动位置时很方便。

### 按物种

按物种对 Session 分组，展开后显示包含该物种的各个 Session。

## 排序

可按**日期**（最新或最早在前）、**名称**（A–Z 或 Z–A）或**时长**（最长或最短在前）排序 Session。按时长排序在您想找出本周最长的 Survey，或那段不小心保存下来的 30 秒测试录音时很有用。

当 Session 按天分组时，每个日期标题行先显示用于整天操作的菜单（:material-dots-vertical:），展开/折叠箭头位于行尾。箭头是*最后*一个元素——与应用中其他所有可展开列表的约定一致——因此在靠右边缘点按总是会展开或折叠该分组。

## 本地时间

Session 库中显示的每个时间戳——列表行、日期分组标题、"开始" / "结束"徽标——都按手机*当前*所在时区呈现。Session 底层的时间戳以 UTC 存储，因此在柏林录制、之后在纽约打开的 Session，只会显示为早五（或六）小时——磁盘上的数据并未改变。在长时间 Survey 中途穿越时区时，显示的时间会跟随设备。

## 行操作

每个 Session 行都有两种操作方式：

- 每张卡片右侧的**三点菜单**（:material-dots-vertical:）会打开一个小菜单，包含**打开**、**分享**和**删除**。分享使用您当前在"设置 → 导出"中的偏好（格式和"包含音频"），并直接打开系统分享面板——不必为了把 Session 发给同事而先打开 Session 回顾。
- 把行向左或向右**滑动**即可删除。删除前仍会弹出确认对话框，因此误滑动是可以挽回的。

## 接下来会发生什么

点按任意 Session 即可打开 [Session 回顾](session-review.md)。

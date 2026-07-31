# 图标与控件

本页说明 BirdNET Live 中反复出现的控件和符号。下面的名称与应用中显示的完全一致。

## 通用导航控件

| 控件 | 出现位置 | 作用 |
|---|---|---|
| :material-tune: **设置** | 主界面底栏、Live、Point Count、Survey、文件分析、Session 回顾 | 打开设置。在模式界面中，打开与该工作方式最相关的设置。 |
| :material-magnify: **探索** | 主界面底栏 | 打开探索。 |
| :material-music-box-multiple-outline: **库** | 主界面底栏 | 打开 Session 库。 |
| :material-help-circle-outline: **帮助** | 主界面底栏、探索页头、Survey 面板、Session 回顾工具栏 | 打开帮助或该界面专属的帮助面板。 |
| :material-information-outline: **信息 / 关于** | 主界面底栏、信息栏、帮助面板 | 显示概况信息或汇总说明。 |
| :material-arrow-left: **返回** | Live 模式 | 返回上一界面。 |
| :material-open-in-new: **打开外部链接** | 关于界面、文档链接 | 打开外部页面，例如在线用户指南。 |
| :material-hand-heart: **捐助** | 关于界面 | 打开 BirdNET 捐助页面。 |

## 天气符号

| 控件 | 含义 |
|---|---|
| :material-weather-sunny: **晴** | 天空晴朗。 |
| :material-weather-partly-cloudy: **多云** | 以晴为主或部分多云时的太阳与云。 |
| :material-weather-cloudy: **阴** | 全天空被云覆盖。 |
| :material-weather-fog: **雾** | 雾或雾凇。 |
| :material-weather-partly-rainy: **毛毛雨** | 弱降水。 |
| :material-weather-rainy: **雨** | 降雨或阵雨。 |
| :material-weather-snowy: **雪** | 降雪或阵雪。 |
| :material-weather-lightning-rainy: **雷暴** | 雷暴天气。 |

## 开始、停止与 Session 控件

| 控件 | 含义 |
|---|---|
| :material-microphone: **麦克风** | 开始实时聆听。 |
| :material-stop: **停止** | 停止正在进行的录音、样点计数或 Survey。 |
| :material-play: **播放** | 启动已配置好的流程，或从暂停就绪状态继续。 |
| :material-close: **关闭 / 取消** | 取消正在进行的文件分析。 |
| :material-timer: **计时** | 时长或剩余时间。 |
| :material-alert-circle-outline: **错误** | 模型或处理出错。 |

## 位置与时间控件

| 控件 | 含义 |
|---|---|
| :material-crosshairs-gps: **当前位置** | 使用设备当前的 GPS 位置。 |
| :material-map-marker-plus: **手动坐标** | 手动输入坐标。 |
| :material-map-marker-off: **无位置** | 跳过位置，或表示位置不可用。 |
| :material-map-marker: **已有位置** | 确认位置、显示坐标，或标记带地图的 Session。 |
| :material-refresh: **刷新** | 重新读取当前位置或刷新预测列表。 |
| :material-map: **地图选点** | 在地图选择器中选取坐标。 |
| :material-calendar: **日期** | 设置或显示日期。 |
| :material-close: **清除** | 移除已选日期。 |

## 探索与物种符号

| 控件 | 含义 |
|---|---|
| 物种缩略图 | 该物种随应用附带的图片（如果有）。 |
| 置信度或地理模型百分比徽标 | 对模型输出的简要数值概括。数值越高，表示在该界面语境下支持越强。 |
| 月份标签（`1月`、`4月`、`7月`、`10月`、`12月`） | 物种浮层中周度预期频率图的参考点。 |

## 单条检测的操作

这些控件出现在应用中每一行检测上——Session 回顾的物种列表、片段播放面板、实时 Survey 的检测列表，以及 Survey 地图标记。完整行为请参见 [Session 回顾 → 单条检测的操作](session-review.md#单条检测的操作)。

| 控件 | 含义 |
|---|---|
| :material-check: **确认** | 一按即可打勾，把某条检测标记为已通过视觉或听觉核实。已确认的检测会在聚类行和地图标记上出现一个绿色小勾。 |
| :material-dots-vertical: **更多** | 打开该条检测的菜单，包含**分享检测**、**替换物种**、**删除检测**和**删除物种**。 |
| :material-share-variant: **分享检测** | 通过系统分享面板分享一条检测，并在有音频片段时一并附上——包括实时 Survey 期间从正在录制的文件中截取的片段。 |
| :material-swap-horizontal: **替换物种** | 为这条检测选择另一个物种。也可以把回顾列表中的某行向左滑动打开。 |
| :material-delete-outline: **删除检测** | 立即移除该行。会出现几秒钟的 SnackBar 可撤销。也可以把回顾列表中的某行向右滑动触发。 |
| :material-delete-sweep-outline: **删除物种** | 一次性从 Session 中移除该物种的全部检测，同样可通过 SnackBar 撤销。 |
| :material-ear-hearing: **听到** | 用于手动添加的检测：您听到了这只鸟。在选择物种后出现的确认面板中通过复选框设置。 |
| :material-eye: **看到** | 用于手动添加的检测：您看到了这只鸟。两个符号同时出现表示既听到*又*看到。 |

## Session 回顾工具栏

这些控件用于 Session 回顾界面。

| 控件 | 含义 |
|---|---|
| :material-plus-circle-outline: **添加** | 添加内容，例如物种或批注。 |
| :material-undo-variant: **撤销** / :material-redo-variant: **重做** | 在回顾的编辑记录中前后移动。 |
| :material-content-cut: **裁剪** | 进入裁剪模式，或表示裁剪模式已启用。 |
| :material-content-save: **保存** | 保存回顾中的修改。 |
| :material-share-variant: **分享** | 导出或分享 Session。 |
| :material-delete-outline: **删除** | 丢弃该 Session。 |
| :material-play: **继续** | 在该操作可用时，从 Session 回顾继续未完成的 Survey。 |

## 各界面的状态栏

### Live 模式

Live 信息栏使用 :material-information-outline:，后面跟着紧凑的标签，例如：

- `now` — 当前在实时列表中可见的检测
- `spp` — 独立物种数
- `det` — 检测总数
- 正在录音时的时长和预计录音大小

### Point Count

样点计数的计时栏把 :material-stop: **停止**、:material-timer: **计时**和进度条组合起来，显示计时 Session 的剩余部分。

### Survey

Survey 面板使用：

- :material-map-outline: **地图** — 实时地图标签页
- :material-equalizer: **语谱图** — 语谱图标签页
- :material-chart-bar: **汇总** — 汇总标签页
- :material-chart-bar: Survey 汇总视图中的统计标签

## 如有疑问

如果不确定某个控件的作用，可以打开应用中最近的帮助面板，或在本用户指南中查看该界面对应的工作流程页面。

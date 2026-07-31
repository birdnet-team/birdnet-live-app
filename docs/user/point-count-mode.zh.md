# Point Count 模式

Point Count 模式是 BirdNET Live 中定点计时的工作方式。

## 如何打开

在主界面点按带 :material-map-marker: 图标的 **Point Count 模式**卡片。

## 设置流程

样点计数的设置分为四步。

### 1. 时长与位置

选择：

- 可用时长标签之一
- 用 :material-crosshairs-gps: 获取当前 GPS 位置
- 用 :material-map-marker-plus: 手动输入坐标
- 用 :material-map-marker-off: 不使用位置
- 用 :material-map: 在地图上选点

当您从系统权限对话框或应用设置返回时，设置界面会刷新 GPS，因此新授予的位置
权限应当能在不重启向导的情况下更新坐标。同一区块中还有一张天气卡片。若天气
访问处于关闭状态，卡片会请求**允许查询天气**授权；启用后，它只用天气图标、
温度和风力预览该地点。保存样点计数时会复用同一份缓存的 Open-Meteo 快照。

### 2. 推理参数

为本次 Session 选择分析设置，例如窗口时长、推理频率、置信度阈值和物种筛选
模式。这些参数以您的全局设置为起点，但可以针对本次计数调整，而不改变您的
默认值。

### 3. 野外提示

该界面给出一份简短的应用内清单，供开始前逐项确认。

### 4. 准备就绪

准备就绪界面汇总所选时长，可用 :material-play: 开始。

## 样点计数进行中界面

进行中的样点计数界面以计时面板为核心。

### 顶部栏

- :material-stop: — 提前结束样点计数
- :material-timer: — 显示剩余时间
- :material-tune: — 打开 Point Count 设置

### 主要指示

- 倒计时进度条
- 显示当前检测、独立物种数和检测总数的紧凑信息栏
- 语谱图视图
- 检测列表

## 计数结束后

样点计数结束时，BirdNET Live 会保存 Session 并打开 [Session 回顾](session-review.md)。

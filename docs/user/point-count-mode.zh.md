# Point Count 模式

Point Count 模式是 BirdNET Live 中定点计时的工作方式。

## 如何打开

在主界面点按带 :app-locationOnRounded: 图标的 **Point Count 模式**卡片。

## 设置流程

样点计数的设置分为四步。

### 1. 时长与位置

选择：

- 选择一个可用时长：3、5、10、15、20、25 或 30 分钟
- 选择是否在屏幕关闭后继续计数（默认开启）
- 用 :app-myLocation: 获取当前 GPS 位置
- 用 :app-editLocationAlt: 手动输入坐标
- 用 :app-locationOff: 不使用位置
- 用 :app-mapSheet: 在地图上选点

当您从系统权限对话框或应用设置返回时，设置界面会刷新 GPS，因此新授予的位置
权限应当能在不重启向导的情况下更新坐标。同一区块中还有一张天气卡片。若天气
访问处于关闭状态，卡片会请求**允许查询天气**授权；启用后，它只用天气图标、
温度和风力预览该地点。保存样点计数时会复用同一份缓存的 Open-Meteo 快照。

### 2. 推理参数

为本次 Session 选择分析设置，例如推理频率、置信度阈值和物种筛选
模式。这些参数以您的全局设置为起点，但可以针对本次计数调整，而不改变您的
默认值。

| 设置控件 | 图标 |
|---|---|
| 麦克风 | :app-micRounded: |
| 录音模式 | :app-fiberManualRecordRounded: |
| 片段上下文 | :app-timerOutlined: |
| 推理频率 | :app-speedRounded: |
| 置信度阈值 | :app-verifiedRounded: |
| 灵敏度 | :app-hearing: |
| 物种筛选 | :app-filterAltRounded: |

每个控件旁的 :app-helpOutline: 按钮会说明其作用。第一步中的 :app-timerRounded: 时长控件和位置选择器也有相同的帮助按钮。

选择**完整**可保存连续音频（默认），选择**片段**可为每次检测到的鸣声保存片段，选择**关闭**则不保存音频。此选项与 Live Mode 的录音设置独立，并会为下次 Point Count 记住。片段使用与 Live Mode 相同的峰值窗口选择和片段上下文，不按位置减少片段。选择**片段**时，**片段前后余量**滑块控制每个分析窗口前后各保留多少秒音频；它也会更新 Live Mode 的片段上下文设置。

### 3. 野外提示

该界面给出一份简短的应用内清单，供开始前逐项确认。

### 4. 准备就绪

准备就绪界面汇总所选时长、录音选项和屏幕关闭后的行为。点按 :app-playArrowRounded: 开始。

## 样点计数进行中界面

进行中的样点计数界面以计时面板为核心。

### 顶部栏

- :app-stopRounded: — 提前结束样点计数
- :app-timerRounded: — 显示剩余时间
- :app-helpOutlineRounded: — 打开 Point Count 帮助
- :app-tuneRounded: — 打开 Point Count 设置

### 主要指示

- 倒计时进度条
- 显示当前检测、独立物种数和检测总数的紧凑信息栏
- 语谱图视图
- 检测列表

## 计数结束后

在 Point Count 设置中开启**熄屏后继续运行**时，锁屏或切换到其他应用（即使屏幕仍亮着）后，计数仍会继续，并在所选时长结束。倒计时使用实际经过的时间，界面暂停不会延长计数。Android 会显示带有打开和停止操作的常驻通知。关闭此开关可在锁屏或切换应用时提前结束计数。Point Count 不会暂停后再恢复，以免中断定时计数。如果在启动过程中离开应用，计数会被取消并显示消息；请重新设置并开始。Windows 上最小化窗口不会结束计数。

Point Count 结束后，BirdNET Live 会打开 [Session 回顾](session-review.md)。启用自动保存时，Session 会自动保存；否则，请在回顾界面手动保存需要保留的 Session。

启用自动保存时，未完成的计数还会在开始时、每 30 秒以及应用离开前台时保存。发生崩溃或断电后，最近保存的部分计数可在 Session 库中找到。

# 入门

## 安装

BirdNET Live 支持 Android、iOS 和 Windows。

### 系统要求

- **Android**：8.0（API 26）或更高
- **iOS**：15.0 或更高
- **Windows**：10 或更高（实验性）
- 应用与模型约需 300 MB 存储空间

### 下载

- **Android** — [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live)，或从 [GitHub 发布页](https://github.com/birdnet-team/birdnet-live-app/releases/latest)手动安装已签名的 APK。
- **iOS** — [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518)。
- **Windows** — 从源码自行构建；参见 [Developer Guide](../developer/building.md)。

## 首次使用流程

首次打开 BirdNET Live 时，应用会带您完成一段简短的引导和权限设置。

1. 阅读引导页面。
2. 查看使用规范和隐私政策。
3. 授予麦克风权限，让 BirdNET Live 可以处理音频。
4. 可选：授予位置权限，用于地理标记、探索、Point Count 和 Survey。
5. 可选：允许通知，用于长时间调查。

## 首次启动

1. **引导** — 简要介绍功能和权限
2. **使用规范与隐私** — 查看使用规范和隐私政策
3. **权限** — 授予麦克风访问权限（所有模式都需要）
4. **准备就绪** — 开始识别鸟类！

## 主界面概览

主界面是应用的中心。

### 主要模式卡片

- :material-microphone: **Live 模式**
- :material-map-marker: **Point Count 模式**
- :material-routes: **Survey 模式**
- :material-file-music: **文件分析**

### 底部按钮

- :material-tune: **设置**
- :material-magnify: **探索**
- :material-music-box-multiple-outline: **Session 库**
- :material-help-circle-outline: **帮助**
- :material-information-outline: **关于**

## 会保存哪些内容

BirdNET Live 会自动保存每个已完成的 Session，并在处理结束后在 Session 回顾中打开它。

- Live 模式的 Session 保存检测结果，并根据您的设置保存完整录音或片段。
- Point Count 模式的 Session 保存为计时样点计数。
- Survey 模式的 Session 保存路线、检测结果和相关元数据。
- 文件分析的结果会转换成可回顾的 Session。

## 推荐接着阅读

- 如果想快速了解界面上反复出现的符号，请阅读[图标与控件](icons-and-controls.md)。
- 在更改阈值、筛选、录音行为或语谱图显示之前，请阅读[设置](settings.md)。
- 打开您最常用工作方式的指南：[Live 模式](live-mode.md)、[Point Count 模式](point-count-mode.md)、[Survey 模式](survey-mode.md) 或[文件分析](file-analysis.md)。

## 权限

| 权限 | 用途 | 是否可选？ |
|------------|-------------|-----------|
| 麦克风 | 所有录音模式 | 必需 |
| 位置 | GPS 标记、Survey/Point Count | Live 模式下可选 |
| 存储 | 保存录音和导出文件 | 录音时必需 |
| 通知 | 后台 Survey 提醒 | 可选 |

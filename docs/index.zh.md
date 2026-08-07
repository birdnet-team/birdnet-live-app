# BirdNET Live

**装在口袋里的专业生物声学工具。**

BirdNET Live 是一款基于 Flutter 的应用，面向需要在野外获得可靠声学证据的野外研究者、保护工作者和观鸟者。它直接在您的设备上运行 BirdNET+ 音频分类器和地理模型，因此安装完成后，物种识别可以完全离线工作。

<p align="center">
  <img src="https://img.shields.io/badge/latest-v1.1.0-orange.svg" alt="Latest release: v1.1.0">
  <img src="https://img.shields.io/badge/species-9%2C789-brightgreen.svg" alt="Species: 9,789">
  <img src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows-green.svg" alt="Platforms">
</p>

## 功能

- **Live 模式** - 实时滚动语谱图与物种识别
- **Point Count 模式** - 带倒计时和样点元数据的计时 Session
- **Survey 模式** - 长时间样线调查，支持 GPS 轨迹、后台监测和检测抽样
- **文件分析** - 离线分析已有录音（WAV、FLAC、MP3、OGG 等）
- **ARU 模式** - 把设备变成自主录音单元，用于多日部署
- **探索** - 使用 BirdNET 地理模型浏览您所在位置可能出现的物种
- **Session 库** - 查看、编辑和导出过往 Session，并可回放音频
- **导出** - Raven Pro、CSV、JSON、GPX 和带来源元数据的 ZIP 包
- **设备端推理** - BirdNET+ 模型覆盖 9,789 个物种，无需联网
- **FLAC 录音** - 压缩音频，长时间调查时文件更小
- **无障碍** - 屏幕阅读器标签、提示文本，以及可选的检测语音播报
- **自适应布局** - 界面适配手机、平板以及竖屏和横屏
- **本地化** - 界面和语音播报支持 11 种语言

<p align="center">
  <img src="../assets/screenshots/live-mode.png" alt="Live Mode" width="150">
  <img src="../assets/screenshots/session-review.png" alt="Session Review" width="150">
  <img src="../assets/screenshots/explore.png" alt="Explore" width="150">
  <img src="../assets/screenshots/species.png" alt="Species Overlay" width="150">
  <img src="../assets/screenshots/file-analysis.png" alt="File Analysis" width="150">
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live"><b>Google Play</b></a>
  &nbsp;·&nbsp;
  <a href="https://apps.apple.com/us/app/birdnet-live/id6776168518"><b>App Store</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest"><b>Download APK</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app"><b>GitHub</b></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/birdnet-team/birdnet-live-app/releases"><b>All Releases</b></a>
</p>

## 快速开始

先看[用户指南](user/index.md)了解整体情况，然后打开[入门](user/getting-started.md)安装并运行 BirdNET Live。

## 安装

BirdNET Live 已上架 [Google Play](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live) 和 [App Store](https://apps.apple.com/us/app/birdnet-live/id6776168518)。

在 Android 上也可以手动安装已签名的 APK：从 [GitHub 发布页](https://github.com/birdnet-team/birdnet-live-app/releases/latest)下载最新版本，把 `.apk` 文件传到手机上并打开安装。您可能需要先在设备设置中允许安装未知来源的应用。

> **注意：** APK 约 260 MB，因为其中包含 BirdNET+ 模型文件和全部物种图片，以便离线使用。

## 面向开发者

架构、构建和参与贡献请参阅 [Developer Guide](developer/index.md)。开发者文档仅提供英文版本。

## 许可

BirdNET Live 的源代码基于 [MIT 许可证](https://github.com/birdnet-team/birdnet-live-app/blob/main/LICENSE)开源。随附的 BirdNET 模型权重基于 [Apache 2.0 许可证](https://github.com/birdnet-team/birdnet-live-app/blob/main/MODEL_LICENSE)授权。

# Umeko IR

[English](README.md)

[![Flutter CI](https://github.com/iamtwz/umeko-ir/actions/workflows/ci.yml/badge.svg)](https://github.com/iamtwz/umeko-ir/actions/workflows/ci.yml)
[![最新版本](https://img.shields.io/github/v/release/iamtwz/umeko-ir?sort=semver&label=release)](https://github.com/iamtwz/umeko-ir/releases/latest)
[![下载量](https://img.shields.io/github/downloads/iamtwz/umeko-ir/total?label=downloads)](https://github.com/iamtwz/umeko-ir/releases)
[![License: MIT](https://img.shields.io/github/license/iamtwz/umeko-ir)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![支持平台](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Android%20%7C%20Web-blue)](#下载)
[![Stars](https://img.shields.io/github/stars/iamtwz/umeko-ir?style=social)](https://github.com/iamtwz/umeko-ir/stargazers)
[![欢迎 PR](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/iamtwz/umeko-ir/pulls)

Umeko IR 是一个面向 Umeko IR 设备的跨平台热成像控制台。它可以通过串口或 USB 连接设备，实时渲染热成像画面，读取设备中保存的热图文件，并提供原始串口 HEX 调试输出，方便固件调试和日常使用。

本 App 同时适配两个硬件项目：

- [umeiko/RP2040-MLX90640-touchscreen-arduino](https://github.com/umeiko/RP2040-MLX90640-touchscreen-arduino) — RP2040 单光机型（MLX90640 + 触摸屏）。
- [umeiko/ESP32_Dual_Vision_Thermal](https://github.com/umeiko/ESP32_Dual_Vision_Thermal) — ESP32 双光机型（热成像 + 可见光融合）。

![实时热成像](assets/screenshots/live.png)

## 功能

- 实时热成像串流，显示数据包数量和识别到的传感器格式。
- 显示最高温、最低温、平均温度，以及自动标注的最高/最低温锚点。
- 自定义测温点，支持拖动、长按删除，以及实时和回放温度曲线。
- 配色、滤镜、双线性放大、水平翻转、垂直翻转和旋转控制在 Live、Gallery 和回放间统一。
- 支持摄氏 / 华氏 / 开尔文三种温度单位，在画面、曲线、导出和 Gallery 元数据中统一应用。
- 支持本地录制单帧快照和多帧热成像视频，使用 UIR v1 格式（带版本号、CRC 校验、0.01 °C 量化的 zlib 压缩）。
- Gallery 分为「设备」和「本地」两个标签：设备端边读边显示并显示进度，支持单张删除和二次确认清空；本地端管理 UIR 录制文件。
- 支持 PNG 截图导出、本地录像 APNG 导出，以及温度曲线 CSV 导出（视平台能力而定）。
- 串口调试页显示自动轮转的 HEX 原始数据。
- 内置 GitHub Releases 自动更新检查，可选的 Sentry 与 PostHog 遥测，全部可在设置中关闭。
- 支持浅色、深色、跟随系统主题。
- 内置英语、中文、日语界面。

## 截图

### 实时画面

![实时画面](assets/screenshots/live.png)

### 设备图库

![设备图库](assets/screenshots/gallery.png)

### 串口调试

![串口调试](assets/screenshots/debug.png)

## 支持的数据格式

- MLX90640 `MLX40BEGIN` / `MLX40END` float 帧，32x24（RP2040 和 ESP32）。
- MLX90641 `MLX41BEGIN` / `MLX41END` float 帧，16x12（ESP32）。
- Heimann `BEGIN` / `END` uint16 Kelvin 帧，32x32（ESP32 双光机型）。
- Legacy `BEGIN` / `END` float 帧，32x24（RP2040）。
- 本地 UIR v1 录制文件：带版本号、帧级 CRC 和 0.01 °C 量化的 zlib 压缩容器。
- 设备图库命令：`ls`、`cat /<file>.bin`、`rm /<file>.bin`、`clear_photos`。

## 平台支持

- macOS、Windows、Linux：通过 `flutter_libserialport` 访问串口。
- Android：通过 `usb_serial` 访问 USB 串口设备。
- Web：保留独立的 Web Serial 适配边界，实际硬件访问取决于浏览器 Web Serial 支持情况。

## 使用方式

1. 通过 USB 连接 Umeko IR 设备。
2. 打开 Umeko IR。
3. 如果没有自动选择串口，手动选择设备串口。
4. 点击 **连接**。
5. 点击 **开始串流** 查看实时热成像画面。
6. 使用 **配色**、**滤镜**、**双线性**、翻转和旋转控制调整图像显示。
7. 点击实时画面添加自定义测温点，拖动移动，长按删除。
8. 使用录制控件保存单帧快照或多帧 UIR 录像到本地。
9. 打开 **图库**，在 **设备** 和 **本地** 标签间切换；通过菜单导出 PNG、APNG 或 CSV。
10. 打开 **调试** 查看原始串口 HEX 数据。
11. 打开 **设置** 切换语言、主题、温度单位、遥测和自动更新。

默认比特率是 `115200`。断开连接后可以在设备设置中切换比特率。

## macOS 未签名应用

开发构建和早期发布版本可能没有进行 Apple 签名。首次打开时，macOS Gatekeeper 可能会提示“无法验证开发者”或阻止应用启动。

优先尝试系统提供的打开方式：

1. 打开 Finder。
2. 右键点击 `Umeko IR.app`。
3. 选择 **打开**。
4. 在警告弹窗中再次确认 **打开**。

如果应用是从网络下载的，并且仍然无法打开，可以移除 quarantine 属性：

```bash
xattr -dr com.apple.quarantine "/Applications/Umeko IR.app"
```

如果应用在其他目录，请把路径替换成实际的 `.app` 路径：

```bash
xattr -dr com.apple.quarantine "/path/to/Umeko IR.app"
```

## 开发

```bash
cd src
flutter pub get
dart format .
flutter analyze
flutter test
```

Android 构建应使用 JDK 17。仓库包含 `.java-version`，可供 jenv 或 asdf
等工具识别；如果你的 shell 默认使用更新的 JDK，请在运行 Gradle 或 Flutter
Android 构建前把 `JAVA_HOME` 指向 JDK 17。

启动 macOS 客户端：

```bash
cd src
flutter run -d macos
```

构建示例：

```bash
cd src
flutter build macos --release
flutter build apk --release
flutter build web --release
```

## 应用图标

Logo 源文件位于 `assets/logo/raw.png`。平台图标通过 `src/pubspec.yaml` 中的 `flutter_launcher_icons` 配置生成：

```bash
cd src
flutter pub run flutter_launcher_icons
```

## 说明

- macOS 串口访问需要在本地测试和正式分发时正确配置 App Sandbox。
- Android 打开 USB 串口设备时，系统会弹出 USB 权限请求。
- 构建缓存、本地 SDK 元数据、Pods、Gradle 状态和签名文件都已通过 `.gitignore` 忽略。

## 许可证

本项目使用 [MIT License](LICENSE)。

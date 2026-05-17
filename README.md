# Umeko IR

[简体中文](README.zh-CN.md)

[![Flutter CI](https://github.com/iamtwz/umeko-ir/actions/workflows/ci.yml/badge.svg)](https://github.com/iamtwz/umeko-ir/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/iamtwz/umeko-ir?sort=semver)](https://github.com/iamtwz/umeko-ir/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/iamtwz/umeko-ir/total)](https://github.com/iamtwz/umeko-ir/releases)
[![License: MIT](https://img.shields.io/github/license/iamtwz/umeko-ir)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Android%20%7C%20Web-blue)](#download)
[![Stars](https://img.shields.io/github/stars/iamtwz/umeko-ir?style=social)](https://github.com/iamtwz/umeko-ir/stargazers)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/iamtwz/umeko-ir/pulls)

Umeko IR is a cross-platform thermal imaging console for Umeko IR devices. It connects to the device over serial or USB, renders live thermal frames, reads image files stored on the device, and exposes raw serial diagnostics for firmware bring-up.

This app supports two device families:

- [umeiko/RP2040-MLX90640-touchscreen-arduino](https://github.com/umeiko/RP2040-MLX90640-touchscreen-arduino) — RP2040 single-thermal hardware (MLX90640 + touchscreen).
- [umeiko/ESP32_Dual_Vision_Thermal](https://github.com/umeiko/ESP32_Dual_Vision_Thermal) — ESP32 dual-vision hardware (thermal + visible-light fusion).

![Live thermal stream](assets/screenshots/live.png)

## Features

- Live thermal stream with packet counters and detected sensor format.
- Thermal overlays for max, min, and average temperature, plus auto hot/cold anchors.
- Custom measurement points with draggable labels and live/playback temperature curves.
- Color map, filter, bilinear upscaling, horizontal flip, vertical flip, and rotation controls shared by live view, gallery, and playback.
- Temperature unit setting for Celsius, Fahrenheit, and Kelvin across previews, charts, exports, and gallery metadata.
- Local recording for snapshots and multi-frame thermal videos in the UIR v1 format (versioned, CRC-checked, zlib compressed at 0.01 °C resolution).
- Gallery split into Device and Local tabs, with incremental loading, per-file delete, and a confirm-then-clear flow for device storage.
- PNG snapshot export, APNG export for recordings, and CSV export for temperature curves on supported platforms.
- Serial debug view with rolling HEX output.
- In-app update check against GitHub Releases, optional Sentry and PostHog telemetry, all toggleable from Settings.
- Light, dark, and system theme modes.
- Built-in English, Chinese, and Japanese UI.

## Screenshots

### Live

![Live view](assets/screenshots/live.png)

### Device Gallery

![Gallery view](assets/screenshots/gallery.png)

### Serial Debug

![Debug view](assets/screenshots/debug.png)

## Supported Data Formats

- MLX90640 `MLX40BEGIN` / `MLX40END` float frames, 32x24 (RP2040 and ESP32).
- MLX90641 `MLX41BEGIN` / `MLX41END` float frames, 16x12 (ESP32).
- Heimann `BEGIN` / `END` uint16 Kelvin frames, 32x32 (ESP32 dual-vision).
- Legacy `BEGIN` / `END` float frames, 32x24 (RP2040).
- Local UIR v1 recordings: versioned container with per-frame CRC and 0.01 °C zlib-quantized compression.
- Device gallery commands: `ls`, `cat /<file>.bin`, `rm /<file>.bin`, `clear_photos`.

## Platform Support

- macOS, Windows, Linux: serial access through `flutter_libserialport`.
- Android: USB serial access through `usb_serial`.
- Web: isolated Web Serial adapter boundary. Browser hardware access depends on Web Serial availability.

## Using the App

1. Connect the Umeko IR device over USB.
2. Open Umeko IR.
3. Pick the serial port if it is not selected automatically.
4. Click **Connect**.
5. Click **Start Stream** to view live thermal frames.
6. Use **Color Map**, **Filter**, **Bilinear**, flip, and rotation controls to tune the image.
7. Tap the live view to drop custom measurement points; drag to move, long-press to remove.
8. Use the recording controls to capture snapshots or multi-frame UIR videos to local storage.
9. Open **Gallery** to browse the **Device** tab (stored `.bin` files) and the **Local** tab (UIR recordings); export PNG, APNG, or CSV from the menu.
10. Open **Debug** when you need raw serial HEX diagnostics.
11. Open **Settings** to switch language, theme, temperature unit, telemetry, and auto-update preferences.

The default bitrate is `115200`. You can change it from Device Settings when disconnected.

## macOS Unsigned App

Development builds and early release builds may be unsigned. macOS Gatekeeper may show a warning such as "Apple could not verify" or block the app on first launch.

Try the normal override first:

1. Open Finder.
2. Right-click `Umeko IR.app`.
3. Choose **Open**.
4. Confirm **Open** in the warning dialog.

If the app was downloaded from the internet and still cannot be opened, remove the quarantine attribute:

```bash
xattr -dr com.apple.quarantine "/Applications/Umeko IR.app"
```

If the app is in another folder, replace the path with the actual `.app` path:

```bash
xattr -dr com.apple.quarantine "/path/to/Umeko IR.app"
```

## Development

```bash
cd src
flutter pub get
dart format .
flutter analyze
flutter test
```

Android builds should run on JDK 17. The repository includes `.java-version`
for tools such as jenv or asdf; if your shell defaults to a newer JDK, set
`JAVA_HOME` to JDK 17 before running Gradle or Flutter Android builds.

Run the macOS app:

```bash
cd src
flutter run -d macos
```

Build examples:

```bash
cd src
flutter build macos --release
flutter build apk --release
flutter build web --release
```

## Launcher Icons

The source logo is stored at `assets/logo/raw.png`. Platform icons are generated from `src/pubspec.yaml` using `flutter_launcher_icons`:

```bash
cd src
flutter pub run flutter_launcher_icons
```

## Notes

- macOS serial access requires the app sandbox to be configured appropriately for local testing and distribution.
- On Android, USB permission is requested by the OS when a supported serial device is opened.
- Build caches, local SDK metadata, Pods, Gradle state, and signing files are ignored by `.gitignore`.

## License

This project is licensed under the [MIT License](LICENSE).

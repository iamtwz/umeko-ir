# Umeko IR

[简体中文](README.zh-CN.md)

Umeko IR is a cross-platform thermal imaging console for Umeko IR devices. It connects to the device over serial or USB, renders live thermal frames, reads image files stored on the device, and exposes raw serial diagnostics for firmware bring-up.

This app is designed for hardware built from the [umeiko/RP2040-MLX90640-touchscreen-arduino](https://github.com/umeiko/RP2040-MLX90640-touchscreen-arduino) project.

![Live thermal stream](assets/screenshots/live.png)

## Features

- Live thermal stream with packet counters and detected sensor format.
- Thermal overlays for max, min, and average temperature.
- Auto anchors for hottest and coldest points.
- Color map and filter controls shared by live view and gallery preview.
- Bilinear upscaling, horizontal flip, vertical flip, and rotation controls.
- Device gallery reader for `.bin` thermal image files.
- Incremental gallery loading with progress feedback.
- Device file deletion and clear-device confirmation flow.
- Serial debug view with rolling HEX output.
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

- MLX90640 `MLX40BEGIN` / `MLX40END` float frames, 32x24.
- MLX90641 `MLX41BEGIN` / `MLX41END` float frames, 16x12.
- Heimann `BEGIN` / `END` uint16 Kelvin frames, 32x32.
- Legacy `BEGIN` / `END` float frames, 32x24.
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
7. Open **Gallery** and click **Read Device** to load stored `.bin` files.
8. Open **Debug** when you need raw serial HEX diagnostics.

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

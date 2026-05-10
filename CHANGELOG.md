# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added local UIR recording for snapshots and multi-frame thermal videos.
- Added UIR v1 storage with explicit format versioning, frame CRC checks, and
  0.01 °C quantized zlib compression.
- Added local recording storage, Gallery entries for local files, and playback
  controls for recorded UIR videos.
- Added custom measurement points with live temperature labels, dragging, and
  deletion.
- Added live and playback temperature curves for custom points.
- Added sharing/export actions for local UIR recordings, PNG snapshots, and CSV
  point temperature curves on supported platforms.
- Added a build channel switch for release and dev builds.
- Added Android dev build identity so CI/test APKs can be installed alongside
  the production APK.
- Added dev/release channel labels to app titles, About dialogs, and telemetry
  metadata.

### Changed

- Non-tag CI artifacts now include a `dev` suffix in their file names.
- Non-tag Android CI builds now produce `Umeko IR Dev` with package ID
  `com.example.umeko_ir_flutter.dev`.
- Tag-based release artifacts keep the production app name and package ID.

### Fixed

- Unified local and device gallery previews so local UIR files show thermal
  thumbnails, single-frame UIR files use image review controls, and multi-frame
  UIR files keep editable points and temperature curves during playback.
- Fixed temperature curve axis labels and hover tooltips to use stable
  one-decimal formatting without overlapping labels.
- Updated desktop and web default titles from the generated Flutter project name
  to `Umeko IR`.

## [1.0.5] - 2026-05-07

### Added

- Added signed Android release builds for tag-based GitHub Releases.
- Added Android release signing support through CI environment secrets.

### Changed

- Android release builds now use the configured release/upload keystore when
  signing secrets are available.
- Local and non-release Android builds continue to fall back to debug signing
  when release signing is not configured.

## [1.0.4] - 2026-05-07

### Added

- Added serial metadata normalization and tests for USB device identity.

### Fixed

- Fixed Windows serial port handling so `COMx` device names are not treated as
  filesystem paths.
- Improved desktop serial behavior by configuring DTR/RTS for more reliable
  device responses.
- Improved serial port display names by preferring stable USB metadata over
  unreliable localized driver descriptions.

## [1.0.3] - 2026-05-07

### Fixed

- Fixed GitHub Release publishing by ensuring the release job has repository
  context before calling the GitHub CLI.

## [1.0.2] - 2026-05-07

### Added

- Added packaged release artifacts for macOS, Windows, Linux, Web, and Android.

### Changed

- Release CI now uploads platform-specific archives with stable artifact names.

## [1.0.1] - 2026-05-07

### Added

- Initial public release of the Umeko IR Flutter app.
- Added cross-platform thermal imaging UI for live streaming, device gallery,
  render controls, and raw serial diagnostics.
- Added serial support for desktop, Android USB serial, and a Web Serial adapter
  boundary.
- Added English, Simplified Chinese, and Japanese localization.
- Added Sentry integration with an app tracking toggle.
- Added PostHog analytics with opt-out support.
- Added automatic update checks through GitHub Releases.
- Added GitHub repository link in Settings.
- Added CI for formatting, analysis, tests, and platform builds.

### Changed

- Pinned the Windows CI runner and updated GitHub Actions versions.
- Installed required macOS and Linux CI build dependencies.

### Documentation

- Added English and Simplified Chinese README files.
- Added macOS unsigned app launch instructions.

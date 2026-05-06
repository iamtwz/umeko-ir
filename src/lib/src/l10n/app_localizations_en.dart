// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Umeko IR';

  @override
  String get live => 'Live';

  @override
  String get gallery => 'Gallery';

  @override
  String get debug => 'Debug';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get refreshPorts => 'Refresh ports';

  @override
  String get settings => 'Settings';

  @override
  String get deviceSettings => 'Device Settings';

  @override
  String get appSettings => 'App Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get systemLanguage => 'System';

  @override
  String get systemTheme => 'System';

  @override
  String get lightTheme => 'Light';

  @override
  String get darkTheme => 'Dark';

  @override
  String get appTracking => 'App Tracking';

  @override
  String get appTrackingDescription =>
      'Share crash reports and performance traces to help improve the app.';

  @override
  String get autoUpdateCheck => 'Automatic Update Check';

  @override
  String get autoUpdateCheckDescription =>
      'Check GitHub Releases when the app opens.';

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String updateAvailableMessage(Object version) {
    return 'Version $version is available. Open GitHub Releases to download it?';
  }

  @override
  String get downloadUpdate => 'Download';

  @override
  String get notNow => 'Not Now';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

  @override
  String get japanese => 'Japanese';

  @override
  String get about => 'About';

  @override
  String get aboutAppDescription =>
      'Cross-platform thermal imaging viewer for Umeko IR devices.';

  @override
  String version(Object version) {
    return 'Version $version';
  }

  @override
  String get licenses => 'Licenses';

  @override
  String get serialPort => 'Serial port';

  @override
  String get chooseSerialPort => 'Choose serial port';

  @override
  String get noSerialPorts => 'No serial ports';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get noFrame => 'No frame';

  @override
  String get connectAndStartStream => 'Connect and start stream';

  @override
  String get noFormat => 'No format';

  @override
  String packets(Object count) {
    return 'Packets $count';
  }

  @override
  String get packetsMetric => 'Packets';

  @override
  String get readDevice => 'Read device';

  @override
  String get clearDevice => 'Clear device';

  @override
  String deviceFiles(Object count) {
    return '$count files';
  }

  @override
  String get noDevicePhotos => 'No device photos';

  @override
  String get readDeviceFiles => 'Read device files to populate this view';

  @override
  String get delete => 'Delete';

  @override
  String photoStats(Object width, Object height, Object max, Object min) {
    return '${width}x$height  Max $max C  Min $min C';
  }

  @override
  String get startStream => 'Start Stream';

  @override
  String get stopStream => 'Stop Stream';

  @override
  String get colorMap => 'Color Map';

  @override
  String get filter => 'Filter';

  @override
  String get bilinear => 'Bilinear';

  @override
  String get horizontalFlip => 'Horizontal Flip';

  @override
  String get verticalFlip => 'Vertical Flip';

  @override
  String get received => 'Received';

  @override
  String get format => 'Format';

  @override
  String get bitrate => 'Bitrate';

  @override
  String get disconnectBeforeBitrate => 'Disconnect before changing bitrate.';

  @override
  String get defaultFirmwareBitrate => 'Default firmware setting is 115200.';

  @override
  String get serialDebug => 'Serial Debug';

  @override
  String get clear => 'Clear';

  @override
  String get clearDevicePhotosTitle => 'Clear device photos?';

  @override
  String get clearDevicePhotosMessage =>
      'This deletes all thermal image files stored on the device. This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get colorMapIronbow => 'Ironbow';

  @override
  String get colorMapRainbow => 'Rainbow';

  @override
  String get colorMapGrayscale => 'Grayscale';

  @override
  String get colorMapBlackHot => 'Black Hot';

  @override
  String get colorMapHot => 'Hot';

  @override
  String get colorMapInferno => 'Inferno';

  @override
  String get colorMapPlasma => 'Plasma';

  @override
  String get colorMapJet => 'Jet';

  @override
  String get colorMapCool => 'Cool';

  @override
  String get filterNone => 'None';

  @override
  String get filterGaussian => 'Gaussian';

  @override
  String get filterSharpen => 'Sharpen';

  @override
  String get filterSobel => 'Sobel';

  @override
  String get filterEmboss => 'Emboss';
}

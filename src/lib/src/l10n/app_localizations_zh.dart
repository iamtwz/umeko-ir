// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Umeko IR';

  @override
  String get live => '实时';

  @override
  String get gallery => '图库';

  @override
  String get debug => '调试';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get refreshPorts => '刷新串口';

  @override
  String get settings => '设置';

  @override
  String get deviceSettings => '设备设置';

  @override
  String get appSettings => '应用设置';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get systemTheme => '跟随系统';

  @override
  String get lightTheme => '浅色';

  @override
  String get darkTheme => '深色';

  @override
  String get appTracking => 'App 追踪';

  @override
  String get appTrackingDescription => '分享匿名使用统计、崩溃报告和性能追踪，帮助改进应用。';

  @override
  String get autoUpdateCheck => '自动检查更新';

  @override
  String get autoUpdateCheckDescription => 'App 打开时检查 GitHub Releases。';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String updateAvailableMessage(Object version) {
    return '版本 $version 已可用。要打开 GitHub Releases 下载吗？';
  }

  @override
  String get downloadUpdate => '下载';

  @override
  String get notNow => '稍后';

  @override
  String get english => '英语';

  @override
  String get chinese => '中文';

  @override
  String get japanese => '日语';

  @override
  String get about => '关于';

  @override
  String get aboutAppDescription => '面向 Umeko IR 设备的跨平台热成像查看器。';

  @override
  String version(Object version) {
    return '版本 $version';
  }

  @override
  String get githubRepository => 'GitHub 仓库';

  @override
  String get licenses => '开源许可';

  @override
  String get serialPort => '串口';

  @override
  String get chooseSerialPort => '选择串口';

  @override
  String get noSerialPorts => '无可用串口';

  @override
  String get dismiss => '关闭';

  @override
  String get noFrame => '暂无画面';

  @override
  String get connectAndStartStream => '连接后开始串流';

  @override
  String get noFormat => '无格式';

  @override
  String packets(Object count) {
    return '包 $count';
  }

  @override
  String get packetsMetric => '数据包';

  @override
  String get readDevice => '读取设备';

  @override
  String get clearDevice => '清空设备';

  @override
  String deviceFiles(Object count) {
    return '$count 个文件';
  }

  @override
  String get noDevicePhotos => '暂无设备图片';

  @override
  String get readDeviceFiles => '读取设备文件后会显示在这里';

  @override
  String get delete => '删除';

  @override
  String photoStats(Object width, Object height, Object max, Object min) {
    return '${width}x$height  最高 $max C  最低 $min C';
  }

  @override
  String get startStream => '开始串流';

  @override
  String get stopStream => '停止串流';

  @override
  String get colorMap => '配色';

  @override
  String get filter => '滤镜';

  @override
  String get bilinear => '双线性';

  @override
  String get horizontalFlip => '水平翻转';

  @override
  String get verticalFlip => '垂直翻转';

  @override
  String get received => '已接收';

  @override
  String get format => '格式';

  @override
  String get bitrate => '比特率';

  @override
  String get disconnectBeforeBitrate => '修改比特率前请先断开连接。';

  @override
  String get defaultFirmwareBitrate => '默认固件设置为 115200。';

  @override
  String get serialDebug => '串口调试';

  @override
  String get clear => '清空';

  @override
  String get clearDevicePhotosTitle => '清空设备图片？';

  @override
  String get clearDevicePhotosMessage => '这会删除设备上存储的所有热成像图片文件。此操作不可撤销。';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

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

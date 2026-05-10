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
  String get temperatureUnit => '温度单位';

  @override
  String get temperatureUnitCelsius => '摄氏度 (°C)';

  @override
  String get temperatureUnitFahrenheit => '华氏度 (°F)';

  @override
  String get temperatureUnitKelvin => '开尔文 (K)';

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

  @override
  String get capture => '拍摄';

  @override
  String get record => '录制';

  @override
  String get stopRecording => '停止';

  @override
  String get captureSaved => '拍摄已保存';

  @override
  String get recordingSaved => '录制已保存';

  @override
  String get advancedRenderSettings => '画面设置';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String localFiles(Object count) {
    return '本地：$count';
  }

  @override
  String localFileBreakdown(Object photoCount, Object videoCount) {
    return '$photoCount 张图片 · $videoCount 段视频';
  }

  @override
  String get deviceFilesSection => '设备文件';

  @override
  String get localRecordings => '本地录制';

  @override
  String get export => '导出';

  @override
  String get shareUir => '保存 UIR';

  @override
  String get sharePng => '保存 PNG';

  @override
  String get shareApng => '保存 APNG';

  @override
  String get shareCsv => '保存 CSV';

  @override
  String get exportCsv => '导出 CSV';

  @override
  String get moreActions => '更多操作';

  @override
  String get fileInformation => '文件信息';

  @override
  String get fileName => '文件名';

  @override
  String get fileFormat => '格式';

  @override
  String get source => '来源';

  @override
  String get type => '类型';

  @override
  String get resolution => '分辨率';

  @override
  String get frames => '帧数';

  @override
  String get durationLabel => '时长';

  @override
  String get temperatureRangeLabel => '温度范围';

  @override
  String get averageTemperature => '平均温度';

  @override
  String get fileSize => '文件大小';

  @override
  String get createdAt => '创建时间';

  @override
  String get photoKind => '图片';

  @override
  String get videoKind => '视频';

  @override
  String get exportOptions => '导出选项';

  @override
  String get exportingApng => '正在导出 APNG';

  @override
  String get done => '完成';

  @override
  String get exportLog => '导出日志';

  @override
  String get exportPhasePreparing => '准备中';

  @override
  String get exportPhasePreparingText => '准备文字';

  @override
  String get exportPhaseRenderingFrames => '渲染帧';

  @override
  String get exportPhaseEncodingApng => '编码 APNG';

  @override
  String get exportPhaseSaving => '保存中';

  @override
  String get exportPhaseComplete => '已完成';

  @override
  String get exportPhaseCancelling => '正在取消';

  @override
  String get exportPhaseCancelled => '已取消';

  @override
  String get exportMessageStartingApngExport => '开始导出 APNG';

  @override
  String get exportMessageReadingUirFile => '读取 UIR 文件';

  @override
  String exportMessageRenderingTextOverlays(Object count) {
    return '渲染 $count 个文字标注';
  }

  @override
  String exportMessageRenderedTextOverlay(Object index, Object total) {
    return '已渲染文字标注 $index/$total';
  }

  @override
  String exportMessageRenderingFrame(Object index, Object total) {
    return '正在渲染帧 $index/$total';
  }

  @override
  String exportMessageRenderedFrame(Object index, Object total) {
    return '已渲染帧 $index/$total';
  }

  @override
  String get exportMessageCompressingAnimatedPngFrames => '压缩动画 PNG 帧';

  @override
  String get exportMessageApngEncodingComplete => 'APNG 编码完成';

  @override
  String get exportMessageWritingApngFile => '写入 APNG 文件';

  @override
  String get exportMessageApngFileSaved => 'APNG 文件已保存';

  @override
  String get exportMessageStoppingApngExport => '正在停止 APNG 导出';

  @override
  String get exportMessageExportCancelled => '导出已取消';

  @override
  String get temperatureCurves => '温度曲线';

  @override
  String get includeLegend => '显示图例';

  @override
  String get includeMeasurementPoints => '显示自定义点';

  @override
  String get previousFrame => '上一帧';

  @override
  String get nextFrame => '下一帧';

  @override
  String get noReadableFrames => '无可读帧';

  @override
  String get noReadableFramesMessage => '此 UIR 文件不包含可读取的帧。';

  @override
  String get noPointSamples => '暂无测温点数据';

  @override
  String framesMetric(Object count) {
    return '$count 帧';
  }
}

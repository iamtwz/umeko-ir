// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Umeko IR';

  @override
  String get live => 'ライブ';

  @override
  String get gallery => 'ギャラリー';

  @override
  String get debug => 'デバッグ';

  @override
  String get connected => '接続済み';

  @override
  String get disconnected => '未接続';

  @override
  String get connect => '接続';

  @override
  String get disconnect => '切断';

  @override
  String get refreshPorts => 'ポートを更新';

  @override
  String get settings => '設定';

  @override
  String get deviceSettings => 'デバイス設定';

  @override
  String get appSettings => 'アプリ設定';

  @override
  String get language => '言語';

  @override
  String get theme => 'テーマ';

  @override
  String get systemLanguage => 'システム';

  @override
  String get systemTheme => 'システム';

  @override
  String get lightTheme => 'ライト';

  @override
  String get darkTheme => 'ダーク';

  @override
  String get appTracking => 'アプリ追跡';

  @override
  String get appTrackingDescription =>
      '匿名の利用状況、クラッシュレポート、パフォーマンストレースを共有して、アプリの改善に役立てます。';

  @override
  String get autoUpdateCheck => '自動アップデート確認';

  @override
  String get autoUpdateCheckDescription => 'アプリ起動時に GitHub Releases を確認します。';

  @override
  String get updateAvailableTitle => '新しいバージョンがあります';

  @override
  String updateAvailableMessage(Object version) {
    return 'バージョン $version が利用できます。GitHub Releases を開いてダウンロードしますか？';
  }

  @override
  String get downloadUpdate => 'ダウンロード';

  @override
  String get notNow => '後で';

  @override
  String get english => '英語';

  @override
  String get chinese => '中国語';

  @override
  String get japanese => '日本語';

  @override
  String get about => 'About';

  @override
  String get aboutAppDescription => 'Umeko IR デバイス向けのクロスプラットフォーム熱画像ビューアです。';

  @override
  String version(Object version) {
    return 'バージョン $version';
  }

  @override
  String get githubRepository => 'GitHub リポジトリ';

  @override
  String get licenses => 'ライセンス';

  @override
  String get serialPort => 'シリアルポート';

  @override
  String get chooseSerialPort => 'ポートを選択';

  @override
  String get noSerialPorts => '利用可能なポートなし';

  @override
  String get dismiss => '閉じる';

  @override
  String get noFrame => 'フレームなし';

  @override
  String get connectAndStartStream => '接続してストリームを開始';

  @override
  String get noFormat => '形式なし';

  @override
  String packets(Object count) {
    return 'パケット $count';
  }

  @override
  String get packetsMetric => 'パケット';

  @override
  String get readDevice => 'デバイス読込';

  @override
  String get clearDevice => 'デバイス消去';

  @override
  String deviceFiles(Object count) {
    return '$count ファイル';
  }

  @override
  String get noDevicePhotos => 'デバイス画像なし';

  @override
  String get readDeviceFiles => 'デバイスファイルを読み込むとここに表示されます';

  @override
  String get delete => '削除';

  @override
  String photoStats(Object width, Object height, Object max, Object min) {
    return '${width}x$height  最高 $max C  最低 $min C';
  }

  @override
  String get startStream => 'ストリーム開始';

  @override
  String get stopStream => 'ストリーム停止';

  @override
  String get colorMap => 'カラーマップ';

  @override
  String get filter => 'フィルター';

  @override
  String get bilinear => 'バイリニア';

  @override
  String get horizontalFlip => '水平反転';

  @override
  String get verticalFlip => '垂直反転';

  @override
  String get received => '受信';

  @override
  String get format => '形式';

  @override
  String get bitrate => 'ビットレート';

  @override
  String get disconnectBeforeBitrate => 'ビットレートを変更する前に切断してください。';

  @override
  String get defaultFirmwareBitrate => '既定のファームウェア設定は 115200 です。';

  @override
  String get serialDebug => 'シリアルデバッグ';

  @override
  String get clear => '消去';

  @override
  String get clearDevicePhotosTitle => 'デバイス画像を消去しますか？';

  @override
  String get clearDevicePhotosMessage =>
      'デバイスに保存されたすべての熱画像ファイルを削除します。この操作は元に戻せません。';

  @override
  String get cancel => 'キャンセル';

  @override
  String get close => '閉じる';

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

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
  String get device => 'デバイス';

  @override
  String get deviceCapabilitiesIntro =>
      'デバイス固有のツール。接続中の機器が対応していない機能はグレー表示されます。';

  @override
  String get deviceCapabilityProbing => 'デバイス機能を確認中…';

  @override
  String get deviceCapabilityProbeFailed => 'デバイス機能の確認に失敗しました';

  @override
  String get dualVisionProbeFailedRetryDetail => 'デバイスから読み込む操作でもう一度お試しください。';

  @override
  String get deviceCapabilityProbeOnOpen => '開いたときに確認します';

  @override
  String get deviceCapabilityUnsupported => 'この機器はこの機能に対応していません';

  @override
  String get deviceNotConnected => 'デバイス未接続';

  @override
  String get serialDebugSubtitle => '全デバイス共通の TX/RX HEX ログ';

  @override
  String get serialDebugEmpty => 'シリアル通信はまだありません。';

  @override
  String get dualVisionAlignment => 'デュアル光位置合わせ';

  @override
  String get dualVisionAlignmentSubtitle => '可視光カメラを熱センサーに合わせ、融合の透明度を調整';

  @override
  String get dualVisionConnectFirst => 'デュアル光機器を先に接続してください。';

  @override
  String get dualVisionUnsupportedDetail =>
      '位置合わせ機能は ESP32 デュアル光モデルのみ対応。RP2040 サーマル専用モデルには可視光カメラはありません。';

  @override
  String get dualVisionReadFromDevice => 'デバイスから読み取る';

  @override
  String get dualVisionTranslate => '平行移動';

  @override
  String get dualVisionScale => 'スケール';

  @override
  String get dualVisionCameraOrientation => 'カメラの向き';

  @override
  String get dualVisionCameraFlipSubtitle => '可視光カメラの補助的な向き設定';

  @override
  String get dualVisionAlignmentControls => '位置合わせ';

  @override
  String get dualVisionPosition => '位置';

  @override
  String get dualVisionNudgeHint => '1 回につき 1 ピクセル移動';

  @override
  String get dualVisionUniformScale => '縦横比を保持';

  @override
  String get dualVisionScaleLinked => 'X と Y のスケールを連動';

  @override
  String get dualVisionScaleUnlinked => 'X と Y のスケールを個別に調整';

  @override
  String get dualVisionQuickAdjust => 'クイック調整';

  @override
  String get dualVisionQuickAdjustSubtitle => 'スライダーで大きく連続調整';

  @override
  String get dualVisionCanvasHint => 'ガイド表示です。実際の融合結果はデバイス画面で確認してください';

  @override
  String get dualVisionGestureHint => 'ドラッグで移動 · 角で拡縮 · 上のハンドルで回転';

  @override
  String get dualVisionCameraFrame => 'カメラ画角';

  @override
  String get dualVisionThermalArea => 'サーマル領域';

  @override
  String get dualVisionDefaultPosition => '初期位置';

  @override
  String get dualVisionAdjustments => 'キャリブレーション操作';

  @override
  String get dualVisionRetry => '再試行';

  @override
  String get dualVisionReady => '準備完了';

  @override
  String get dualVisionSyncing => '同期中…';

  @override
  String get dualVisionSaved => '保存済み';

  @override
  String get dualVisionSyncFailed => '同期に失敗';

  @override
  String get dualVisionResetTitle => '位置合わせをリセットしますか？';

  @override
  String get dualVisionResetMessage =>
      '位置、スケール、回転、融合強度を初期値に戻します。カメラの向きは変更されません。';

  @override
  String get dualVisionResetAction => 'リセット';

  @override
  String get dualVisionTx => 'X 平行移動';

  @override
  String get dualVisionTy => 'Y 平行移動';

  @override
  String get dualVisionSx => 'X スケール';

  @override
  String get dualVisionSy => 'Y スケール';

  @override
  String get dualVisionAngle => '回転';

  @override
  String get dualVisionFusionAlpha => '融合 α';

  @override
  String get verticalFlipCamera => '縦反転(カメラ)';

  @override
  String get horizontalMirrorCamera => '横反転(カメラ)';

  @override
  String get dualVisionFlipStateUnknown => '現在の状態は不明です';

  @override
  String get toggle => '切り替え';

  @override
  String get resetToDefaults => '位置合わせと透明度をリセット';

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
  String get temperatureUnit => '温度単位';

  @override
  String get temperatureUnitCelsius => '摂氏 (°C)';

  @override
  String get temperatureUnitFahrenheit => '華氏 (°F)';

  @override
  String get temperatureUnitKelvin => 'ケルビン (K)';

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

  @override
  String get capture => '撮影';

  @override
  String get record => '録画';

  @override
  String get stopRecording => '停止';

  @override
  String get captureSaved => '撮影を保存しました';

  @override
  String get recordingSaved => '録画を保存しました';

  @override
  String get advancedRenderSettings => '画面設定';

  @override
  String get playbackSpeed => '再生速度';

  @override
  String localFiles(Object count) {
    return 'ローカル: $count';
  }

  @override
  String localFileBreakdown(Object photoCount, Object videoCount) {
    return '画像 $photoCount 件 · 動画 $videoCount 件';
  }

  @override
  String get deviceFilesSection => 'デバイスファイル';

  @override
  String get localRecordings => 'ローカル録画';

  @override
  String get export => 'エクスポート';

  @override
  String get shareUir => 'UIR を保存';

  @override
  String get sharePng => 'PNG を保存';

  @override
  String get shareApng => 'APNG を保存';

  @override
  String get shareCsv => 'CSV を保存';

  @override
  String get exportCsv => 'CSV をエクスポート';

  @override
  String get moreActions => 'その他の操作';

  @override
  String get fileInformation => 'ファイル情報';

  @override
  String get fileName => 'ファイル名';

  @override
  String get fileFormat => '形式';

  @override
  String get source => 'ソース';

  @override
  String get type => '種類';

  @override
  String get resolution => '解像度';

  @override
  String get frames => 'フレーム数';

  @override
  String get durationLabel => '長さ';

  @override
  String get temperatureRangeLabel => '温度範囲';

  @override
  String get averageTemperature => '平均温度';

  @override
  String get fileSize => 'ファイルサイズ';

  @override
  String get createdAt => '作成日時';

  @override
  String get photoKind => '画像';

  @override
  String get videoKind => '動画';

  @override
  String get exportOptions => 'エクスポート設定';

  @override
  String get exportingApng => 'APNG をエクスポート中';

  @override
  String get done => '完了';

  @override
  String get exportLog => 'エクスポートログ';

  @override
  String get exportPhasePreparing => '準備中';

  @override
  String get exportPhasePreparingText => 'テキスト準備中';

  @override
  String get exportPhaseRenderingFrames => 'フレーム描画中';

  @override
  String get exportPhaseEncodingApng => 'APNG エンコード中';

  @override
  String get exportPhaseSaving => '保存中';

  @override
  String get exportPhaseComplete => '完了';

  @override
  String get exportPhaseCancelling => 'キャンセル中';

  @override
  String get exportPhaseCancelled => 'キャンセル済み';

  @override
  String get exportMessageStartingApngExport => 'APNG エクスポートを開始しています';

  @override
  String get exportMessageReadingUirFile => 'UIR ファイルを読み込んでいます';

  @override
  String exportMessageRenderingTextOverlays(Object count) {
    return '$count 件のテキストを描画しています';
  }

  @override
  String exportMessageRenderedTextOverlay(Object index, Object total) {
    return 'テキストを描画しました $index/$total';
  }

  @override
  String exportMessageRenderingFrame(Object index, Object total) {
    return 'フレームを描画しています $index/$total';
  }

  @override
  String exportMessageRenderedFrame(Object index, Object total) {
    return 'フレームを描画しました $index/$total';
  }

  @override
  String get exportMessageCompressingAnimatedPngFrames =>
      'アニメーション PNG フレームを圧縮しています';

  @override
  String get exportMessageApngEncodingComplete => 'APNG エンコードが完了しました';

  @override
  String get exportMessageWritingApngFile => 'APNG ファイルを書き込んでいます';

  @override
  String get exportMessageApngFileSaved => 'APNG ファイルを保存しました';

  @override
  String get exportMessageStoppingApngExport => 'APNG エクスポートを停止しています';

  @override
  String get exportMessageExportCancelled => 'エクスポートをキャンセルしました';

  @override
  String get temperatureCurves => '温度曲線';

  @override
  String get includeLegend => '凡例を表示';

  @override
  String get includeMeasurementPoints => '測定点を表示';

  @override
  String get previousFrame => '前のフレーム';

  @override
  String get nextFrame => '次のフレーム';

  @override
  String get noReadableFrames => 'フレームなし';

  @override
  String get noReadableFramesMessage => 'この UIR ファイルには読み取り可能なフレームがありません。';

  @override
  String get noPointSamples => '測定点サンプルなし';

  @override
  String framesMetric(Object count) {
    return '$count フレーム';
  }
}

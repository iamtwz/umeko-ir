import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Umeko IR'**
  String get appTitle;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @refreshPorts.
  ///
  /// In en, this message translates to:
  /// **'Refresh ports'**
  String get refreshPorts;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @deviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Device Settings'**
  String get deviceSettings;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @temperatureUnit.
  ///
  /// In en, this message translates to:
  /// **'Temperature Unit'**
  String get temperatureUnit;

  /// No description provided for @temperatureUnitCelsius.
  ///
  /// In en, this message translates to:
  /// **'Celsius (°C)'**
  String get temperatureUnitCelsius;

  /// No description provided for @temperatureUnitFahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit (°F)'**
  String get temperatureUnitFahrenheit;

  /// No description provided for @temperatureUnitKelvin.
  ///
  /// In en, this message translates to:
  /// **'Kelvin (K)'**
  String get temperatureUnitKelvin;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @systemTheme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemTheme;

  /// No description provided for @lightTheme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightTheme;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTheme;

  /// No description provided for @appTracking.
  ///
  /// In en, this message translates to:
  /// **'App Tracking'**
  String get appTracking;

  /// No description provided for @appTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Share anonymous usage analytics, crash reports, and performance traces to help improve the app.'**
  String get appTrackingDescription;

  /// No description provided for @autoUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Automatic Update Check'**
  String get autoUpdateCheck;

  /// No description provided for @autoUpdateCheckDescription.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub Releases when the app opens.'**
  String get autoUpdateCheckDescription;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. Open GitHub Releases to download it?'**
  String updateAvailableMessage(Object version);

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadUpdate;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @japanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get japanese;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Cross-platform thermal imaging viewer for Umeko IR devices.'**
  String get aboutAppDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @githubRepository.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get githubRepository;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @serialPort.
  ///
  /// In en, this message translates to:
  /// **'Serial port'**
  String get serialPort;

  /// No description provided for @chooseSerialPort.
  ///
  /// In en, this message translates to:
  /// **'Choose serial port'**
  String get chooseSerialPort;

  /// No description provided for @noSerialPorts.
  ///
  /// In en, this message translates to:
  /// **'No serial ports'**
  String get noSerialPorts;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @noFrame.
  ///
  /// In en, this message translates to:
  /// **'No frame'**
  String get noFrame;

  /// No description provided for @connectAndStartStream.
  ///
  /// In en, this message translates to:
  /// **'Connect and start stream'**
  String get connectAndStartStream;

  /// No description provided for @noFormat.
  ///
  /// In en, this message translates to:
  /// **'No format'**
  String get noFormat;

  /// No description provided for @packets.
  ///
  /// In en, this message translates to:
  /// **'Packets {count}'**
  String packets(Object count);

  /// No description provided for @packetsMetric.
  ///
  /// In en, this message translates to:
  /// **'Packets'**
  String get packetsMetric;

  /// No description provided for @readDevice.
  ///
  /// In en, this message translates to:
  /// **'Read device'**
  String get readDevice;

  /// No description provided for @clearDevice.
  ///
  /// In en, this message translates to:
  /// **'Clear device'**
  String get clearDevice;

  /// No description provided for @deviceFiles.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String deviceFiles(Object count);

  /// No description provided for @noDevicePhotos.
  ///
  /// In en, this message translates to:
  /// **'No device photos'**
  String get noDevicePhotos;

  /// No description provided for @readDeviceFiles.
  ///
  /// In en, this message translates to:
  /// **'Read device files to populate this view'**
  String get readDeviceFiles;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @photoStats.
  ///
  /// In en, this message translates to:
  /// **'{width}x{height}  Max {max} C  Min {min} C'**
  String photoStats(Object width, Object height, Object max, Object min);

  /// No description provided for @startStream.
  ///
  /// In en, this message translates to:
  /// **'Start Stream'**
  String get startStream;

  /// No description provided for @stopStream.
  ///
  /// In en, this message translates to:
  /// **'Stop Stream'**
  String get stopStream;

  /// No description provided for @colorMap.
  ///
  /// In en, this message translates to:
  /// **'Color Map'**
  String get colorMap;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @bilinear.
  ///
  /// In en, this message translates to:
  /// **'Bilinear'**
  String get bilinear;

  /// No description provided for @horizontalFlip.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Flip'**
  String get horizontalFlip;

  /// No description provided for @verticalFlip.
  ///
  /// In en, this message translates to:
  /// **'Vertical Flip'**
  String get verticalFlip;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @disconnectBeforeBitrate.
  ///
  /// In en, this message translates to:
  /// **'Disconnect before changing bitrate.'**
  String get disconnectBeforeBitrate;

  /// No description provided for @defaultFirmwareBitrate.
  ///
  /// In en, this message translates to:
  /// **'Default firmware setting is 115200.'**
  String get defaultFirmwareBitrate;

  /// No description provided for @serialDebug.
  ///
  /// In en, this message translates to:
  /// **'Serial Debug'**
  String get serialDebug;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearDevicePhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear device photos?'**
  String get clearDevicePhotosTitle;

  /// No description provided for @clearDevicePhotosMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes all thermal image files stored on the device. This action cannot be undone.'**
  String get clearDevicePhotosMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @colorMapIronbow.
  ///
  /// In en, this message translates to:
  /// **'Ironbow'**
  String get colorMapIronbow;

  /// No description provided for @colorMapRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get colorMapRainbow;

  /// No description provided for @colorMapGrayscale.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get colorMapGrayscale;

  /// No description provided for @colorMapBlackHot.
  ///
  /// In en, this message translates to:
  /// **'Black Hot'**
  String get colorMapBlackHot;

  /// No description provided for @colorMapHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get colorMapHot;

  /// No description provided for @colorMapInferno.
  ///
  /// In en, this message translates to:
  /// **'Inferno'**
  String get colorMapInferno;

  /// No description provided for @colorMapPlasma.
  ///
  /// In en, this message translates to:
  /// **'Plasma'**
  String get colorMapPlasma;

  /// No description provided for @colorMapJet.
  ///
  /// In en, this message translates to:
  /// **'Jet'**
  String get colorMapJet;

  /// No description provided for @colorMapCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get colorMapCool;

  /// No description provided for @filterNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get filterNone;

  /// No description provided for @filterGaussian.
  ///
  /// In en, this message translates to:
  /// **'Gaussian'**
  String get filterGaussian;

  /// No description provided for @filterSharpen.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get filterSharpen;

  /// No description provided for @filterSobel.
  ///
  /// In en, this message translates to:
  /// **'Sobel'**
  String get filterSobel;

  /// No description provided for @filterEmboss.
  ///
  /// In en, this message translates to:
  /// **'Emboss'**
  String get filterEmboss;

  /// No description provided for @capture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get capture;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopRecording;

  /// No description provided for @captureSaved.
  ///
  /// In en, this message translates to:
  /// **'Snapshot saved'**
  String get captureSaved;

  /// No description provided for @recordingSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get recordingSaved;

  /// No description provided for @advancedRenderSettings.
  ///
  /// In en, this message translates to:
  /// **'Image settings'**
  String get advancedRenderSettings;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @localFiles.
  ///
  /// In en, this message translates to:
  /// **'Local: {count}'**
  String localFiles(Object count);

  /// No description provided for @localFileBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{photoCount} images · {videoCount} videos'**
  String localFileBreakdown(Object photoCount, Object videoCount);

  /// No description provided for @deviceFilesSection.
  ///
  /// In en, this message translates to:
  /// **'Device files'**
  String get deviceFilesSection;

  /// No description provided for @localRecordings.
  ///
  /// In en, this message translates to:
  /// **'Local recordings'**
  String get localRecordings;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @shareUir.
  ///
  /// In en, this message translates to:
  /// **'Save UIR'**
  String get shareUir;

  /// No description provided for @sharePng.
  ///
  /// In en, this message translates to:
  /// **'Save PNG'**
  String get sharePng;

  /// No description provided for @shareApng.
  ///
  /// In en, this message translates to:
  /// **'Save APNG'**
  String get shareApng;

  /// No description provided for @shareCsv.
  ///
  /// In en, this message translates to:
  /// **'Save CSV'**
  String get shareCsv;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @fileInformation.
  ///
  /// In en, this message translates to:
  /// **'File information'**
  String get fileInformation;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// No description provided for @fileFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get fileFormat;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @frames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get frames;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @temperatureRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Temperature range'**
  String get temperatureRangeLabel;

  /// No description provided for @averageTemperature.
  ///
  /// In en, this message translates to:
  /// **'Average temperature'**
  String get averageTemperature;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'File size'**
  String get fileSize;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAt;

  /// No description provided for @photoKind.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoKind;

  /// No description provided for @videoKind.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoKind;

  /// No description provided for @exportOptions.
  ///
  /// In en, this message translates to:
  /// **'Export options'**
  String get exportOptions;

  /// No description provided for @exportingApng.
  ///
  /// In en, this message translates to:
  /// **'Exporting APNG'**
  String get exportingApng;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @exportLog.
  ///
  /// In en, this message translates to:
  /// **'Export log'**
  String get exportLog;

  /// No description provided for @exportPhasePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get exportPhasePreparing;

  /// No description provided for @exportPhasePreparingText.
  ///
  /// In en, this message translates to:
  /// **'Preparing text'**
  String get exportPhasePreparingText;

  /// No description provided for @exportPhaseRenderingFrames.
  ///
  /// In en, this message translates to:
  /// **'Rendering frames'**
  String get exportPhaseRenderingFrames;

  /// No description provided for @exportPhaseEncodingApng.
  ///
  /// In en, this message translates to:
  /// **'Encoding APNG'**
  String get exportPhaseEncodingApng;

  /// No description provided for @exportPhaseSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get exportPhaseSaving;

  /// No description provided for @exportPhaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get exportPhaseComplete;

  /// No description provided for @exportPhaseCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling'**
  String get exportPhaseCancelling;

  /// No description provided for @exportPhaseCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get exportPhaseCancelled;

  /// No description provided for @exportMessageStartingApngExport.
  ///
  /// In en, this message translates to:
  /// **'Starting APNG export'**
  String get exportMessageStartingApngExport;

  /// No description provided for @exportMessageReadingUirFile.
  ///
  /// In en, this message translates to:
  /// **'Reading UIR file'**
  String get exportMessageReadingUirFile;

  /// No description provided for @exportMessageRenderingTextOverlays.
  ///
  /// In en, this message translates to:
  /// **'Rendering {count} text overlays'**
  String exportMessageRenderingTextOverlays(Object count);

  /// No description provided for @exportMessageRenderedTextOverlay.
  ///
  /// In en, this message translates to:
  /// **'Rendered text overlay {index}/{total}'**
  String exportMessageRenderedTextOverlay(Object index, Object total);

  /// No description provided for @exportMessageRenderingFrame.
  ///
  /// In en, this message translates to:
  /// **'Rendering frame {index}/{total}'**
  String exportMessageRenderingFrame(Object index, Object total);

  /// No description provided for @exportMessageRenderedFrame.
  ///
  /// In en, this message translates to:
  /// **'Rendered frame {index}/{total}'**
  String exportMessageRenderedFrame(Object index, Object total);

  /// No description provided for @exportMessageCompressingAnimatedPngFrames.
  ///
  /// In en, this message translates to:
  /// **'Compressing animated PNG frames'**
  String get exportMessageCompressingAnimatedPngFrames;

  /// No description provided for @exportMessageApngEncodingComplete.
  ///
  /// In en, this message translates to:
  /// **'APNG encoding complete'**
  String get exportMessageApngEncodingComplete;

  /// No description provided for @exportMessageWritingApngFile.
  ///
  /// In en, this message translates to:
  /// **'Writing APNG file'**
  String get exportMessageWritingApngFile;

  /// No description provided for @exportMessageApngFileSaved.
  ///
  /// In en, this message translates to:
  /// **'APNG file saved'**
  String get exportMessageApngFileSaved;

  /// No description provided for @exportMessageStoppingApngExport.
  ///
  /// In en, this message translates to:
  /// **'Stopping APNG export'**
  String get exportMessageStoppingApngExport;

  /// No description provided for @exportMessageExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get exportMessageExportCancelled;

  /// No description provided for @temperatureCurves.
  ///
  /// In en, this message translates to:
  /// **'Temperature curves'**
  String get temperatureCurves;

  /// No description provided for @includeLegend.
  ///
  /// In en, this message translates to:
  /// **'Show legend'**
  String get includeLegend;

  /// No description provided for @includeMeasurementPoints.
  ///
  /// In en, this message translates to:
  /// **'Show measurement points'**
  String get includeMeasurementPoints;

  /// No description provided for @previousFrame.
  ///
  /// In en, this message translates to:
  /// **'Previous frame'**
  String get previousFrame;

  /// No description provided for @nextFrame.
  ///
  /// In en, this message translates to:
  /// **'Next frame'**
  String get nextFrame;

  /// No description provided for @noReadableFrames.
  ///
  /// In en, this message translates to:
  /// **'No frames'**
  String get noReadableFrames;

  /// No description provided for @noReadableFramesMessage.
  ///
  /// In en, this message translates to:
  /// **'This UIR file does not contain readable frames.'**
  String get noReadableFramesMessage;

  /// No description provided for @noPointSamples.
  ///
  /// In en, this message translates to:
  /// **'No point samples'**
  String get noPointSamples;

  /// No description provided for @framesMetric.
  ///
  /// In en, this message translates to:
  /// **'{count} frames'**
  String framesMetric(Object count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

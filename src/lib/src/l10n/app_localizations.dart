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

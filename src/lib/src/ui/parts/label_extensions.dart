// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

extension ThermalColorMapLabel on ThermalColorMap {
  String label(AppLocalizations l10n) {
    return switch (this) {
      ThermalColorMap.ironbow => l10n.colorMapIronbow,
      ThermalColorMap.rainbow => l10n.colorMapRainbow,
      ThermalColorMap.grayscale => l10n.colorMapGrayscale,
      ThermalColorMap.blackHot => l10n.colorMapBlackHot,
      ThermalColorMap.hot => l10n.colorMapHot,
      ThermalColorMap.inferno => l10n.colorMapInferno,
      ThermalColorMap.plasma => l10n.colorMapPlasma,
      ThermalColorMap.jet => l10n.colorMapJet,
      ThermalColorMap.cool => l10n.colorMapCool,
    };
  }
}

extension ThermalFilterLabel on ThermalFilter {
  String label(AppLocalizations l10n) {
    return switch (this) {
      ThermalFilter.none => l10n.filterNone,
      ThermalFilter.gaussian => l10n.filterGaussian,
      ThermalFilter.sharpen => l10n.filterSharpen,
      ThermalFilter.sobel => l10n.filterSobel,
      ThermalFilter.emboss => l10n.filterEmboss,
    };
  }
}

extension AppLanguageLabel on AppLanguage {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AppLanguage.system => l10n.systemLanguage,
      AppLanguage.english => l10n.english,
      AppLanguage.chinese => l10n.chinese,
      AppLanguage.japanese => l10n.japanese,
    };
  }

  IconData get icon {
    return switch (this) {
      AppLanguage.system => Icons.language,
      AppLanguage.english => Icons.text_fields,
      AppLanguage.chinese => Icons.translate,
      AppLanguage.japanese => Icons.translate,
    };
  }
}

extension AppThemePreferenceLabel on AppThemePreference {
  String label(AppLocalizations l10n) {
    return switch (this) {
      AppThemePreference.system => l10n.systemTheme,
      AppThemePreference.light => l10n.lightTheme,
      AppThemePreference.dark => l10n.darkTheme,
    };
  }
}

extension TemperatureUnitLabel on TemperatureUnit {
  String label(AppLocalizations l10n) {
    return switch (this) {
      TemperatureUnit.celsius => l10n.temperatureUnitCelsius,
      TemperatureUnit.fahrenheit => l10n.temperatureUnitFahrenheit,
      TemperatureUnit.kelvin => l10n.temperatureUnitKelvin,
    };
  }
}

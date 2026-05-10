enum TemperatureUnit {
  celsius('celsius', 'C'),
  fahrenheit('fahrenheit', 'F'),
  kelvin('kelvin', 'K');

  const TemperatureUnit(this.code, this.csvSuffix);

  final String code;
  final String csvSuffix;

  static TemperatureUnit fromCode(String? code) {
    return TemperatureUnit.values.firstWhere(
      (unit) => unit.code == code,
      orElse: () => TemperatureUnit.celsius,
    );
  }

  double convertFromCelsius(double celsius) {
    return switch (this) {
      TemperatureUnit.celsius => celsius,
      TemperatureUnit.fahrenheit => celsius * 9 / 5 + 32,
      TemperatureUnit.kelvin => celsius + 273.15,
    };
  }

  String format(double celsius, {int digits = 1}) {
    final value = convertFromCelsius(celsius).toStringAsFixed(digits);
    return this == TemperatureUnit.kelvin ? '$value K' : '$value °$csvSuffix';
  }

  String formatRange(double minCelsius, double maxCelsius, {int digits = 1}) {
    final min = convertFromCelsius(minCelsius).toStringAsFixed(digits);
    final max = convertFromCelsius(maxCelsius).toStringAsFixed(digits);
    final suffix = this == TemperatureUnit.kelvin ? 'K' : '°$csvSuffix';
    return '$min-$max $suffix';
  }
}

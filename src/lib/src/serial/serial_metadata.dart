String? buildSerialPortDescription({
  String? description,
  String? manufacturer,
  String? productName,
  int? vendorId,
  int? productId,
  bool trustDescription = true,
}) {
  final cleanManufacturer = cleanSerialMetadata(manufacturer);
  final cleanProductName = cleanSerialMetadata(productName);
  final cleanDescription = cleanSerialMetadata(description);

  if (cleanManufacturer != null && cleanProductName != null) {
    if (cleanProductName.toLowerCase().contains(
      cleanManufacturer.toLowerCase(),
    )) {
      return cleanProductName;
    }
    return '$cleanManufacturer $cleanProductName';
  }
  if (cleanProductName != null) return cleanProductName;
  if (cleanManufacturer != null) return cleanManufacturer;
  if (trustDescription && cleanDescription != null) return cleanDescription;

  if (vendorId == 0x2e8a) return 'Raspberry Pi Pico / RP2040';
  if (vendorId != null || productId != null) {
    final parts = <String>[];
    if (vendorId != null) parts.add('VID:${_hex16(vendorId)}');
    if (productId != null) parts.add('PID:${_hex16(productId)}');
    return 'USB Serial Device (${parts.join(' ')})';
  }
  return null;
}

String? cleanSerialMetadata(String? value) {
  final normalized = value
      ?.replaceAll('\u0000', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (_containsInvalidDisplayCharacters(normalized)) return null;
  return normalized;
}

bool _containsInvalidDisplayCharacters(String value) {
  if (value.contains('\uFFFD')) return true;
  if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]').hasMatch(value)) {
    return true;
  }
  return false;
}

String _hex16(int value) {
  return value.toRadixString(16).padLeft(4, '0').toUpperCase();
}

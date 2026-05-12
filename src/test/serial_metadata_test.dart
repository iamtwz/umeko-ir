import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/serial/serial_metadata.dart';

void main() {
  test('buildSerialPortDescription prefers clean USB product identity', () {
    expect(
      buildSerialPortDescription(
        description: 'USB Serial Device',
        manufacturer: 'Raspberry Pi',
        productName: 'Pico',
        vendorId: 0x2e8a,
        productId: 0x000a,
      ),
      'Raspberry Pi Pico',
    );
  });

  test('buildSerialPortDescription ignores untrusted Windows descriptions', () {
    expect(
      buildSerialPortDescription(
        description:
            'USB \u00E4\u00B8\u00B2\u00E8\u00A1\u008C'
            '\u00E8\u00AE\u00BE\u00E5\u00A4\u0087',
        vendorId: 0x2e8a,
        productId: 0x000a,
        trustDescription: false,
      ),
      'Raspberry Pi Pico / RP2040',
    );
  });

  test('buildSerialPortDescription identifies CH340 fallback', () {
    expect(
      buildSerialPortDescription(
        description: 'USB Serial Device',
        vendorId: 0x1a86,
        productId: 0x7523,
        trustDescription: false,
      ),
      'CH340 USB Serial / ESP32',
    );
  });

  test('cleanSerialMetadata rejects replacement characters and controls', () {
    expect(cleanSerialMetadata('USB \uFFFD Device'), isNull);
    expect(cleanSerialMetadata('USB\u0087Device'), isNull);
  });

  test('buildSerialPortDescription falls back to VID PID', () {
    expect(
      buildSerialPortDescription(vendorId: 0x1234, productId: 0x00ab),
      'USB Serial Device (VID:1234 PID:00AB)',
    );
  });

  test('buildSerialPortDescription uses trusted descriptions last', () {
    expect(
      buildSerialPortDescription(description: 'USB Serial Device'),
      'USB Serial Device',
    );
    expect(
      buildSerialPortDescription(
        description: 'USB Serial Device',
        trustDescription: false,
      ),
      isNull,
    );
  });
}

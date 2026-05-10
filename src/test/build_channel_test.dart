import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/src/application/build_channel.dart';

void main() {
  test('defaults to release channel', () {
    expect(buildChannel, BuildChannel.release);
    expect(appDisplayName('Umeko IR'), 'Umeko IR');
    expect(appVersionLabel('1.0.5'), '1.0.5');
  });

  test('dev channel labels are visibly distinct', () {
    expect(buildChannelFromName('dev'), BuildChannel.dev);
    expect(
      appDisplayName('Umeko IR', channel: BuildChannel.dev),
      'Umeko IR Dev',
    );
    expect(appVersionLabel('1.0.5', channel: BuildChannel.dev), '1.0.5 (Dev)');
  });
}

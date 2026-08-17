import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/main.dart';
import 'package:umeko_ir_flutter/src/application/thermal_controller.dart';
import 'package:umeko_ir_flutter/src/l10n/app_localizations.dart';
import 'package:umeko_ir_flutter/src/serial/serial_adapter.dart';

void main() {
  testWidgets('alpha draft preserves alignment and shows confirmed flip', (
    tester,
  ) async {
    final serial = _DualVisionWidgetSerialAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DualVisionAlignmentPage(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DualVisionAlignmentPage)),
    );
    final controller = container.read(thermalControllerProvider.notifier);
    await controller.connect();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.text('12.50'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(2));
    expect(find.byType(SwitchListTile), findsNothing);

    final alphaSlider = tester.widget<Slider>(find.byType(Slider).first);
    alphaSlider.onChanged!(200);
    await tester.pump();

    expect(find.text('12.50'), findsOneWidget);
    tester
        .widget<OutlinedButton>(find.byType(OutlinedButton).first)
        .onPressed!();
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(find.byType(OutlinedButton).first)
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 30));

    final flip = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(flip.value, isTrue);
    expect(find.text('12.50'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    expect(
      container.read(thermalControllerProvider).dualVision.params?.tx,
      12.5,
    );
    expect(
      container.read(thermalControllerProvider).dualVision.params?.fusionAlpha,
      200,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unsupported capability card still opens for retry', (
    tester,
  ) async {
    final serial = _DualVisionWidgetSerialAdapter(respondToAlign: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [serialAdapterProvider.overrideWithValue(serial)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevicePane(),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DevicePane)),
    );
    final controller = container.read(thermalControllerProvider.notifier);
    await controller.connect();
    await controller.stopStream();
    final probe = controller.probeDualVision();
    await tester.pump(const Duration(milliseconds: 1600));
    await probe;
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('This device does not support this capability'), findsOne);
    await tester.tap(find.text('Dual-vision alignment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byType(DualVisionAlignmentPage), findsOneWidget);
    expect(find.byTooltip('Read from device'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _DualVisionWidgetSerialAdapter implements SerialAdapter {
  _DualVisionWidgetSerialAdapter({this.respondToAlign = true});

  final bool respondToAlign;
  final _input = StreamController<Uint8List>.broadcast();
  final _port = const SerialPortDescriptor(
    id: '/dev/cu.usbmodem-dual-vision',
    label: 'ESP32 dual vision',
    vendorId: 0x1a86,
  );

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  Future<List<SerialPortDescriptor>> listPorts() async => [_port];

  @override
  Future<void> connect(
    SerialPortDescriptor port,
    SerialOptions options,
  ) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> write(Uint8List data) async {
    final command = utf8.decode(data, allowMalformed: true).trim();
    if (command == 'get_align' && respondToAlign) {
      _emit('ALIGN 12.50 -4.00 1.100 1.200 -15.00 128\n');
    } else if (command == 'toggle_vflip') {
      _emit('VFLIP:1\n');
    }
  }

  void _emit(String text) {
    _input.add(Uint8List.fromList(utf8.encode(text)));
  }
}

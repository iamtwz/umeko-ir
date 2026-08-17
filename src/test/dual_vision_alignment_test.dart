import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umeko_ir_flutter/main.dart';
import 'package:umeko_ir_flutter/src/application/thermal_controller.dart';
import 'package:umeko_ir_flutter/src/core/dual_vision.dart';
import 'package:umeko_ir_flutter/src/l10n/app_localizations.dart';
import 'package:umeko_ir_flutter/src/serial/serial_adapter.dart';

void main() {
  testWidgets('alpha draft preserves alignment and shows confirmed flip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    expect(find.textContaining('X 12.5'), findsWidgets);
    expect(find.text('Saved'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('dual-vision-camera-orientation')),
    );
    await tester.tap(
      find.byKey(const ValueKey('dual-vision-camera-orientation')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(SwitchListTile), findsNWidgets(2));

    final alphaSlider = tester.widget<Slider>(find.byType(Slider).first);
    alphaSlider.onChanged!(80);
    await tester.pump();

    expect(find.textContaining('X 12.5'), findsWidgets);
    expect(find.text('Syncing…'), findsOneWidget);
    tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).onChanged!(
      true,
    );
    await tester.pump();
    expect(
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).first)
          .onChanged,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 30));

    final flip = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(flip.value, isTrue);
    expect(find.textContaining('X 12.5'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 150));
    expect(
      container.read(thermalControllerProvider).dualVision.params?.tx,
      12.5,
    );
    expect(
      container.read(thermalControllerProvider).dualVision.params?.fusionAlpha,
      204,
    );
    expect(find.text('Saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reset requires confirmation and restores firmware defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DualVisionAlignmentPage)),
    );
    await container.read(thermalControllerProvider.notifier).connect();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 30));

    await tester.tap(find.byTooltip('Reset alignment and alpha'));
    await tester.pumpAndSettle();
    expect(find.text('Reset alignment?'), findsOneWidget);
    expect(serial.commands.where((value) => value.startsWith('set_')), isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(serial.commands.where((value) => value.startsWith('set_')), isEmpty);

    await tester.tap(find.byTooltip('Reset alignment and alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      serial.commands,
      containsAllInOrder([
        'set_align 0.00 0.00 1.000 1.000 -0.00',
        'set_alpha 128',
      ]),
    );
    expect(
      container.read(thermalControllerProvider).dualVision.params,
      AlignParams.defaults,
    );
    expect(find.text('Saved'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact layout exposes a draggable calibration control sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DualVisionAlignmentPage)),
    );
    await container.read(thermalControllerProvider.notifier).connect();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pump(const Duration(milliseconds: 30));

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Calibration controls'), findsOneWidget);
    expect(find.text('Fusion alpha'), findsOneWidget);
    expect(find.text('Alignment'), findsOneWidget);
    final canvasBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('dual-vision-canvas')))
        .dy;
    final sheetTop = tester
        .getTopLeft(find.byKey(const ValueKey('dual-vision-control-sheet')))
        .dy;
    expect(sheetTop - canvasBottom, inInclusiveRange(0, 24));
    expect(tester.takeException(), isNull);

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
  final List<String> commands = [];
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
    commands.add(command);
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

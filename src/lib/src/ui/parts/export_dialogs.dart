// GENERATED: extracted from main.dart during main-split refactor.
// Kept as a 'part of' to preserve privacy of underscore-prefixed members
// without promoting them across library boundaries.
part of '../../../main.dart';

enum _GalleryMenuAction { export, fileInfo }

enum _LocalExportFormat { png, apng, uir }

const _defaultExportScale = 32;
const _exportScaleOptions = [4, 8, 16, 24, 32, 48, 64];

class _LocalExportRequest {
  const _LocalExportRequest({required this.format, this.options});

  final _LocalExportFormat format;
  final _LocalExportOptions? options;
}

class _LocalExportOptions {
  const _LocalExportOptions({
    required this.includeLegend,
    required this.includePoints,
    required this.settings,
    required this.exportScale,
  });

  final bool includeLegend;
  final bool includePoints;
  final RenderSettings settings;
  final int exportScale;
}

Future<_LocalExportRequest?> _showLocalExportDialog(
  BuildContext context,
  RenderSettings initialSettings, {
  required int sourceWidth,
  required int sourceHeight,
  required bool supportsApng,
}) {
  var format = _LocalExportFormat.png;
  var includeLegend = true;
  var includePoints = true;
  var settings = initialSettings;
  var exportScale = _defaultExportScale;
  final l10n = context.l10n;
  final formats = [
    _LocalExportFormat.png,
    if (supportsApng) _LocalExportFormat.apng,
    _LocalExportFormat.uir,
  ];
  return showDialog<_LocalExportRequest>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final needsRenderOptions = format != _LocalExportFormat.uir;
          return AlertDialog(
            title: Text(l10n.export),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<_LocalExportFormat>(
                      initialValue: format,
                      decoration: InputDecoration(labelText: l10n.fileFormat),
                      items: [
                        for (final value in formats)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_localExportFormatLabel(l10n, value)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => format = value);
                      },
                    ),
                    if (needsRenderOptions) ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeLegend,
                        title: Text(l10n.includeLegend),
                        onChanged: (value) {
                          setState(
                            () => includeLegend = value ?? includeLegend,
                          );
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includePoints,
                        title: Text(l10n.includeMeasurementPoints),
                        onChanged: (value) {
                          setState(
                            () => includePoints = value ?? includePoints,
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _ExportRenderSettingsFields(
                        settings: settings,
                        sourceWidth: sourceWidth,
                        sourceHeight: sourceHeight,
                        exportScale: exportScale,
                        onScaleChanged: (value) {
                          setState(() => exportScale = value);
                        },
                        onChanged: (value) => setState(() => settings = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _LocalExportRequest(
                    format: format,
                    options: needsRenderOptions
                        ? _LocalExportOptions(
                            includeLegend: includeLegend,
                            includePoints: includePoints,
                            settings: settings,
                            exportScale: exportScale,
                          )
                        : null,
                  ),
                ),
                child: Text(l10n.export),
              ),
            ],
          );
        },
      );
    },
  );
}

String _localExportFormatLabel(
  AppLocalizations l10n,
  _LocalExportFormat format,
) {
  return switch (format) {
    _LocalExportFormat.png => l10n.sharePng,
    _LocalExportFormat.apng => l10n.shareApng,
    _LocalExportFormat.uir => l10n.shareUir,
  };
}

String _exportScaleLabel(
  int scale,
  int sourceWidth,
  int sourceHeight,
  RenderSettings settings,
) {
  final size = displayOrientedSize(
    sourceWidth,
    sourceHeight,
    settings.rotation,
  );
  return '${scale}x (${size.width * scale}x${size.height * scale}px)';
}

Future<_LocalExportOptions?> _showPngExportOptions(
  BuildContext context,
  RenderSettings initialSettings, {
  required int sourceWidth,
  required int sourceHeight,
}) {
  var includeLegend = true;
  var includePoints = true;
  var settings = initialSettings;
  var exportScale = _defaultExportScale;
  final l10n = context.l10n;
  return showDialog<_LocalExportOptions>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(l10n.exportOptions),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeLegend,
                      title: Text(l10n.includeLegend),
                      onChanged: (value) {
                        setState(() => includeLegend = value ?? includeLegend);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includePoints,
                      title: Text(l10n.includeMeasurementPoints),
                      onChanged: (value) {
                        setState(() => includePoints = value ?? includePoints);
                      },
                    ),
                    const Divider(height: 24),
                    _ExportRenderSettingsFields(
                      settings: settings,
                      sourceWidth: sourceWidth,
                      sourceHeight: sourceHeight,
                      exportScale: exportScale,
                      onScaleChanged: (value) {
                        setState(() => exportScale = value);
                      },
                      onChanged: (value) => setState(() => settings = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _LocalExportOptions(
                    includeLegend: includeLegend,
                    includePoints: includePoints,
                    settings: settings,
                    exportScale: exportScale,
                  ),
                ),
                child: Text(l10n.sharePng),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ExportRenderSettingsFields extends StatelessWidget {
  const _ExportRenderSettingsFields({
    required this.settings,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.exportScale,
    required this.onScaleChanged,
    required this.onChanged,
  });

  final RenderSettings settings;
  final int sourceWidth;
  final int sourceHeight;
  final int exportScale;
  final ValueChanged<int> onScaleChanged;
  final ValueChanged<RenderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<int>(
          initialValue: exportScale,
          decoration: InputDecoration(labelText: l10n.resolution),
          items: [
            for (final value in _exportScaleOptions)
              DropdownMenuItem(
                value: value,
                child: Text(
                  _exportScaleLabel(value, sourceWidth, sourceHeight, settings),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onScaleChanged(value);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ThermalColorMap>(
          initialValue: settings.colorMap,
          decoration: InputDecoration(labelText: l10n.colorMap),
          items: [
            for (final value in ThermalColorMap.values)
              DropdownMenuItem(value: value, child: Text(value.label(l10n))),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(settings.copyWith(colorMap: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ThermalFilter>(
          initialValue: settings.filter,
          decoration: InputDecoration(labelText: l10n.filter),
          items: [
            for (final value in ThermalFilter.values)
              DropdownMenuItem(value: value, child: Text(value.label(l10n))),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(settings.copyWith(filter: value));
          },
        ),
        const SizedBox(height: 10),
        _CompactSwitchRow(
          value: settings.upscaleEnabled,
          label: l10n.bilinear,
          onChanged: (value) =>
              onChanged(settings.copyWith(upscaleEnabled: value)),
        ),
        _ExportAdvancedRenderSettings(
          settings: settings,
          label: l10n.advancedRenderSettings,
          horizontalFlipLabel: l10n.horizontalFlip,
          verticalFlipLabel: l10n.verticalFlip,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

Future<void> _shareApngWithProgress(
  BuildContext context,
  ThermalExporter exporter,
  GalleryEntry entry,
  _LocalExportOptions options,
  TemperatureUnit temperatureUnit,
) async {
  final l10n = context.l10n;
  final labels = _apngExportLabels(l10n);
  var progress = 0.0;
  var phase = labels.preparing;
  var message = l10n.exportMessageStartingApngExport;
  final logs = <String>['${labels.preparing}: $message'];
  final logScrollController = ScrollController();
  final closeCompleter = Completer<void>();
  StateSetter? updateDialog;
  NavigatorState? dialogNavigator;
  var dialogVisible = false;
  var cancelRequested = false;
  var isCancelling = false;
  var isComplete = false;
  var logsExpanded = false;

  void scrollLogsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!logsExpanded || !logScrollController.hasClients) return;
      logScrollController.animateTo(
        logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void addLog(String line) {
    if (logs.isNotEmpty && logs.last == line) return;
    logs.add(line);
    if (logs.length > 80) logs.removeAt(0);
    scrollLogsToEnd();
  }

  void showProgressDialog() {
    if (dialogVisible || !context.mounted) return;
    dialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogNavigator = Navigator.of(context, rootNavigator: true);
          return StatefulBuilder(
            builder: (context, setState) {
              updateDialog = setState;
              return AlertDialog(
                title: Text(context.l10n.exportingApng),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              phase,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text('${(progress * 100).clamp(0, 100).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 16),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          setState(() {
                            logsExpanded = !logsExpanded;
                          });
                          if (logsExpanded) scrollLogsToEnd();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                logsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.exportLog,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (logsExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SingleChildScrollView(
                            controller: logScrollController,
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final log in logs)
                                  Text(
                                    log,
                                    style: const TextStyle(
                                      fontFamily: 'Menlo',
                                      fontFamilyFallback: [
                                        'SF Mono',
                                        'Monaco',
                                        'Courier New',
                                        'Courier',
                                      ],
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isCancelling
                        ? null
                        : () {
                            if (isComplete) {
                              if (!closeCompleter.isCompleted) {
                                closeCompleter.complete();
                              }
                              Navigator.of(context, rootNavigator: true).pop();
                              return;
                            }
                            setState(() {
                              cancelRequested = true;
                              isCancelling = true;
                              phase = l10n.exportPhaseCancelling;
                              message = l10n.exportMessageStoppingApngExport;
                              addLog('$phase: $message');
                            });
                          },
                    child: Text(isComplete ? l10n.done : l10n.cancel),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        if (!closeCompleter.isCompleted) closeCompleter.complete();
      }),
    );
  }

  try {
    await exporter.shareApng(
      entry,
      options.settings,
      temperatureUnit: temperatureUnit,
      includePoints: options.includePoints,
      includeLegend: options.includeLegend,
      exportScale: options.exportScale,
      shouldCancel: () => cancelRequested,
      onProgress: (event) {
        showProgressDialog();
        final localizedPhase = _localizeApngProgressText(event.phase, l10n);
        final localizedMessage = _localizeApngProgressText(event.message, l10n);
        updateDialog?.call(() {
          progress = event.value.clamp(0.0, 1.0);
          phase = localizedPhase;
          message = localizedMessage;
          addLog('$localizedPhase: $localizedMessage');
        });
      },
      labels: labels,
    );
    if (dialogVisible) {
      updateDialog?.call(() {
        progress = 1;
        phase = labels.complete;
        message = labels.apngFileSaved;
        isComplete = true;
        isCancelling = false;
        addLog('$phase: $message');
      });
      await closeCompleter.future;
    }
  } on ThermalExportCancelled {
    if (dialogVisible) {
      updateDialog?.call(() {
        phase = l10n.exportPhaseCancelled;
        message = l10n.exportMessageExportCancelled;
        isComplete = true;
        isCancelling = false;
        addLog('$phase: $message');
      });
      await closeCompleter.future;
    }
  } catch (_) {
    if (dialogVisible && dialogNavigator?.canPop() == true) {
      dialogNavigator?.pop();
    }
    rethrow;
  } finally {
    logScrollController.dispose();
  }
}

ThermalApngExportLabels _apngExportLabels(AppLocalizations l10n) {
  return ThermalApngExportLabels(
    preparing: l10n.exportPhasePreparing,
    preparingText: l10n.exportPhasePreparingText,
    renderingFrames: l10n.exportPhaseRenderingFrames,
    encodingApng: l10n.exportPhaseEncodingApng,
    saving: l10n.exportPhaseSaving,
    complete: l10n.exportPhaseComplete,
    readingUirFile: l10n.exportMessageReadingUirFile,
    renderingTextOverlays: _countTemplate(
      l10n.exportMessageRenderingTextOverlays,
    ),
    renderedTextOverlay: _indexTotalTemplate(
      l10n.exportMessageRenderedTextOverlay,
    ),
    renderingFrame: _indexTotalTemplate(l10n.exportMessageRenderingFrame),
    renderedFrame: _indexTotalTemplate(l10n.exportMessageRenderedFrame),
    compressingAnimatedPngFrames:
        l10n.exportMessageCompressingAnimatedPngFrames,
    apngEncodingComplete: l10n.exportMessageApngEncodingComplete,
    writingApngFile: l10n.exportMessageWritingApngFile,
    apngFileSaved: l10n.exportMessageApngFileSaved,
  );
}

String _localizeApngProgressText(String value, AppLocalizations l10n) {
  return switch (value) {
    'Preparing' => l10n.exportPhasePreparing,
    'Preparing text' => l10n.exportPhasePreparingText,
    'Rendering frames' => l10n.exportPhaseRenderingFrames,
    'Encoding APNG' => l10n.exportPhaseEncodingApng,
    'Saving' => l10n.exportPhaseSaving,
    'Complete' => l10n.exportPhaseComplete,
    'Reading UIR file' => l10n.exportMessageReadingUirFile,
    'Compressing animated PNG frames' =>
      l10n.exportMessageCompressingAnimatedPngFrames,
    'APNG encoding complete' => l10n.exportMessageApngEncodingComplete,
    'Writing APNG file' => l10n.exportMessageWritingApngFile,
    'APNG file saved' => l10n.exportMessageApngFileSaved,
    _ => value,
  };
}

String _countTemplate(String Function(Object count) formatter) {
  const countToken = '__COUNT__';
  return formatter(countToken).replaceAll(countToken, '{count}');
}

String _indexTotalTemplate(
  String Function(Object index, Object total) formatter,
) {
  const indexToken = '__INDEX__';
  const totalToken = '__TOTAL__';
  return formatter(
    indexToken,
    totalToken,
  ).replaceAll(indexToken, '{index}').replaceAll(totalToken, '{total}');
}

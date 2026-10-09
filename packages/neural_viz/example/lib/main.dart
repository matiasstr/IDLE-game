import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:neural_viz/neural_viz.dart';

/// The engine's stages (kept here so the example doesn't depend on core).
const stages = <(String, List<int>)>[
  ('perceptron', [3, 1]),
  ('mlp', [3, 5, 2]),
  ('cnn', [6, 8, 6, 3]),
  ('rnn', [4, 7, 7, 4]),
  ('transformer', [6, 8, 8, 8, 6]),
  ('llm', [8, 10, 10, 10, 8]),
  ('multimodal', [8, 10, 12, 10, 8]),
  ('agi', [10, 12, 14, 12, 10]),
];

NetworkTopology topologyOf(int stage) =>
    NetworkTopology.fromId(stages[stage].$1, stages[stage].$2);

void main() {
  final query = Uri.base.queryParameters;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF07090D),
      ),
      home: query.containsKey('t')
          ? CapturePage(config: CaptureConfig.fromQuery(query))
          : const GalleryPage(),
    ),
  );
}

/// Every stage, live.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 2 : 1,
        childAspectRatio: 720 / 440,
        padding: const EdgeInsets.all(12),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (var i = 0; i < stages.length; i++)
            NeuralNetworkView(
              topology: topologyOf(i),
              stage: i,
              nextTopology: i + 1 < stages.length ? topologyOf(i + 1) : null,
              productionPerSecond: 0.5 * _pow10(i * 1.6),
              trainingCount: _taps,
              progress: 0.5,
              accuracy: 0.3 + 0.09 * i,
              onTrain: () => setState(() => _taps++),
            ),
        ],
      ),
    );
  }
}

double _pow10(double x) {
  var v = 1.0;
  for (var i = 0; i < x.floor(); i++) {
    v *= 10;
  }
  return v;
}

/// Deterministic still for screenshots:
/// `?stage=4&t=3.4&w=720&h=440&prod=1e7&acc=0.93&progress=0.9`
/// plus optional `taps=3.15,3.2` and `from=3&switchAt=1.0`.
class CaptureConfig {
  CaptureConfig.fromQuery(Map<String, String> q)
    : stage = int.tryParse(q['stage'] ?? '') ?? 0,
      t = double.tryParse(q['t'] ?? '') ?? 3,
      width = double.tryParse(q['w'] ?? '') ?? 720,
      height = double.tryParse(q['h'] ?? '') ?? 440,
      production = double.tryParse(q['prod'] ?? '') ?? 100,
      accuracy = double.tryParse(q['acc'] ?? '') ?? 0.5,
      progress = double.tryParse(q['progress'] ?? '') ?? 0.3,
      taps = [
        for (final s in (q['taps'] ?? '').split(','))
          if (double.tryParse(s) != null) double.parse(s),
      ],
      from = int.tryParse(q['from'] ?? ''),
      switchAt = double.tryParse(q['switchAt'] ?? '') ?? 0.5,
      quality = VizQuality.values.asNameMap()[q['quality']] ?? VizQuality.high,
      reducedMotion = q['motion'] == 'reduced';

  final int stage;
  final double t, width, height, production, accuracy, progress, switchAt;
  final List<double> taps;
  final int? from;
  final VizQuality quality;
  final bool reducedMotion;
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.config});

  final CaptureConfig config;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  late final ValueNotifier<Duration> _clock;
  late int _stage;
  int _taps = 0;

  /// (time, action) steps applied one frame apart.
  late final List<(double, VoidCallback)> _script;

  CaptureConfig get c => widget.config;

  @override
  void initState() {
    super.initState();
    _stage = c.from ?? c.stage;
    _clock = ValueNotifier(Duration.zero);
    _script = [
      if (c.from != null) (c.switchAt, () => _stage = c.stage),
      for (final tap in c.taps) (tap, () => _taps++),
      (c.t, () {}),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    SchedulerBinding.instance.addPostFrameCallback((_) => _step(0));
  }

  void _step(int i) {
    if (i >= _script.length) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        globalContext.setProperty('__vizReady'.toJS, true.toJS);
      });
      return;
    }
    final (at, action) = _script[i];
    _clock.value = Duration(microseconds: (at * 1e6).round());
    setState(action);
    SchedulerBinding.instance.addPostFrameCallback((_) => _step(i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final view = NeuralNetworkView(
      topology: topologyOf(_stage),
      stage: _stage,
      nextTopology: _stage + 1 < stages.length ? topologyOf(_stage + 1) : null,
      productionPerSecond: c.production,
      trainingCount: _taps,
      progress: c.progress,
      accuracy: c.accuracy,
      clock: _clock,
      quality: c.quality,
    );
    return Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: c.width,
          height: c.height,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: c.reducedMotion),
            child: view,
          ),
        ),
      ),
    );
  }
}

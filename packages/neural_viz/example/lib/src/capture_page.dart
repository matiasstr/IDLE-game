import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:neural_viz/neural_viz.dart';

import 'design.dart';
import 'platform/web_bridge.dart';
import 'stages.dart';

/// Deterministic still for screenshots. Any `t=` parameter selects it:
///
/// `?stage=4&t=3.4&w=720&h=440&prod=1e7&acc=0.93&progress=0.9`
///
/// plus optional `taps=3.15,3.2` (tap times), `from=3&switchAt=1.0` (start at
/// stage 3 and switch to `stage` at 1.0 s), `quality=high|medium|low|auto`,
/// `motion=reduced`, `contrast=high` and `loss=1` (a 320 × 96 LossChart with a
/// synthetic run directly under the frame).
///
/// The screenshot scripts depend on this contract: no chrome, the frame at the
/// top left, and `window.__vizReady = true` once the frame at `t` is painted.
class CaptureConfig {
  CaptureConfig.fromQuery(Map<String, String> q)
    : stage = (int.tryParse(q['stage'] ?? '') ?? 0).clamp(0, lastStage),
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
      from = int.tryParse(q['from'] ?? '')?.clamp(0, lastStage),
      switchAt = double.tryParse(q['switchAt'] ?? '') ?? 0.5,
      quality = VizQuality.values.asNameMap()[q['quality']] ?? VizQuality.high,
      reducedMotion = q['motion'] == 'reduced',
      highContrast = q['contrast'] == 'high',
      showLoss = q['loss'] == '1';

  final int stage;
  final double t, width, height, production, accuracy, progress, switchAt;
  final List<double> taps;
  final int? from;
  final VizQuality quality;
  final bool reducedMotion;
  final bool highContrast;
  final bool showLoss;
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.config});

  final CaptureConfig config;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  late final ValueNotifier<Duration> _clock;
  late final LossHistory? _loss;
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
    _loss = c.showLoss
        ? syntheticLossHistory(
            stage: c.stage,
            progress: c.progress,
            accuracy: c.accuracy,
          )
        : null;
    _script = [
      if (c.from != null) (c.switchAt, () => _stage = c.stage),
      for (final tap in c.taps) (tap, () => _taps++),
      (c.t, () {}),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    SchedulerBinding.instance.addPostFrameCallback((_) => _step(0));
  }

  @override
  void dispose() {
    _clock.dispose();
    _loss?.dispose();
    super.dispose();
  }

  void _step(int i) {
    if (i >= _script.length) {
      // The last step's frame is on screen; report after one more frame so
      // the raster of that frame has landed.
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => markCaptureReady())
        ..scheduleFrame();
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
      topology: stages[_stage].topology,
      stage: _stage,
      nextTopology: nextTopologyOf(_stage),
      productionPerSecond: c.production,
      trainingCount: _taps,
      progress: c.progress,
      accuracy: c.accuracy,
      clock: _clock,
      quality: c.quality,
    );
    final loss = _loss;
    return Scaffold(
      backgroundColor: Palette.background,
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: c.reducedMotion,
          highContrast: c.highContrast,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: c.width, height: c.height, child: view),
            ),
            if (loss != null)
              Positioned(
                left: 0,
                top: c.height,
                width: 320,
                height: 96,
                child: LossChart(history: loss),
              ),
          ],
        ),
      ),
    );
  }
}

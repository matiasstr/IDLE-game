/// Renders LossChart PNGs (on a card, at 2x, with JetBrains Mono) for visual
/// review. Skipped unless LOSS_CHART_SHOTS names an output directory:
///
///     LOSS_CHART_SHOTS=/tmp/loss flutter test \
///         test/loss/loss_chart_screenshots_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';

final String? _outDir = Platform.environment['LOSS_CHART_SHOTS'];

const _stages = <(double, String)>[
  (0.5, 'MLP'),
  (0.25, 'CNN'),
  (0.13, 'RNN'),
  (0.072, 'Transformer'),
  (0.040, 'LLM'),
  (0.022, 'Multimodal'),
  (0.012, 'AGI'),
];

/// Engine-like run: accuracy = 1 − 0.9·e^(−log10(tokens+1)/3), with
/// log10(tokens) reaching 15 after [runSeconds].
LossHistory simulate(
  int seconds, {
  double noise = 0.04,
  int runSeconds = 5400,
}) {
  final h = LossHistory(noise: noise, seed: 7);
  var next = 0;
  for (var t = 0; t < seconds; t++) {
    final log10Tokens = 15 * math.pow(t / runSeconds, 0.75);
    final acc = 1 - 0.9 * math.exp(-log10Tokens / 3);
    final loss = -math.log(acc);
    if (next < _stages.length && loss <= _stages[next].$1) {
      h.mark(_stages[next].$2);
      next++;
    }
    h.add(loss);
  }
  return h;
}

Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget chart, {
  double width = 320,
  double height = 96,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF0D1117),
              padding: const EdgeInsets.all(14),
              child: SizedBox(width: width, height: height, child: chart),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$_outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_outDir == null) return;
    Directory(_outDir!).createSync(recursive: true);
    final font = File('example/assets/fonts/JetBrainsMono-Medium.ttf');
    final loader = FontLoader('JetBrains Mono')
      ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
    await loader.load();
  });

  testWidgets('renders review PNGs', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await shoot(tester, 'empty', LossChart(history: LossHistory()));
    final one = LossHistory()..add(2.30);
    await shoot(tester, 'one', LossChart(history: one));
    final early = simulate(40);
    await shoot(tester, 'early', LossChart(history: early));
    final run = simulate(5400);
    await shoot(tester, 'run', LossChart(history: run));
    await shoot(
      tester,
      'run_noisy',
      LossChart(history: simulate(5400, noise: 0.15)),
    );
    await shoot(
      tester,
      'run_240x72',
      LossChart(history: run),
      width: 240,
      height: 72,
    );
    await shoot(
      tester,
      'run_360x120',
      LossChart(history: run),
      width: 360,
      height: 120,
    );
    await shoot(
      tester,
      'compact',
      LossChart(history: run),
      width: 280,
      height: 44,
    );
    await shoot(tester, 'mid', LossChart(history: simulate(1200)));
    await shoot(
      tester,
      'noaxis',
      LossChart(history: run, showAxis: false, showReadout: false),
    );
    await shoot(tester, 'raw', LossChart(history: run, smoothing: 0));
    // CNN reached 6 s ago (at 994 s): its label flips left of the hairline.
    await shoot(tester, 'just_marked', LossChart(history: simulate(1000)));
    await shoot(
      tester,
      'early_noisy',
      LossChart(history: simulate(200, noise: 0.15)),
    );
    await shoot(
      tester,
      'narrow',
      LossChart(history: run),
      width: 180,
      height: 80,
    );
    await shoot(
      tester,
      'compact_empty',
      LossChart(history: LossHistory()),
      width: 280,
      height: 44,
    );
  }, skip: _outDir == null);
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/loss/loss_chart.dart'
    show debiasedEma, formatLoss, lossDeltaPercent;

/// TensorBoard's smoothing, written the straightforward way.
List<double> referenceEma(List<double> values, double weight) {
  final out = <double>[];
  var last = 0.0;
  var count = 0;
  for (final y in values) {
    last = last * weight + (1 - weight) * y;
    count++;
    final debias = weight == 0 ? 1.0 : 1 - math.pow(weight, count);
    out.add(last / debias);
  }
  return out;
}

double engineLoss(int i) {
  final log10Tokens = 15 * math.pow(i / 4000, 0.75);
  return -math.log(1 - 0.9 * math.exp(-log10Tokens / 3));
}

LossHistory run(int samples, {List<int> marks = const []}) {
  final h = LossHistory(seed: 1);
  for (var i = 0; i < samples; i++) {
    if (marks.contains(i)) h.mark('stage $i');
    h.add(engineLoss(i));
  }
  return h;
}

Widget host(Widget chart, {double width = 320, double height = 96}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, height: height, child: chart),
      ),
    );

void main() {
  group('debiasedEma', () {
    test('matches the TensorBoard reference', () {
      final rng = math.Random(4);
      for (final weight in [0.0, 0.3, 0.6, 0.9, 0.99]) {
        final h = LossHistory(noise: 0.3, seed: 2);
        final raw = <double>[];
        for (var i = 0; i < 200; i++) {
          h.add(engineLoss(i) * (0.5 + rng.nextDouble()));
          raw.add(h[i]);
        }
        final out = Float64List(h.capacity);
        debiasedEma(h, weight, out);
        final expected = referenceEma(raw, weight);
        for (var i = 0; i < raw.length; i++) {
          expect(
            out[i],
            closeTo(expected[i], 1e-12 * expected[i]),
            reason: 'w $weight, i $i',
          );
        }
      }
    });

    test('is not pulled toward zero at the start', () {
      final h = LossHistory(noise: 0)
        ..add(2.3)
        ..add(2.3)
        ..add(2.3);
      final out = Float64List(h.capacity);
      debiasedEma(h, 0.6, out);
      expect(out[0], closeTo(2.3, 1e-12));
      expect(out[1], closeTo(2.3, 1e-12));
      expect(out[2], closeTo(2.3, 1e-12));
    });

    test('smoothing 0 returns the raw values', () {
      final h = run(50);
      final out = Float64List(h.capacity);
      debiasedEma(h, 0, out);
      for (var i = 0; i < h.length; i++) {
        expect(out[i], h[i]);
      }
    });
  });

  group('formatting', () {
    test('two decimals from 1, three significant digits below', () {
      expect(formatLoss(math.ln10), '2.30');
      expect(formatLoss(1), '1.00');
      expect(formatLoss(12.345), '12.35');
      expect(formatLoss(0.5), '0.500');
      expect(formatLoss(0.25), '0.250');
      expect(formatLoss(0.0421), '0.0421');
      expect(formatLoss(0.00609), '0.00609');
    });

    test('delta is the drop in percent', () {
      expect(lossDeltaPercent(2.3, 0.0414).toStringAsFixed(1), '98.2');
      expect(lossDeltaPercent(2, 2), 0);
      expect(lossDeltaPercent(1, 1.5), -50);
    });
  });

  group('LossChart', () {
    testWidgets('empty: guides, baseline and no value', (tester) async {
      final h = LossHistory();
      await tester.pumpWidget(host(LossChart(history: h)));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        tester.getSemantics(find.byType(LossChart)),
        isSemantics(label: 'loss'),
      );
    });

    testWidgets('one point still shows the empty state', (tester) async {
      final h = LossHistory()..add(2.3);
      await tester.pumpWidget(
        host(LossChart(history: h, semanticLabel: 'Training loss')),
      );
      expect(tester.takeException(), isNull);
      final node = tester.getSemantics(find.byType(LossChart));
      expect(node.label, 'Training loss');
      expect(node.value, isEmpty);
    });

    testWidgets('200 points with markers', (tester) async {
      final h = run(200, marks: [40, 90, 150, 199]);
      expect(h.markers, hasLength(4));
      await tester.pumpWidget(
        host(LossChart(history: h, semanticLabel: 'Training loss')),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(LossChart)),
        isSemantics(label: 'Training loss', value: formatLoss(h.latest!)),
      );
    });

    testWidgets('a long, decimated run in a narrow chart', (tester) async {
      // More points than pixel columns: the raw trace is bucketed.
      final h = run(6000, marks: [100, 600, 1500, 3000, 5000]);
      for (final size in [const Size(120, 80), const Size(240, 72)]) {
        await tester.pumpWidget(
          host(
            LossChart(history: h),
            width: size.width,
            height: size.height,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('compact mode and option combinations', (tester) async {
      final h = run(300, marks: [100]);
      for (final height in [24.0, 40.0, 63.0, 64.0, 120.0]) {
        for (final axis in [true, false]) {
          for (final readout in [true, false]) {
            await tester.pumpWidget(
              host(
                LossChart(
                  history: h,
                  showAxis: axis,
                  showReadout: readout,
                  smoothing: readout ? 0.6 : 0,
                ),
                height: height,
              ),
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    });

    testWidgets('tiny and zero sizes do not throw', (tester) async {
      final h = run(50);
      for (final size in [Size.zero, const Size(4, 4), const Size(30, 10)]) {
        await tester.pumpWidget(
          host(
            LossChart(history: h),
            width: size.width,
            height: size.height,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('unbounded constraints fall back to 320 × 96', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UnconstrainedBox(child: LossChart(history: run(10))),
        ),
      );
      expect(tester.getSize(find.byType(LossChart)), const Size(320, 96));
    });

    testWidgets('repaints on every sample, so the readout stays live', (
      tester,
    ) async {
      final h = LossHistory(capacity: 16);
      for (var i = 0; i < 16; i++) {
        h.add(engineLoss(i));
      }
      expect(h.samplesPerPoint, 2);
      await tester.pumpWidget(
        host(LossChart(history: h, semanticLabel: 'Training loss')),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);

      h.add(0.5); // pending, but the readout shows it
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(LossChart)),
        isSemantics(label: 'Training loss', value: '0.500'),
      );
      h.mark('CNN');
      expect(tester.binding.hasScheduledFrame, isFalse);

      h.add(0.4); // commits
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(
        tester.getSemantics(find.byType(LossChart)),
        isSemantics(label: 'Training loss', value: '0.400'),
      );

      h.startRun();
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
      expect(tester.getSemantics(find.byType(LossChart)).value, isEmpty);
    });

    testWidgets('follows the theme extension, text scale and new histories', (
      tester,
    ) async {
      const custom = NeuralVizTheme(signal: Color(0xFFFF8800));
      Widget app(LossHistory h, double scale) => MaterialApp(
        theme: ThemeData(extensions: const [custom]),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 100,
              child: LossChart(history: h),
            ),
          ),
        ),
      );
      final a = run(120, marks: [60]);
      await tester.pumpWidget(app(a, 1));
      await tester.pumpWidget(app(a, 2.5));
      await tester.pumpWidget(app(run(30), 2.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes cleanly', (tester) async {
      final h = run(100, marks: [50]);
      await tester.pumpWidget(host(LossChart(history: h)));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      // The history outlives the chart; notifying it must not touch the
      // disposed chart.
      h.add(0.1);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

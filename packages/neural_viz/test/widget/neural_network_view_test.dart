import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';

import '../helpers/viz_fixtures.dart';

final _captureKey = GlobalKey();

/// The view at [size] under a bare MediaQuery (no MaterialApp needed).
Widget _host(
  Widget child, {
  Size size = const Size(720, 440),
  bool disableAnimations = false,
}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(1000, 800),
    disableAnimations: disableAnimations,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: _captureKey,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  ),
);

/// The pixels currently on screen for the hosted view.
Future<Uint8List> _capture(WidgetTester tester) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = boundary.toImageSync();
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  }))!;
}

NeuralNetworkView _view(
  int stage, {
  int trainingCount = 0,
  double production = 1e4,
  double progress = 0.4,
  double accuracy = 0.6,
  VoidCallback? onTrain,
  ValueChanged<VizTransition>? onPeak,
  ValueChanged<VizTransition>? onEnd,
  ValueListenable<Duration>? clock,
  String? semanticLabel,
  bool playIntro = true,
}) => NeuralNetworkView(
  topology: stageTopology(stage),
  stage: stage,
  nextTopology: nextTopologyAfter(stage),
  productionPerSecond: production,
  trainingCount: trainingCount,
  progress: progress,
  accuracy: accuracy,
  onTrain: onTrain,
  onTransitionPeak: onPeak,
  onTransitionEnd: onEnd,
  clock: clock,
  semanticLabel: semanticLabel,
  playIntro: playIntro,
  quality: VizQuality.high,
);

/// Pumps frames until none is scheduled; returns how long that took.
Future<Duration> _settle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 16),
  Duration limit = const Duration(seconds: 3),
}) async {
  var elapsed = Duration.zero;
  while (tester.binding.hasScheduledFrame && elapsed < limit) {
    await tester.pump(step);
    elapsed += step;
  }
  return elapsed;
}

void main() {
  group('lifecycle', () {
    testWidgets('mounts, animates and unmounts without ticker errors', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_view(3)));
      expect(tester.binding.hasScheduledFrame, isTrue);
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Unmount in the middle of an evolution, with waves in flight.
      await tester.pumpWidget(_host(_view(4, trainingCount: 1)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('every stage paints at awkward sizes', (tester) async {
      for (final size in const [Size.zero, Size(120, 80), Size(1, 300)]) {
        for (var stage = 0; stage < 8; stage++) {
          await tester.pumpWidget(_host(_view(stage), size: size));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull, reason: '$stage $size');
        }
        // Resizing a live view.
        await tester.pumpWidget(_host(_view(5), size: const Size(720, 440)));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(_host(_view(5), size: size));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('TickerMode(false) schedules no frames', (tester) async {
      await tester.pumpWidget(
        _host(TickerMode(enabled: false, child: _view(2))),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Turning tickers back on resumes the animation.
      await tester.pumpWidget(
        _host(TickerMode(enabled: true, child: _view(2))),
      );
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a FixedVizClock schedules no frames', (tester) async {
      const clock = FixedVizClock(Duration(milliseconds: 3100));
      await tester.pumpWidget(_host(_view(2, clock: clock)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // New inputs repaint once, then the view is idle again.
      await tester.pumpWidget(
        _host(_view(2, clock: clock, production: 1e9, trainingCount: 1)),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('repainting', () {
    testWidgets('a FixedVizClock gives identical frames across pumps', (
      tester,
    ) async {
      const clock = FixedVizClock(Duration(milliseconds: 3400));
      await tester.pumpWidget(_host(_view(4, clock: clock)));
      final first = await _capture(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(_host(_view(4, clock: clock)));
      expect(await _capture(tester), first);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('new inputs show up in the cached network picture', (
      tester,
    ) async {
      const clock = FixedVizClock(Duration(milliseconds: 3100));
      // What the trained network looks like when mounted directly.
      await tester.pumpWidget(_host(_view(2, clock: clock, accuracy: 0.95)));
      final trained = await _capture(tester);
      await tester.pumpWidget(const SizedBox());

      // The same inputs reached by an update must look the same: the
      // static picture is re-recorded and repainted.
      await tester.pumpWidget(_host(_view(2, clock: clock, accuracy: 0.1)));
      final untrained = await _capture(tester);
      expect(untrained, isNot(trained));
      await tester.pumpWidget(_host(_view(2, clock: clock, accuracy: 0.95)));
      expect(await _capture(tester), trained);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('frame pacing does not change the picture', (tester) async {
      // Same input history (mounted at 0 s, a tap at 1.5 s); one view is
      // stepped in 16.67 ms frames, the other jumps straight to 2 s.
      Future<Uint8List> run({required bool stepped}) async {
        final clock = ValueNotifier(Duration.zero);
        await tester.pumpWidget(_host(_view(5, clock: clock)));
        Future<void> to(int i) async {
          clock.value = Duration(microseconds: (i * 16666.67).round());
          await tester.pump();
        }

        if (stepped) {
          for (var i = 1; i <= 90; i++) {
            await to(i);
          }
        } else {
          await to(90);
        }
        await tester.pumpWidget(
          _host(_view(5, clock: clock, trainingCount: 1)),
        );
        if (stepped) {
          for (var i = 91; i <= 120; i++) {
            await to(i);
          }
        } else {
          await to(120);
        }
        final image = await _capture(tester);
        await tester.pumpWidget(const SizedBox());
        clock.dispose();
        return image;
      }

      expect(await run(stepped: true), await run(stepped: false));
    });
  });

  group('reduced motion', () {
    testWidgets('no frames are scheduled once settled', (tester) async {
      await tester.pumpWidget(_host(_view(4), disableAnimations: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      // Production and progress changes only repaint the still.
      await tester.pumpWidget(
        _host(
          _view(4, production: 1e10, progress: 0.95),
          disableAnimations: true,
        ),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('every tap runs a short fade, then the ticker stops', (
      tester,
    ) async {
      var count = 0;
      await tester.pumpWidget(_host(_view(2), disableAnimations: true));
      await tester.pump();
      for (var tap = 0; tap < 4; tap++) {
        // Idle for a while: the scene clock is stopped meanwhile.
        await tester.pump(Duration(milliseconds: 300 + 700 * tap));
        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pumpWidget(
          _host(_view(2, trainingCount: ++count), disableAnimations: true),
        );
        expect(
          tester.binding.hasScheduledFrame,
          isTrue,
          reason: 'tap $tap should animate',
        );
        final ran = await _settle(tester);
        expect(ran, greaterThanOrEqualTo(const Duration(milliseconds: 150)));
        expect(ran, lessThanOrEqualTo(const Duration(milliseconds: 500)));
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a stage change crossfades for 300 ms, then stops', (
      tester,
    ) async {
      final log = <String>[];
      Widget view(int stage) => _host(
        _view(
          stage,
          onPeak: (t) => log.add('peak'),
          onEnd: (t) => log.add('end'),
        ),
        disableAnimations: true,
      );
      await tester.pumpWidget(view(2));
      await tester.pump();
      await tester.pumpWidget(view(3));
      expect(tester.binding.hasScheduledFrame, isTrue);
      final ran = await _settle(tester);
      expect(ran, greaterThanOrEqualTo(const Duration(milliseconds: 300)));
      expect(ran, lessThan(const Duration(milliseconds: 400)));
      expect(log, ['peak', 'end']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('toggling it at runtime stops and restarts the ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_view(5, playIntro: false)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(
        _host(_view(5, playIntro: false), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(_host(_view(5, playIntro: false)));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('callbacks', () {
    testWidgets('onTrain fires on tap, Space and Enter', (tester) async {
      var trained = 0;
      await tester.pumpWidget(_host(_view(1, onTrain: () => trained++)));
      await tester.tap(find.byType(NeuralNetworkView));
      expect(trained, 1);

      Focus.of(tester.element(find.byType(GestureDetector))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(trained, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(trained, 3);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without onTrain the view takes no taps or focus', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_view(1)));
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(FocusableActionDetector), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('transition callbacks follow a ValueNotifier clock', (
      tester,
    ) async {
      final clock = ValueNotifier(Duration.zero);
      addTearDown(clock.dispose);
      final log = <String>[];
      Widget view(int stage) => _host(
        _view(
          stage,
          clock: clock,
          onPeak: (t) => log.add('peak ${t.kind.name} ${t.toStage}'),
          onEnd: (t) => log.add('end ${t.kind.name} ${t.toStage}'),
        ),
      );
      Future<void> at(int ms) async {
        clock.value = Duration(milliseconds: ms);
        await tester.pump();
      }

      await tester.pumpWidget(view(2));
      await at(1000);
      await tester.pumpWidget(view(3)); // evolves at t = 1 s
      await at(1395);
      expect(log, isEmpty);
      await at(1405);
      expect(log, ['peak evolve 3']);
      await at(3395);
      expect(log, hasLength(1));
      await at(3405);
      expect(log, ['peak evolve 3', 'end evolve 3']);

      await tester.pumpWidget(view(0)); // reset at t = 3.405 s
      await at(4095);
      expect(log, hasLength(2));
      await at(4115);
      expect(log.last, 'peak reset 0');
      await at(5015);
      expect(log.last, 'end reset 0');
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('transition callbacks follow the ticker', (tester) async {
      final log = <String>[];
      Widget view(int stage) => _host(
        _view(
          stage,
          playIntro: false,
          onPeak: (t) => log.add('peak'),
          onEnd: (t) => log.add('end'),
        ),
      );
      await tester.pumpWidget(view(6));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(view(7));
      await tester.pump(const Duration(milliseconds: 350));
      expect(log, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, ['peak']);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(log, ['peak']);
      await tester.pump(const Duration(milliseconds: 100));
      expect(log, ['peak', 'end']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('semantics', () {
    testWidgets('a label makes the view an image', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(_view(2, semanticLabel: 'Neural network: CNN')),
      );
      expect(find.bySemanticsLabel('Neural network: CNN'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Neural network: CNN')),
        isSemantics(label: 'Neural network: CNN', isImage: true),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('with onTrain the view is a labeled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(_view(2, semanticLabel: 'Train the network', onTrain: () {})),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Train the network')),
        isSemantics(
          label: 'Train the network',
          isButton: true,
          isFocusable: true,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });

    testWidgets('without a label the view is hidden from semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Semantics(
            container: true,
            label: 'host',
            explicitChildNodes: true,
            child: _view(2),
          ),
        ),
      );
      final host = tester.getSemantics(find.bySemanticsLabel('host'));
      expect(host.childrenCount, 0);
      expect(tester.getSemantics(find.byType(NeuralNetworkView)), same(host));
      await tester.pumpWidget(const SizedBox());
      handle.dispose();
    });
  });
}

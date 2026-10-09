import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/scene/layout.dart';
import 'package:neural_viz/src/scene/transition.dart';

import '../helpers/viz_fixtures.dart';

const _size = Size(720, 440);

NetworkLayout _layout(int stage) =>
    NetworkLayout.build(stageTopology(stage), _size, devicePixelRatio: 2);

SceneTransition _transition(
  int fromStage,
  int toStage, {
  VizTransitionKind? kind,
  bool reducedMotion = false,
}) {
  final resolved =
      kind ??
      (toStage > fromStage
          ? VizTransitionKind.evolve
          : (toStage < fromStage
                ? VizTransitionKind.reset
                : VizTransitionKind.crossfade));
  return SceneTransition(
    info: VizTransition(kind: resolved, fromStage: fromStage, toStage: toStage),
    start: 10,
    to: _layout(toStage),
    from: _layout(fromStage),
    reducedMotion: reducedMotion,
  );
}

void main() {
  group('mitosis parents', () {
    test('every new neuron has a valid parent', () {
      for (var from = 0; from < 8; from++) {
        for (var to = from + 1; to < 8; to++) {
          final tr = _transition(from, to);
          expect(tr.style, TransitionStyle.mitosis);
          final old = tr.from!;
          for (var n = 0; n < tr.to.neuronCount; n++) {
            expect(
              tr.parent[n],
              inInclusiveRange(0, old.neuronCount - 1),
              reason: '$from → $to neuron $n',
            );
          }
        }
      }
    });

    test('each parent has exactly one first child; the rest are orphans', () {
      for (var from = 0; from < 8; from++) {
        for (var to = from + 1; to < 8; to++) {
          final tr = _transition(from, to);
          final old = tr.from!;
          final firstChildren = List.filled(old.neuronCount, 0);
          final children = List.filled(old.neuronCount, 0);
          for (var n = 0; n < tr.to.neuronCount; n++) {
            children[tr.parent[n]]++;
            if (tr.firstChild[n] == 1) firstChildren[tr.parent[n]]++;
          }
          for (var p = 0; p < old.neuronCount; p++) {
            expect(firstChildren[p], children[p] > 0 ? 1 : 0);
            expect(tr.orphan[p], children[p] == 0 ? 1 : 0);
          }
          // The first child is the lowest-numbered one: it keeps its place
          // in the column order.
          for (var n = 0; n < tr.to.neuronCount; n++) {
            if (tr.firstChild[n] != 1) continue;
            for (var m = 0; m < n; m++) {
              expect(tr.parent[m], isNot(tr.parent[n]));
            }
          }
        }
      }
    });

    test('parents follow the documented layer and index mapping', () {
      for (var from = 0; from < 8; from++) {
        for (var to = from + 1; to < 8; to++) {
          final tr = _transition(from, to);
          final old = tr.from!, next = tr.to;
          final oldL = old.layerCount, newL = next.layerCount;
          for (var l = 0; l < newL; l++) {
            final parentLayer = (l * (oldL - 1) / (newL - 1)).round();
            final oldN = old.layerSize(parentLayer), newN = next.layerSize(l);
            for (var i = 0; i < newN; i++) {
              final p = tr.parent[next.layerStart[l] + i];
              expect(old.layerOf[p], parentLayer);
              final index = ((i + 0.5) * oldN / newN - 0.5).round().clamp(
                0,
                oldN - 1,
              );
              expect(p - old.layerStart[parentLayer], index);
            }
          }
          // Inputs grow from inputs and outputs from outputs.
          expect(old.layerOf[tr.parent[0]], 0);
          expect(
            old.layerOf[tr.parent[next.neuronCount - 1]],
            old.layerCount - 1,
          );
        }
      }
    });

    test('children of a parent are contiguous in their layer', () {
      final tr = _transition(5, 6);
      final next = tr.to;
      for (var l = 0; l < next.layerCount; l++) {
        final seen = <int>{};
        var previous = -1;
        for (var n = next.layerStart[l]; n < next.layerStart[l + 1]; n++) {
          final p = tr.parent[n];
          if (p != previous) {
            expect(seen.add(p), isTrue, reason: 'parent $p split');
          }
          previous = p;
        }
      }
    });
  });

  group('styles without parents', () {
    test('reset, crossfade, reduced motion and intro map nothing', () {
      final cases = [
        _transition(5, 0),
        _transition(3, 3),
        _transition(2, 3, reducedMotion: true),
        SceneTransition(
          info: const VizTransition(
            kind: VizTransitionKind.intro,
            fromStage: 2,
            toStage: 2,
          ),
          start: 0,
          to: _layout(2),
          reducedMotion: false,
        ),
      ];
      for (final tr in cases) {
        expect(tr.style, isNot(TransitionStyle.mitosis));
        expect(tr.parent.every((p) => p == -1), isTrue);
        expect(tr.firstChild.every((c) => c == 0), isTrue);
      }
    });
  });

  group('timing', () {
    test('durations and peaks match the spec', () {
      final evolve = _transition(1, 2);
      expect(evolve.style, TransitionStyle.mitosis);
      expect(evolve.duration, 2.4);
      expect(evolve.peakAt, 0.4);

      final reset = _transition(4, 0);
      expect(reset.style, TransitionStyle.collapse);
      expect(reset.duration, 1.6);
      expect(reset.peakAt, 0.7);

      final crossfade = _transition(3, 3);
      expect(crossfade.style, TransitionStyle.crossfade);
      expect(crossfade.duration, 0.4);
      expect(crossfade.peakAt, 0.2);

      final reduced = _transition(1, 2, reducedMotion: true);
      expect(reduced.style, TransitionStyle.crossfade);
      expect(reduced.duration, 0.3);
      expect(reduced.peakAt, 0.15);
      expect(reduced.notifies, isTrue);
    });

    test('the intro is silent', () {
      final intro = SceneTransition(
        info: const VizTransition(
          kind: VizTransitionKind.intro,
          fromStage: 0,
          toStage: 0,
        ),
        start: 0,
        to: _layout(0),
        reducedMotion: false,
      );
      expect(intro.style, TransitionStyle.unfold);
      expect(intro.duration, 0.9);
      expect(intro.notifies, isFalse);
    });

    test('elapsed and isDone are relative to the start', () {
      final tr = _transition(0, 1);
      expect(tr.elapsed(10.5), 0.5);
      expect(tr.isDone(12.39), isFalse);
      expect(tr.isDone(12.4), isTrue);
    });

    test('edges finish weaving before the settle', () {
      final cases = [
        for (var from = 0; from < 7; from++) _transition(from, from + 1),
        _transition(0, 7),
        // Publishing a paper resets to the perceptron.
        for (var from = 1; from < 8; from++) _transition(from, 0),
      ];
      for (final tr in cases) {
        expect(tr.settleAt, lessThan(tr.duration));
        expect(tr.settleAt, greaterThan(tr.peakAt));
        // Edges of the last layer pair start weaving last.
        for (var e = 0; e < 400; e++) {
          for (var layer = 0; layer < tr.to.layerCount - 1; layer++) {
            final start = tr.weaveStart(e, layer);
            expect(start, greaterThan(tr.peakAt), reason: '${tr.info}');
            expect(
              start + SceneTransition.weaveDuration,
              lessThanOrEqualTo(tr.settleAt),
              reason: '${tr.info}',
            );
          }
        }
      }
    });

    test('multi-stage jumps play one transition straight to the target', () {
      final tr = _transition(0, 7);
      expect(tr.info.steps, 7);
      expect(tr.style, TransitionStyle.mitosis);
      expect(tr.to.kind, NetworkKind.agi);
    });
  });
}

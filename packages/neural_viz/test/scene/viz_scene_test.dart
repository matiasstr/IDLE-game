import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/render/sprite_atlas.dart';
import 'package:neural_viz/src/scene/frame_buffers.dart';
import 'package:neural_viz/src/scene/viz_scene.dart';

import '../helpers/viz_fixtures.dart';

/// Every batch and bucket has room left: nothing was silently dropped.
void _expectWithinCaps(FrameBuffers f, String reason) {
  expect(f.glow.count, lessThan(f.glow.capacity), reason: '$reason glow');
  expect(f.cores.count, lessThan(f.cores.capacity), reason: '$reason cores');
  for (final hue in f.lit) {
    for (final bucket in hue) {
      expect(bucket.count, lessThan(bucket.capacity), reason: '$reason lit');
    }
  }
  for (final sign in f.base) {
    for (final level in sign) {
      for (final bucket in level) {
        expect(bucket.count, lessThan(bucket.capacity), reason: '$reason base');
      }
    }
  }
  expect(f.bodyCount, lessThan(FrameBuffers.maxNeurons), reason: reason);
  expect(f.ringCount, lessThan(f.ringX.length), reason: reason);
}

/// Signal heads in the glow batch: cyan dots of the head size (motifs may
/// add dots of their own, at other sizes).
/// Signal heads of any hue: motifs may tint them (multimodal inputs keep
/// their modality's color until fusion).
int _signalHeads(VizScene scene) {
  final glow = scene.frame.glow;
  final headWidth = 0.8 * scene.layout!.r + 2.5;
  var n = 0;
  for (var i = 0; i < glow.count; i++) {
    // Unrotated scale × cell width = drawn width.
    final width = glow.transforms[i * 4] * Sprites.dot.width * glow.atlasScale;
    if (glow.rects[i * 4] == Sprites.dot.x * glow.atlasScale &&
        glow.rects[i * 4 + 1] == Sprites.dot.y * glow.atlasScale &&
        (width - headWidth).abs() < 1e-3) {
      n++;
    }
  }
  return n;
}

/// Centers of the signal heads (see [_signalHeads]).
List<(double, double)> _signalHeadCenters(VizScene scene) {
  final glow = scene.frame.glow;
  final signal = scene.theme.signal.toARGB32() & 0xffffff;
  final headWidth = 0.8 * scene.layout!.r + 2.5;
  final cell = Sprites.dot.width * glow.atlasScale;
  return [
    for (var i = 0; i < glow.count; i++)
      if (glow.rects[i * 4] == Sprites.dot.x * glow.atlasScale &&
          glow.colors[i] & 0xffffff == signal &&
          (glow.transforms[i * 4] * cell - headWidth).abs() < 1e-3)
        (
          glow.transforms[i * 4 + 2] + glow.transforms[i * 4] * cell / 2,
          glow.transforms[i * 4 + 3] + glow.transforms[i * 4] * cell / 2,
        ),
  ];
}

double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final length2 = dx * dx + dy * dy;
  final u = length2 == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / length2).clamp(0.0, 1.0);
  final cx = ax + u * dx, cy = ay + u * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

int _ghosts(FrameBuffers f) => countSprites(f.glow, Sprites.dashRing);

void main() {
  group('evaluate is a pure function of inputs and time', () {
    for (var stage = 0; stage < 8; stage++) {
      test('stage $stage', () {
        final d = SceneDriver(stage, production: 1e6, progress: 0.97)
          ..tap([1.0, 2.9, 3.0]);
        for (final (t1, t2) in const [(3.1, 7.9), (3.45, 3.0), (12.0, 0.5)]) {
          final first = snapshot(d.frameAt(t1));
          expect(snapshot(d.frameAt(t1)), first, reason: 't1 twice');
          d.frameAt(t2);
          expect(snapshot(d.frameAt(t1)), first, reason: 't1, t2, t1');
        }
        d.dispose();
      });
    }

    test('also while transforming', () {
      for (var stage = 0; stage < 7; stage++) {
        final d = SceneDriver(stage, production: 1e9)..frameAt(0.9);
        d.goTo(1, stage + 1);
        expect(d.scene.transition, isNotNull);
        for (final (t1, t2) in const [
          (1.2, 2.0),
          (1.45, 1.1),
          (2.2, 3.3),
          (3.2, 1.0),
        ]) {
          final first = snapshot(d.frameAt(t1));
          d.frameAt(t2);
          expect(snapshot(d.frameAt(t1)), first, reason: '$stage at $t1');
        }
        d.dispose();
      }
    });

    test('frame pacing does not change the frame', () {
      for (final stage in const [2, 5, 7]) {
        SceneDriver make() =>
            SceneDriver(stage, production: 1e5, progress: 0.9)
              ..tap([6.9, 7.25]);

        final once = make();
        final expected = snapshot(once.frameAt(7.3));
        once.dispose();
        for (final step in const [1 / 60, 1 / 120, 1 / 30, 0.0213]) {
          final stepped = make();
          for (var t = 0.0; t < 7.3; t += step) {
            stepped.frameAt(t);
          }
          expect(
            snapshot(stepped.frameAt(7.3)),
            expected,
            reason: '$stage $step',
          );
          stepped.dispose();
        }
      }
    });

    test('buffers are reused, never reallocated', () {
      final d = SceneDriver(7, production: 1e12);
      final f = d.frame;
      final glow = f.glow, cores = f.cores;
      final transforms = glow.transforms, rects = glow.rects;
      final colors = glow.colors;
      final lit = [for (final hue in f.lit) ...hue];
      final litPoints = [for (final b in lit) b.points];
      final base = [
        for (final sign in f.base)
          for (final level in sign) ...level,
      ];
      final bodyX = f.bodyX, ringX = f.ringX;
      for (var i = 0; i < 1000; i++) {
        final t = i * 0.016;
        if (i % 50 == 0) d.tap([t]);
        if (i == 400) d.goTo(t, 6);
        d.scene.tick(t);
        d.frameAt(t);
      }
      expect(identical(d.scene.frame, f), isTrue);
      expect(identical(f.glow, glow), isTrue);
      expect(identical(f.cores, cores), isTrue);
      expect(identical(glow.transforms, transforms), isTrue);
      expect(identical(glow.rects, rects), isTrue);
      expect(identical(glow.colors, colors), isTrue);
      final litNow = [for (final hue in f.lit) ...hue];
      for (var i = 0; i < lit.length; i++) {
        expect(identical(litNow[i], lit[i]), isTrue);
        expect(identical(litNow[i].points, litPoints[i]), isTrue);
      }
      final baseNow = [
        for (final sign in f.base)
          for (final level in sign) ...level,
      ];
      for (var i = 0; i < base.length; i++) {
        expect(identical(baseNow[i], base[i]), isTrue);
      }
      expect(identical(f.bodyX, bodyX), isTrue);
      expect(identical(f.ringX, ringX), isTrue);
      d.dispose();
    });
  });

  group('instance caps', () {
    test('signal heads stay within the slot cap at full production', () {
      for (var stage = 0; stage < 8; stage++) {
        for (final size in layoutSizes) {
          for (final quality in const [
            VizQuality.high,
            VizQuality.medium,
            VizQuality.low,
          ]) {
            final d = SceneDriver(
              stage,
              size: size,
              production: 1e12,
              quality: quality,
            );
            final factor = switch (quality) {
              VizQuality.low => 0.35,
              VizQuality.medium => 0.6,
              _ => 1.0,
            };
            final cap =
                ((size.width * size.height / 2600).round().clamp(24, 140) *
                        factor)
                    .round();
            var most = 0;
            for (var t = 0.0; t < 6; t += 0.37) {
              d.frameAt(t);
              final heads = _signalHeads(d.scene);
              expect(
                heads,
                lessThanOrEqualTo(cap),
                reason: 'stage $stage $size $quality t $t',
              );
              most = math.max(most, heads);
              _expectWithinCaps(d.frame, 'stage $stage $size');
            }
            // Full production does fill the network with signals.
            expect(most, greaterThanOrEqualTo(3), reason: 'stage $stage $size');
            d.dispose();
          }
        }
      }
    });

    test('nothing is dropped at full production with waves and ghosts', () {
      for (var stage = 0; stage < 8; stage++) {
        final d = SceneDriver(
          stage,
          size: const Size(900, 520),
          production: 1e12,
          progress: 1,
        );
        // As many waves as the limiter allows, plus full heat.
        d.tap([for (var i = 0; i < 40; i++) 1 + i * 0.05]);
        expect(d.scene.taps.aliveWaves(2.95), greaterThanOrEqualTo(3));
        expect(d.scene.taps.heat(2.95), 1);
        for (var t = 2.0; t < 3.5; t += 0.02) {
          _expectWithinCaps(d.frameAt(t), 'stage $stage t $t');
        }
        d.dispose();
      }
    });

    test('nothing is dropped during any transition at full production', () {
      final pairs = [
        for (var s = 0; s < 7; s++) (s, s + 1),
        (0, 7),
        (7, 0),
        (6, 2),
        (4, 4),
      ];
      for (final (from, to) in pairs) {
        final d = SceneDriver(
          from,
          size: const Size(900, 520),
          production: 1e12,
          progress: 1,
        );
        d
          ..tap([0.5, 0.9])
          ..frameAt(0.95);
        d.goTo(
          1,
          to,
          newTopology: to == from ? stageTopology(to, seed: 9) : null,
        );
        expect(d.scene.transition, isNotNull, reason: '$from → $to');
        d.tap([1.2, 1.6, 2.0]);
        for (var t = 1.0; t < 3.6; t += 0.01) {
          _expectWithinCaps(d.frameAt(t), '$from → $to at $t');
        }
        d.dispose();
      }
    });
  });

  group('signals', () {
    test('every signal head travels on an existing edge', () {
      for (var stage = 0; stage < 7; stage++) {
        final d = SceneDriver(stage, production: 1e7, accuracy: 0.9);
        final layout = d.scene.layout!;
        var seen = 0;
        for (var t = 0.0; t < 8; t += 0.23) {
          d.frameAt(t);
          for (final (x, y) in _signalHeadCenters(d.scene)) {
            var onEdge = false;
            for (var e = 0; e < layout.edgeCount && !onEdge; e++) {
              final a = layout.edgeSrc[e], b = layout.edgeDst[e];
              onEdge =
                  _distanceToSegment(
                    x,
                    y,
                    layout.x[a],
                    layout.y[a],
                    layout.x[b],
                    layout.y[b],
                  ) <
                  0.05;
            }
            expect(onEdge, isTrue, reason: 'stage $stage t $t at ($x, $y)');
            seen++;
          }
        }
        expect(seen, greaterThan(20), reason: 'stage $stage');
        d.dispose();
      }
    });

    test('with no production a signal still shows every 1.5 s', () {
      for (var stage = 0; stage < 8; stage++) {
        final d = SceneDriver(stage, production: 0);
        var lastSeen = 0.0;
        for (var t = 0.0; t < 20; t += 0.05) {
          d.frameAt(t);
          if (_signalHeads(d.scene) > 0) lastSeen = t;
          expect(t - lastSeen, lessThan(1.5), reason: 'stage $stage at $t');
        }
        d.dispose();
      }
    });
  });

  group('progress effects', () {
    test('ghosts appear where the next stage adds neurons', () {
      for (var stage = 0; stage < 7; stage++) {
        // (Motifs may draw dashed rings of their own: compare counts.)
        final early = SceneDriver(stage, progress: 0.5);
        final ghostsEarly = _ghosts(early.frameAt(3));
        final d = SceneDriver(stage, progress: 1);
        final added =
            stageTopology(stage + 1).neuronCount -
            stageTopology(stage).neuronCount;
        expect(
          _ghosts(d.frameAt(3)) - ghostsEarly,
          inInclusiveRange(1, stageTopology(stage + 1).neuronCount),
          reason: 'stage $stage (+$added neurons)',
        );
        d.dispose();
        early.dispose();
      }
    });

    test('no ghosts or shimmer without a next stage, even at progress 1', () {
      for (final stage in const [7, 4]) {
        final full = SceneDriver(stage, progress: 1, lastStage: true);
        final none = SceneDriver(stage, progress: 0, lastStage: true);
        for (var t = 0.0; t < 4; t += 0.13) {
          // Frames are identical: same ghosts (none) and the same halos.
          expect(
            snapshot(full.frameAt(t)),
            snapshot(none.frameAt(t)),
            reason: 'stage $stage t $t',
          );
        }
        full.dispose();
        none.dispose();
      }
    });
  });

  group('transitions', () {
    (SceneDriver, List<String>) watched(int stage, {bool reduced = false}) {
      final d = SceneDriver(stage, reducedMotion: reduced)..frameAt(0.5);
      final log = <String>[];
      d.scene.onTransitionPeak = (t) => log.add('peak ${t.kind.name}');
      d.scene.onTransitionEnd = (t) => log.add('end ${t.kind.name}');
      return (d, log);
    }

    void expectTimeline(
      VizScene scene,
      List<String> log,
      double start,
      double peak,
      double end,
      String kind,
    ) {
      scene.tick(start + peak - 0.005);
      expect(log, isEmpty);
      scene.tick(start + peak + 0.005);
      expect(log, ['peak $kind']);
      scene.tick(start + end - 0.005);
      expect(log, ['peak $kind']);
      expect(scene.transition, isNotNull);
      scene.tick(start + end + 0.005);
      expect(log, ['peak $kind', 'end $kind']);
      expect(scene.transition, isNull);
      scene.tick(start + end + 1);
      expect(log, hasLength(2));
    }

    test('an evolution peaks at 400 ms and ends at 2400 ms', () {
      final (d, log) = watched(2);
      d.goTo(1, 3);
      expect(d.scene.transition!.info.kind, VizTransitionKind.evolve);
      expectTimeline(d.scene, log, 1, 0.4, 2.4, 'evolve');
      d.dispose();
    });

    test('a reset peaks at 700 ms and ends at 1600 ms', () {
      final (d, log) = watched(5);
      d.goTo(1, 0);
      expect(d.scene.transition!.info.kind, VizTransitionKind.reset);
      expectTimeline(d.scene, log, 1, 0.7, 1.6, 'reset');
      d.dispose();
    });

    test('the same stage with a new topology crossfades in 400 ms', () {
      final (d, log) = watched(3);
      d.goTo(
        1,
        3,
        newTopology: const NetworkTopology(
          kind: NetworkKind.rnn,
          layers: [4, 8, 8, 4],
        ),
      );
      expect(d.scene.transition!.info.kind, VizTransitionKind.crossfade);
      expectTimeline(d.scene, log, 1, 0.2, 0.4, 'crossfade');
      d.dispose();
    });

    test('with reduced motion every change is a 300 ms crossfade', () {
      final (d, log) = watched(1, reduced: true);
      d.goTo(1, 2);
      expect(d.scene.transition!.info.kind, VizTransitionKind.evolve);
      expectTimeline(d.scene, log, 1, 0.15, 0.3, 'evolve');
      d.dispose();
    });

    test('an equal topology built anew plays nothing', () {
      final (d, log) = watched(4);
      d.goTo(
        1,
        4,
        newTopology: NetworkTopology(
          kind: NetworkKind.transformer,
          layers: List.of(stageLayers[4]),
        ),
      );
      expect(d.scene.transition, isNull);
      d.scene.tick(5);
      expect(log, isEmpty);
      d.dispose();
    });

    test('the intro is silent and ends after 900 ms', () {
      final d = SceneDriver(3, playIntro: true);
      final log = <String>[];
      d.scene.onTransitionPeak = (t) => log.add('peak');
      d.scene.onTransitionEnd = (t) => log.add('end');
      expect(d.scene.transition, isNotNull);
      expect(d.scene.staticNetworkVisible, isFalse);
      d.scene.tick(0.89);
      expect(d.scene.transition, isNotNull);
      d.scene.tick(0.91);
      expect(d.scene.transition, isNull);
      expect(d.scene.staticNetworkVisible, isTrue);
      expect(log, isEmpty);
      d.dispose();
    });

    test('the old network starts exactly where it was drawn', () {
      final (d, _) = watched(2);
      final before = d.scene.layout!;
      d.goTo(1, 3);
      final f = d.frameAt(1);
      expect(f.scale, 1);
      expect(f.bodyCount, before.neuronCount);
      for (var i = 0; i < f.bodyCount; i++) {
        expect(f.bodyX[i], before.x[i]);
        expect(f.bodyY[i], before.y[i]);
      }
      d.dispose();
    });

    test('the new network lands exactly on its layout', () {
      final (d, _) = watched(1);
      d.goTo(1, 2);
      // Just before the end the dynamic drawing fades out over the static
      // picture with every body at its final place.
      final f = d.frameAt(3.39);
      final layout = d.scene.layout!;
      expect(f.bodyCount, layout.neuronCount);
      for (var i = 0; i < f.bodyCount; i++) {
        expect(f.bodyX[i], closeTo(layout.x[i], 1e-3));
        expect(f.bodyY[i], closeTo(layout.y[i], 1e-3));
        expect(f.bodyR[i], closeTo(layout.radius[i], 1e-3));
      }
      expect(f.networkPictureAlpha, greaterThan(0.9));
      d.scene.tick(3.41);
      d.frameAt(3.41);
      expect(f.bodyCount, 0);
      expect(f.networkPictureAlpha, 0);
      expect(d.scene.staticNetworkVisible, isTrue);
      d.dispose();
    });

    test('the network is complete before the static picture fades in', () {
      // Otherwise the fade shows a double image: bodies still flying over
      // the picture's bodies at their final places.
      final cases = [
        for (var s = 0; s < 6; s++) (s, s + 1),
        (0, 6),
        (2, 5),
        for (var s = 1; s < 8; s++) (s, 0), // publishing resets to stage 0
      ];
      for (final (from, to) in cases) {
        final d = SceneDriver(from)..frameAt(0.5);
        d.goTo(1, to);
        final tr = d.scene.transition!;
        final f = d.frameAt(1 + tr.settleAt);
        final layout = d.scene.layout!;
        final reason = '$from → $to';
        expect(f.networkPictureAlpha, closeTo(0, 1e-9), reason: reason);
        expect(f.bodyCount, layout.neuronCount, reason: reason);
        for (var i = 0; i < f.bodyCount; i++) {
          expect(f.bodyX[i], closeTo(layout.x[i], 0.5), reason: reason);
          expect(f.bodyY[i], closeTo(layout.y[i], 0.5), reason: reason);
          expect(f.bodyR[i], closeTo(layout.radius[i], 0.05), reason: reason);
        }
        // Every edge is fully woven: one segment each, ending on a neuron.
        var segments = 0;
        for (final sign in f.base) {
          for (final level in sign) {
            for (final bucket in level) {
              segments += bucket.count;
              for (var s = 0; s < bucket.count; s++) {
                final x2 = bucket.points[s * 4 + 2];
                final y2 = bucket.points[s * 4 + 3];
                var onNeuron = false;
                for (var n = 0; n < layout.neuronCount && !onNeuron; n++) {
                  onNeuron =
                      (x2 - layout.x[n]).abs() < 0.5 &&
                      (y2 - layout.y[n]).abs() < 0.5;
                }
                expect(onNeuron, isTrue, reason: '$reason edge end');
              }
            }
          }
        }
        expect(segments, layout.edgeCount, reason: reason);
        d.dispose();
      }
    });

    test('a resize mid-transition keeps its progress and callbacks', () {
      for (final (from, to, resizeAt) in const [
        (2, 3, 1.2), // before the peak
        (2, 3, 2.0), // mid mitosis
        (5, 0, 1.5), // reset
        (6, 7, 1.3), // into the rings
        (7, 0, 1.1), // out of the rings
      ]) {
        final (d, log) = watched(from);
        d.goTo(1, to);
        final kind = d.scene.transition!.info.kind.name;
        final duration = d.scene.transition!.duration;
        d.frameAt(resizeAt - 0.1);
        d.size = const Size(390, 280);
        d.scene.tick(resizeAt);
        d.frameAt(resizeAt);
        final tr = d.scene.transition;
        expect(tr, isNotNull, reason: '$from → $to');
        expect(tr!.start, 1);
        expect(tr.to.size, const Size(390, 280));
        expect(tr.from!.size, const Size(390, 280));
        for (var t = resizeAt; t < 1 + duration + 0.1; t += 0.05) {
          d.scene.tick(t);
          _expectWithinCaps(d.frameAt(t), '$from → $to at $t');
        }
        expect(log, ['peak $kind', 'end $kind'], reason: '$from → $to');
        expect(d.scene.transition, isNull);
        expect(d.scene.layout!.size, const Size(390, 280));
        d.dispose();
      }
    });

    test('a change mid-flight starts from what was drawn', () {
      for (final (start, first, second) in const [
        (1, 2, 3),
        (3, 4, 0),
        (4, 5, 6),
        (6, 7, 0),
      ]) {
        final (d, _) = watched(start);
        d.goTo(1, first);
        d.frameAt(1.85);
        final before = d.frameAt(1.9);
        final bodies = [
          for (var i = 0; i < before.bodyCount; i++)
            (before.bodyX[i], before.bodyY[i], before.bodyR[i]),
        ];
        d.goTo(1.9, second);
        final after = d.frameAt(1.9);
        // Everything drawn a frame ago is still there, within a pixel.
        for (final (x, y, r) in bodies) {
          var found = false;
          for (var i = 0; i < after.bodyCount && !found; i++) {
            found =
                (after.bodyX[i] - x).abs() <= 1 &&
                (after.bodyY[i] - y).abs() <= 1 &&
                (after.bodyR[i] - r).abs() <= 1;
          }
          expect(found, isTrue, reason: '$first → $second body at ($x, $y)');
        }
        d.dispose();
      }
    });

    test('a multi-stage jump draws one shockwave per stage, up to 3', () {
      for (final (from, to, rings) in const [(0, 1, 1), (2, 4, 2), (0, 7, 3)]) {
        final d = SceneDriver(from)..frameAt(0.5);
        d.goTo(1, to);
        // All rings have started and none has ended.
        expect(d.frameAt(1 + 0.4 + 0.25).ringCount, rings, reason: '$to');
        d.dispose();
      }
    });

    test('taps during a transition only add heat', () {
      final d = SceneDriver(1)..frameAt(0.5);
      // The tap that crosses the threshold arrives with the new topology.
      d
        ..trainingCount += 1
        ..goTo(1, 2);
      expect(d.scene.transition, isNotNull);
      // 3.0 is 0.4 s before the end: such a wave would surface half done.
      d.tap([1.5, 3.0]);
      expect(d.scene.taps.serial, 3);
      expect(d.scene.taps.heat(3.0), greaterThan(0.12));
      for (final t in const [1.0, 1.5, 3.0, 3.2, 3.41, 3.9]) {
        expect(d.scene.taps.aliveWaves(t), 0, reason: 'at $t');
      }
      d.scene.tick(3.41);
      expect(d.scene.transition, isNull);
      // Once settled, taps start waves again.
      d.tap([3.5]);
      expect(d.scene.taps.aliveWaves(3.5), 1);
      d.dispose();
    });
  });

  group('reduced motion', () {
    test('the still is the hero frame whatever the time', () {
      for (var stage = 0; stage < 8; stage++) {
        final hero = NetworkKind.values[stage].heroTime.inMicroseconds / 1e6;
        final d = SceneDriver(stage, reducedMotion: true, t: hero);
        final still = snapshot(d.frameAt(hero));
        for (final t in const [0.0, 1.7, 9.3, 60.0]) {
          expect(snapshot(d.frameAt(t)), still, reason: 'stage $stage t $t');
        }
        d.dispose();
      }
    });

    test('a new production rate shows in the still right away', () {
      final d = SceneDriver(4, reducedMotion: true, production: 1, t: 3.4);
      final dim = snapshot(d.frameAt(3.4));
      d
        ..production = 1e11
        ..apply(3.4);
      expect(snapshot(d.frameAt(3.4)), isNot(dim));
      // Settled at once: no easing to wait for.
      expect(snapshot(d.frameAt(3.4)), snapshot(d.frameAt(10)));
      d.dispose();
    });

    test('a tap brightens the inputs for 150 ms and changes nothing else', () {
      final d = SceneDriver(2, reducedMotion: true, t: 3.1);
      final still = snapshot(d.frameAt(3.1));
      d.tap([3.1]);
      expect(d.scene.isAnimatingAt(3.1), isTrue);
      expect(snapshot(d.frameAt(3.1)), isNot(still));
      expect(snapshot(d.frameAt(3.26)), still);
      // The ticker keeps running until another tap could start a wave.
      expect(d.scene.isAnimatingAt(3.3), isTrue);
      expect(d.scene.isAnimatingAt(3.45), isFalse);

      // Every later tap gets the same feedback, however long it was idle.
      for (final t in const [3.45, 3.8, 4.2]) {
        d.tap([t]);
        expect(d.scene.taps.aliveWaves(t), greaterThanOrEqualTo(1));
        expect(snapshot(d.frameAt(t)), isNot(still), reason: 'tap at $t');
        expect(snapshot(d.frameAt(t + 0.16)), still, reason: 'after $t');
      }
      d.dispose();
    });
  });

  group('caching', () {
    test('5 s of animation records the network picture once', () {
      final d = SceneDriver(4, production: 1e8);
      final records = d.scene.debugNetworkRecords;
      final builds = d.scene.debugLayoutBuilds;
      for (var i = 0; i < 300; i++) {
        final t = i / 60;
        if (i % 40 == 0) d.tap([t]);
        d.scene.tick(t);
        d.frameAt(t);
      }
      expect(d.scene.debugNetworkRecords, records);
      expect(d.scene.debugLayoutBuilds, builds);
      d.dispose();
    });

    test('progress re-records only when the contrast bucket changes', () {
      final d = SceneDriver(4, accuracy: 0.95, progress: 0.30);
      final records = d.scene.debugNetworkRecords;
      d
        ..progress = 0.31
        ..apply(1)
        ..frameAt(1);
      expect(d.scene.debugNetworkRecords, records);
      d
        ..progress = 0.5
        ..apply(2)
        ..frameAt(2);
      expect(d.scene.debugNetworkRecords, records + 1);
      d.dispose();
    });

    test('a resize builds the layout exactly once', () {
      final d = SceneDriver(5);
      final builds = d.scene.debugLayoutBuilds;
      d
        ..size = const Size(390, 280)
        ..frameAt(1)
        ..frameAt(1.1);
      expect(d.scene.debugLayoutBuilds, builds + 1);
      expect(d.scene.layout!.size, const Size(390, 280));
      d.dispose();
    });

    test('an empty size draws nothing and does not throw', () {
      final d = SceneDriver(3, size: Size.zero);
      d.frameAt(0);
      expect(d.scene.layout, isNull);
      expect(d.frame.glow.count, 0);
      d.dispose();
    });

    test('replaced and released pictures are disposed', () {
      final d = SceneDriver(4, accuracy: 0.95, progress: 0.3);
      final first = d.scene.network!;
      final background = d.scene.background!;
      d
        ..progress = 0.6
        ..apply(1)
        ..frameAt(1);
      final second = d.scene.network!;
      expect(identical(first, second), isFalse);
      // Retired pictures are released at the next paint.
      d.frameAt(1.1);
      expect(first.debugDisposed, isTrue);
      expect(second.debugDisposed, isFalse);
      d.dispose();
      expect(second.debugDisposed, isTrue);
      expect(background.debugDisposed, isTrue);
    });

    test('the sprite atlas is shared and freed with the last scene', () {
      final a = SceneDriver(1, dpr: 3), b = SceneDriver(2, dpr: 2.5);
      expect(identical(a.scene.atlas, b.scene.atlas), isTrue);
      final image = a.scene.atlas!.image;
      a.dispose();
      expect(image.debugDisposed, isFalse);
      b.dispose();
      expect(image.debugDisposed, isTrue);
    });
  });

  group('inputs', () {
    test('NaN and out-of-range inputs are sanitized', () {
      final d = SceneDriver(3)
        ..production = double.nan
        ..trainingCount = -5
        ..progress = double.nan
        ..accuracy = double.infinity
        ..apply(1);
      for (final v in snapshot(d.frameAt(2))) {
        expect(v.isFinite, isTrue);
      }
      d.dispose();
    });
  });
}

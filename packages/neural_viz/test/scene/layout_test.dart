import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/scene/layout.dart';

import '../helpers/viz_fixtures.dart';

/// Half the extent of a body: diamonds are drawn 1.2× wider.
double _extent(NetworkLayout l, int n) =>
    l.radius[n] * (l.shape[n] == NeuronShape.diamond.index ? 1.2 : 1);

bool _snapped(double v, double dpr) {
  final scaled = v * dpr;
  return (scaled - scaled.roundToDouble()).abs() < 1e-3;
}

void _expectIdentical(NetworkLayout a, NetworkLayout b) {
  expect(a.content, b.content);
  expect(a.layerStart, b.layerStart);
  expect(a.layerX, b.layerX);
  expect(a.x, b.x);
  expect(a.y, b.y);
  expect(a.radius, b.radius);
  expect(a.shape, b.shape);
  expect(a.layerOf, b.layerOf);
  expect(a.edgeSrc, b.edgeSrc);
  expect(a.edgeDst, b.edgeDst);
  expect(a.weight, b.weight);
  expect(a.highway, b.highway);
  expect(a.outStart, b.outStart);
  expect(a.outEdges, b.outEdges);
  expect(a.gap, b.gap);
  expect(a.pitch, b.pitch);
  expect(a.r, b.r);
  expect(a.captions, b.captions);
  expect(a.captionY, b.captionY);
  expect(a.groupOf, b.groupOf);
  expect(a.ringRadius, b.ringRadius);
  expect(a.ringAngle, b.ringAngle);
  expect(a.coreRadius, b.coreRadius);
}

/// Bodies of the AGI rings at every rotation: the ellipse of ring k plus
/// the body radius must stay inside the content rectangle.
void _expectRingsInside(NetworkLayout l) {
  final c = l.center;
  for (var k = 0; k < l.layerCount; k++) {
    final rx = l.ringRadius[k], ry = rx * kRingSquash;
    final r = l.r;
    expect(c.dx - rx - r, greaterThanOrEqualTo(l.content.left - 1e-3));
    expect(c.dx + rx + r, lessThanOrEqualTo(l.content.right + 1e-3));
    expect(c.dy - ry - r, greaterThanOrEqualTo(l.content.top - 1e-3));
    expect(c.dy + ry + r, lessThanOrEqualTo(l.content.bottom + 1e-3));
  }
}

void main() {
  group('NetworkLayout invariants', () {
    for (final kind in NetworkKind.values) {
      for (final size in layoutSizes) {
        final label =
            '${kind.name} ${size.width.toInt()}×${size.height.toInt()}';
        test(label, () {
          final topology = stageTopology(kind.index);
          for (final dpr in const [1.0, 1.5, 2.0, 3.0]) {
            final l = NetworkLayout.build(
              topology,
              size,
              devicePixelRatio: dpr,
            );
            final reason = '$label @${dpr}x';

            // Structure.
            expect(l.layerCount, stageLayers[kind.index].length);
            expect(l.neuronCount, topology.neuronCount);
            for (var layer = 0; layer < l.layerCount; layer++) {
              expect(l.layerSize(layer), stageLayers[kind.index][layer]);
              for (
                var n = l.layerStart[layer];
                n < l.layerStart[layer + 1];
                n++
              ) {
                expect(l.layerOf[n], layer);
              }
            }

            // The content rectangle lies inside the view.
            expect(l.content.left, greaterThanOrEqualTo(0));
            expect(l.content.top, greaterThanOrEqualTo(0));
            expect(l.content.right, lessThanOrEqualTo(size.width));
            expect(l.content.bottom, lessThanOrEqualTo(size.height));

            if (l.isRings) {
              _expectRingsInside(l);
            } else {
              // Every body is inside the content rectangle.
              for (var n = 0; n < l.neuronCount; n++) {
                final e = _extent(l, n);
                expect(
                  l.x[n] - e,
                  greaterThanOrEqualTo(l.content.left - 1e-3),
                  reason: '$reason neuron $n left',
                );
                expect(
                  l.x[n] + e,
                  lessThanOrEqualTo(l.content.right + 1e-3),
                  reason: '$reason neuron $n right',
                );
                expect(
                  l.y[n] - e,
                  greaterThanOrEqualTo(l.content.top - 1e-3),
                  reason: '$reason neuron $n top',
                );
                expect(
                  l.y[n] + e,
                  lessThanOrEqualTo(l.content.bottom + 1e-3),
                  reason: '$reason neuron $n bottom',
                );
              }

              // Bodies keep at least 3 px between them.
              for (var i = 0; i < l.neuronCount; i++) {
                for (var j = i + 1; j < l.neuronCount; j++) {
                  final d = math.sqrt(
                    math.pow(l.x[i] - l.x[j], 2) + math.pow(l.y[i] - l.y[j], 2),
                  );
                  expect(
                    d,
                    greaterThanOrEqualTo(l.radius[i] + l.radius[j] + 3 - 1e-3),
                    reason: '$reason neurons $i and $j',
                  );
                }
              }

              // Positions are snapped to device pixels.
              for (var n = 0; n < l.neuronCount; n++) {
                expect(_snapped(l.x[n], dpr), isTrue, reason: '$reason x[$n]');
                expect(_snapped(l.y[n], dpr), isTrue, reason: '$reason y[$n]');
              }
              for (var layer = 0; layer < l.layerCount; layer++) {
                expect(_snapped(l.layerX[layer], dpr), isTrue);
              }
              expect(_snapped(l.captionY, dpr), isTrue);
            }

            // Building twice gives the same layout.
            _expectIdentical(
              l,
              NetworkLayout.build(topology, size, devicePixelRatio: dpr),
            );
          }
        });
      }
    }
  });

  group('edges', () {
    const wide = Size(720, 440), narrow = Size(390, 280);

    int edges(int stage, Size size) =>
        NetworkLayout.build(stageTopology(stage), size).edgeCount;

    test('have the documented counts', () {
      expect(edges(NetworkKind.perceptron.index, wide), 3);
      expect(edges(NetworkKind.mlp.index, wide), 25);
      expect(edges(NetworkKind.cnn.index, wide), 56);
      expect(edges(NetworkKind.rnn.index, wide), 105);
      expect(edges(NetworkKind.transformer.index, wide), 224);
      expect(edges(NetworkKind.llm.index, wide), 360);
      expect(edges(NetworkKind.agi.index, wide), 0); // rewired every frame
    });

    test('dense stages keep the full fan-in from 480 px up', () {
      const atThreshold = Size(kCompactWidth, 320);
      expect(edges(NetworkKind.transformer.index, atThreshold), 224);
      expect(edges(NetworkKind.llm.index, atThreshold), 360);
      for (final size in layoutSizes.where((s) => s.width >= kCompactWidth)) {
        expect(edges(NetworkKind.llm.index, size), 360);
      }
    });

    test(
      'dense stages keep the 4 strongest inputs per neuron below 480 px',
      () {
        for (final kind in const [
          NetworkKind.transformer,
          NetworkKind.llm,
          NetworkKind.multimodal,
        ]) {
          for (final size in layoutSizes.where(
            (s) => s.width < kCompactWidth,
          )) {
            final l = NetworkLayout.build(stageTopology(kind.index), size);
            final full = NetworkLayout.build(stageTopology(kind.index), wide);
            final fanIn = List.filled(l.neuronCount, 0);
            for (var e = 0; e < l.edgeCount; e++) {
              fanIn[l.edgeDst[e]]++;
            }
            final fullFanIn = List.filled(full.neuronCount, 0);
            for (var e = 0; e < full.edgeCount; e++) {
              fullFanIn[full.edgeDst[e]]++;
            }
            for (var n = l.layerStart[1]; n < l.neuronCount; n++) {
              expect(
                fanIn[n],
                math.min(4, fullFanIn[n]),
                reason: '${kind.name} ${size.width} neuron $n',
              );
            }
            // Kept edges are the strongest of the full fan-in (highways aside,
            // whose weights are re-drawn after selection).
            for (var n = l.layerStart[1]; n < l.neuronCount; n++) {
              final kept = <int>{
                for (var e = 0; e < l.edgeCount; e++)
                  if (l.edgeDst[e] == n) l.edgeSrc[e],
              };
              final all = <(int, double)>[
                for (var e = 0; e < full.edgeCount; e++)
                  if (full.edgeDst[e] == n && full.highway[e] == 0)
                    (full.edgeSrc[e], full.weight[e].abs()),
              ];
              final dropped = all.where((s) => !kept.contains(s.$1));
              final keptWeights = all.where((s) => kept.contains(s.$1));
              if (dropped.isEmpty || keptWeights.isEmpty) continue;
              final weakestKept = keptWeights.map((s) => s.$2).reduce(math.min);
              final strongestDropped = dropped
                  .map((s) => s.$2)
                  .reduce(math.max);
              expect(weakestKept, greaterThanOrEqualTo(strongestDropped));
            }
          }
        }
        expect(edges(NetworkKind.transformer.index, narrow), 6 * 4 + 8 * 4 * 3);
        expect(edges(NetworkKind.llm.index, narrow), 4 * (10 + 10 + 10 + 8));
      },
    );

    test('are well formed for every kind and size', () {
      for (final kind in NetworkKind.values) {
        for (final size in layoutSizes) {
          final l = NetworkLayout.build(stageTopology(kind.index), size);
          final seen = List.filled(l.edgeCount, 0);
          for (var n = 0; n < l.neuronCount; n++) {
            for (var i = l.outStart[n]; i < l.outStart[n + 1]; i++) {
              final e = l.outEdges[i];
              expect(l.edgeSrc[e], n);
              seen[e]++;
            }
          }
          expect(seen.every((s) => s == 1), isTrue);
          for (var e = 0; e < l.edgeCount; e++) {
            expect(l.layerOf[l.edgeDst[e]], l.layerOf[l.edgeSrc[e]] + 1);
            expect(l.weight[e], inInclusiveRange(-1.0, 1.0));
            if (e > 0) {
              // Ordered by layer pair, then by source.
              final a = l.edgeSrc[e - 1], b = l.edgeSrc[e];
              expect(
                l.layerOf[a] < l.layerOf[b] ||
                    (l.layerOf[a] == l.layerOf[b] && a <= b),
                isTrue,
              );
            }
          }
        }
      }
    });

    test('every output has a strong positive highway back to an input', () {
      for (final kind in NetworkKind.values.where(
        (k) => k != NetworkKind.agi,
      )) {
        final l = NetworkLayout.build(stageTopology(kind.index), wide);
        final last = l.layerCount - 1;
        for (var out = l.layerStart[last]; out < l.neuronCount; out++) {
          var node = out;
          var hops = 0;
          while (l.layerOf[node] > 0) {
            final e = Iterable<int>.generate(l.edgeCount).firstWhere(
              (e) => l.edgeDst[e] == node && l.highway[e] == 1,
              orElse: () => -1,
            );
            expect(e, isNot(-1), reason: '${kind.name}: no highway into $node');
            expect(l.weight[e], greaterThanOrEqualTo(0.8));
            node = l.edgeSrc[e];
            hops++;
          }
          expect(hops, last);
        }
      }
    });

    test('change with the seed', () {
      final a = NetworkLayout.build(stageTopology(4), wide);
      final b = NetworkLayout.build(stageTopology(4, seed: 7), wide);
      expect(a.edgeCount, b.edgeCount);
      expect(a.weight, isNot(equals(b.weight)));
      expect(a.x, b.x); // positions don't depend on the seed
    });
  });

  group('multimodal', () {
    test('encoder edges stay inside their modality lane', () {
      for (final size in layoutSizes) {
        final l = NetworkLayout.build(
          stageTopology(NetworkKind.multimodal.index),
          size,
        );
        // Group of each input; every encoder neuron is fed by one group.
        final laneOf = <int, int>{};
        for (var e = 0; e < l.edgeCount; e++) {
          final s = l.edgeSrc[e];
          if (l.layerOf[s] != 0) continue;
          final group = l.groupOf[s];
          expect(group, inInclusiveRange(0, 2));
          final d = l.edgeDst[e];
          expect(laneOf.putIfAbsent(d, () => group), group, reason: '$size');
        }
        expect(laneOf.length, l.layerSize(1));
        // Lanes are stacked top to bottom in group order, so no encoder edge
        // crosses into another lane.
        for (var g = 0; g < 2; g++) {
          final lowerOfG = [
            for (var n = 0; n < l.layerStart[1]; n++)
              if (l.groupOf[n] == g) l.y[n],
            for (final MapEntry(key: d, value: lane) in laneOf.entries)
              if (lane == g) l.y[d],
          ].reduce(math.max);
          final upperOfNext = [
            for (var n = 0; n < l.layerStart[1]; n++)
              if (l.groupOf[n] == g + 1) l.y[n],
            for (final MapEntry(key: d, value: lane) in laneOf.entries)
              if (lane == g + 1) l.y[d],
          ].reduce(math.min);
          expect(lowerOfG, lessThan(upperOfNext), reason: '$size lane $g');
        }
      }
    });

    test('inputs are split into text, image and audio shapes', () {
      final l = NetworkLayout.build(
        stageTopology(NetworkKind.multimodal.index),
        const Size(720, 440),
      );
      final groups = [for (var n = 0; n < 8; n++) l.groupOf[n]];
      expect(groups, [0, 0, 0, 1, 1, 1, 2, 2]);
      expect(
        [for (var n = 0; n < 8; n++) NeuronShape.values[l.shape[n]]],
        [
          ...List.filled(3, NeuronShape.circle),
          ...List.filled(3, NeuronShape.square),
          ...List.filled(2, NeuronShape.diamond),
        ],
      );
      for (var n = 8; n < l.neuronCount; n++) {
        expect(l.groupOf[n], -1);
      }
    });
  });

  group('AGI rings', () {
    test('radii increase and rings never overlap', () {
      for (final size in layoutSizes) {
        final l = NetworkLayout.build(
          stageTopology(NetworkKind.agi.index),
          size,
        );
        expect(l.isRings, isTrue);
        expect(l.ringRadius.length, l.layerCount);
        final r = l.r;
        // Front bodies are full size, back ones 0.85×; the squashed vertical
        // distance between two rings must fit two front bodies.
        expect(
          l.ringRadius[0] * kRingSquash - r,
          greaterThanOrEqualTo(l.coreRadius - 1e-3),
          reason: '$size: ring 0 touches the core',
        );
        for (var k = 0; k + 1 < l.layerCount; k++) {
          expect(l.ringRadius[k + 1], greaterThan(l.ringRadius[k]));
          expect(
            (l.ringRadius[k + 1] - l.ringRadius[k]) * kRingSquash,
            greaterThanOrEqualTo(2 * r - 1e-3),
            reason: '$size: rings $k and ${k + 1} overlap',
          );
        }
        // Neurons sit on their ring at their angle.
        final c = l.center;
        for (var n = 0; n < l.neuronCount; n++) {
          final k = l.layerOf[n];
          expect(
            l.x[n],
            closeTo(c.dx + l.ringRadius[k] * math.cos(l.ringAngle[n]), 1e-3),
          );
          expect(
            l.y[n],
            closeTo(
              c.dy + l.ringRadius[k] * kRingSquash * math.sin(l.ringAngle[n]),
              1e-3,
            ),
          );
        }
      }
    });

    test('rings alternate direction and outer rings turn faster', () {
      for (var k = 0; k < 7; k++) {
        final a = NetworkLayout.ringOmega(k),
            b = NetworkLayout.ringOmega(k + 1);
        expect(a.sign, -b.sign);
        expect(b.abs(), greaterThan(a.abs()));
      }
    });
  });

  group('captions', () {
    test('sit below the network and inside the view', () {
      for (final kind in NetworkKind.values) {
        for (final size in layoutSizes) {
          final l = NetworkLayout.build(stageTopology(kind.index), size);
          if (size.width < kCaptionMinWidth || kind == NetworkKind.agi) {
            expect(l.captions, isEmpty);
            continue;
          }
          expect(l.captions.length, l.layerCount);
          var lowest = 0.0;
          for (var n = 0; n < l.neuronCount; n++) {
            lowest = math.max(lowest, l.y[n] + _extent(l, n));
          }
          expect(l.captionY, greaterThanOrEqualTo(lowest + 4));
          // 9.5 px mono caption: about 12 px of line height.
          expect(l.captionY + 12, lessThanOrEqualTo(size.height));
        }
      }
    });

    test('are hidden on request', () {
      final l = NetworkLayout.build(
        stageTopology(1),
        const Size(720, 440),
        showCaptions: false,
      );
      expect(l.captions, isEmpty);
    });
  });

  group('unsupported topologies', () {
    test('every supported extreme lays out without overlap', () {
      for (final layers in const [
        [1, 1],
        [16, 16],
        [1, 16, 1],
        [16, 16, 16, 16, 16, 16, 16, 16],
      ]) {
        for (final kind in NetworkKind.values) {
          final l = NetworkLayout.build(
            NetworkTopology(kind: kind, layers: layers),
            const Size(720, 440),
          );
          expect(l.neuronCount, layers.reduce((a, b) => a + b));
          for (var n = 0; n < l.neuronCount; n++) {
            expect(l.x[n].isFinite && l.y[n].isFinite, isTrue);
            expect(l.radius[n], greaterThan(0));
          }
        }
      }
    });
  });
}

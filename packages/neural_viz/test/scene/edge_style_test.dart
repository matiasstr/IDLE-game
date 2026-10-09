import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/src/scene/edge_style.dart';

import '../helpers/viz_fixtures.dart';

void main() {
  group('EdgeStyle.contrast', () {
    const progressSteps = [0.0, 0.3, 0.6, 1.0];

    test('is quantized to 16 steps in [0, 1]', () {
      for (var a = 0; a <= 100; a++) {
        for (var p = 0; p <= 100; p += 5) {
          final c = EdgeStyle.contrast(a / 100, p / 100, false);
          expect(c, inInclusiveRange(0.0, 1.0));
          expect(c * 16, closeTo((c * 16).roundToDouble(), 1e-12));
        }
      }
    });

    test('rises with accuracy and with progress', () {
      for (var a = 0; a < 100; a++) {
        for (final p in progressSteps) {
          expect(
            EdgeStyle.contrast((a + 1) / 100, p, false),
            greaterThanOrEqualTo(EdgeStyle.contrast(a / 100, p, false)),
          );
        }
      }
      for (final a in stageThresholdAccuracy) {
        for (var i = 0; i + 1 < progressSteps.length; i++) {
          expect(
            EdgeStyle.contrast(a, progressSteps[i + 1], false),
            greaterThanOrEqualTo(
              EdgeStyle.contrast(a, progressSteps[i], false),
            ),
          );
        }
      }
    });

    test('every stage visibly re-learns from its threshold', () {
      // [stage][progress step] at the accuracy the stage starts with.
      const expected = [
        [0.0, 0.25, 0.5, 0.5], // perceptron: untrained
        [0.375, 0.625, 0.875, 0.875],
        [0.4375, 0.6875, 0.9375, 0.9375],
        [0.5, 0.75, 1.0, 1.0],
        [0.5, 0.75, 1.0, 1.0],
        [0.5, 0.75, 1.0, 1.0],
        [0.5, 0.75, 1.0, 1.0],
      ];
      for (var stage = 0; stage < expected.length; stage++) {
        for (var i = 0; i < progressSteps.length; i++) {
          expect(
            EdgeStyle.contrast(
              stageThresholdAccuracy[stage],
              progressSteps[i],
              false,
            ),
            expected[stage][i],
            reason: 'stage $stage, progress ${progressSteps[i]}',
          );
        }
        // Just reached: never looks fully trained yet.
        expect(
          EdgeStyle.contrast(stageThresholdAccuracy[stage], 0, false),
          lessThanOrEqualTo(0.5),
        );
      }
    });

    test('the last stage looks fully learned whatever progress says', () {
      final a = stageThresholdAccuracy.last;
      for (final p in progressSteps) {
        expect(EdgeStyle.contrast(a, p, true), 1.0);
      }
      for (var a = 0; a <= 10; a++) {
        expect(
          EdgeStyle.contrast(a / 10, 0, true),
          EdgeStyle.contrast(a / 10, 1, false),
        );
      }
    });
  });

  group('EdgeStyle.strength', () {
    test('untrained weights all look alike', () {
      for (final w in const [-1.0, -0.5, 0.0, 0.3, 1.0]) {
        expect(EdgeStyle.strength(w, 0), closeTo(0.42, 1e-12));
      }
    });

    test('trained weights separate into strong and faint', () {
      expect(EdgeStyle.strength(1, 1), closeTo(1, 1e-12));
      expect(EdgeStyle.strength(-1, 1), closeTo(1, 1e-12));
      expect(EdgeStyle.strength(0, 1), closeTo(0, 1e-12));
      expect(
        EdgeStyle.strength(0.9, 1),
        greaterThan(EdgeStyle.strength(0.2, 1)),
      );
      expect(EdgeStyle.isWide(EdgeStyle.strength(0.95, 1)), isTrue);
      expect(EdgeStyle.isWide(EdgeStyle.strength(0.95, 0)), isFalse);
    });
  });

  group('EdgeStyle.alpha and level', () {
    test('alpha spans the quantized levels', () {
      expect(EdgeStyle.alpha(0), closeTo(0.05, 1e-12));
      expect(EdgeStyle.alpha(1), closeTo(0.45, 1e-12));
      expect(EdgeStyle.alpha(0, highContrast: true), 0.12);
      expect(EdgeStyle.level(EdgeStyle.alpha(0)), 0);
      expect(EdgeStyle.level(EdgeStyle.alpha(1)), EdgeStyle.levels.length - 1);
    });

    test('level picks the closest quantized alpha', () {
      for (var i = 0; i < EdgeStyle.levels.length; i++) {
        expect(EdgeStyle.level(EdgeStyle.levels[i]), i);
      }
      for (var a = 0; a <= 100; a++) {
        final level = EdgeStyle.level(a / 100);
        final d = (EdgeStyle.levels[level] - a / 100).abs();
        for (final other in EdgeStyle.levels) {
          expect(d, lessThanOrEqualTo((other - a / 100).abs() + 1e-12));
        }
      }
    });
  });
}

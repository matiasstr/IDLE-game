import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';

double _pow10(num exponent) => math.pow(10, exponent).toDouble();

void main() {
  group('productionEnergy', () {
    test('matches the documented table', () {
      expect(productionEnergy(0.5), closeTo(0.016, 0.0005));
      expect(productionEnergy(1e3), closeTo(0.28, 1e-9));
      expect(productionEnergy(1e6), closeTo(0.52, 1e-9));
      expect(productionEnergy(1e12), closeTo(1.0, 1e-9));
    });

    test('is a log scale: each decade adds 0.08', () {
      for (var d = 0; d < 11; d++) {
        final lo = productionEnergy(_pow10(d));
        final hi = productionEnergy(_pow10(d + 1));
        expect(hi - lo, closeTo(0.08, 1e-9), reason: '1e$d → 1e${d + 1}');
      }
    });

    test('is monotonic and stays in [0, 1]', () {
      var previous = -1.0;
      for (var i = -40; i <= 160; i++) {
        final v = productionEnergy(_pow10(i / 10));
        expect(v, inInclusiveRange(0.0, 1.0));
        expect(v, greaterThanOrEqualTo(previous));
        previous = v;
      }
    });

    test('saturates above 1e12 tokens per second', () {
      expect(productionEnergy(1e15), 1);
      expect(productionEnergy(1e300), 1);
    });

    test('is safe for zero, negative, NaN and infinite rates', () {
      expect(productionEnergy(0), 0);
      expect(productionEnergy(-0.0), 0);
      expect(productionEnergy(-5), 0);
      expect(productionEnergy(double.negativeInfinity), 0);
      expect(productionEnergy(double.nan), 0);
      expect(productionEnergy(double.infinity), 1);
      expect(productionEnergy(double.maxFinite), 1);
      expect(productionEnergy(double.minPositive), 0);
      expect(productionEnergy(0.1), 0);
    });
  });
}

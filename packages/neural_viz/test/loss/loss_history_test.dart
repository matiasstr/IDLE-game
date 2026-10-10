import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:neural_viz/src/scene/hash.dart';

/// Engine-like loss for sample [i]: falls from ln 10 toward 0.
double engineLoss(int i) {
  final log10Tokens = 15 * math.pow(i / 4000, 0.75);
  return -math.log(1 - 0.9 * math.exp(-log10Tokens / 3));
}

List<double> pointsOf(LossHistory h) => [
  for (var i = 0; i < h.length; i++) h[i],
];

double mean(List<double> values) =>
    values.fold<double>(0, (a, b) => a + b) / values.length;

/// A JSON round trip through text, as a save file does.
LossHistory roundTrip(LossHistory h) => LossHistory.fromJson(
  jsonDecode(jsonEncode(h.toJson())) as Map<String, Object?>,
);

void main() {
  group('add', () {
    test('commits one point per sample before the first decimation', () {
      final h = LossHistory(noise: 0);
      expect(h.length, 0);
      expect(h.latest, isNull);
      expect(h.first, isNull);
      h
        ..add(2.3)
        ..add(1.5)
        ..add(0.9);
      expect(pointsOf(h), [2.3, 1.5, 0.9]);
      expect(h.first, 2.3);
      expect(h.latest, 0.9);
      expect(h.samplesPerPoint, 1);
    });

    test('ignores NaN, infinities, zero and negative values', () {
      final h = LossHistory()..add(1);
      final version = h.version;
      var notified = 0;
      h.addListener(() => notified++);
      for (final v in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
        0.0,
        -0.0,
        -1.0,
      ]) {
        h.add(v);
      }
      expect(h.length, 1);
      expect(h.latest, 1);
      expect(h.version, version);
      expect(notified, 0);
    });

    test('stores loss·(1 + noise·(2h − 1)) with h hashed from the serial', () {
      final h = LossHistory(noise: 0.1, seed: 42);
      for (var i = 0; i < 40; i++) {
        h.add(0.5);
      }
      for (var i = 0; i < 40; i++) {
        final expected = 0.5 * (1 + 0.1 * (2 * hash01(42, i, 0) - 1));
        expect(h[i], closeTo(expected, 1e-15));
        expect(h[i], inInclusiveRange(0.45, 0.55));
      }
      // The raw values carry no jitter.
      expect(h.latest, 0.5);
      expect(h.first, 0.5);
    });

    test('different seeds give different jitter', () {
      final a = LossHistory(seed: 1);
      final b = LossHistory(seed: 2);
      for (var i = 0; i < 20; i++) {
        a.add(1);
        b.add(1);
      }
      expect(pointsOf(a), isNot(pointsOf(b)));
    });

    test('operator [] range-checks against length', () {
      final h = LossHistory()..add(1);
      expect(() => h[1], throwsRangeError);
      expect(() => h[-1], throwsRangeError);
    });
  });

  group('decimation', () {
    test('never exceeds capacity and never empties', () {
      for (final capacity in [16, 18, 64, 256]) {
        final h = LossHistory(capacity: capacity);
        for (var i = 0; i < 20000; i++) {
          h.add(engineLoss(i));
          expect(h.length, lessThan(capacity));
          expect(
            h.length,
            greaterThanOrEqualTo(math.min(i + 1, capacity ~/ 2)),
          );
        }
      }
    });

    test('halves the points and doubles samplesPerPoint at capacity', () {
      final h = LossHistory(capacity: 16, noise: 0);
      for (var i = 0; i < 15; i++) {
        h.add(i + 1.0);
      }
      expect(h.length, 15);
      expect(h.samplesPerPoint, 1);
      h.add(16);
      expect(h.length, 8);
      expect(h.samplesPerPoint, 2);
      expect(pointsOf(h), [1.5, 3.5, 5.5, 7.5, 9.5, 11.5, 13.5, 15.5]);
    });

    test('preserves the mean of every committed sample', () {
      for (final noise in [0.0, 0.04, 0.3]) {
        final h = LossHistory(capacity: 16, noise: noise, seed: 3);
        final jittered = <double>[];
        for (var i = 0; i < 3000; i++) {
          final loss = engineLoss(i);
          h.add(loss);
          jittered.add(loss * (1 + noise * (2 * hash01(3, i, 0) - 1)));
          // Every point covers samplesPerPoint samples, so the points'
          // mean is the mean of the samples committed so far.
          final committed = h.length * h.samplesPerPoint;
          expect(
            mean(pointsOf(h)),
            closeTo(mean(jittered.sublist(0, committed)), 1e-12),
          );
        }
        expect(h.samplesPerPoint, greaterThan(64));
      }
    });

    test('halves marker indices', () {
      final h = LossHistory(capacity: 16, noise: 0);
      for (var i = 0; i < 5; i++) {
        h.add(1);
      }
      h
        ..mark('MLP')
        ..add(1);
      expect(h.markers, [const LossMarker(5, 'MLP')]);
      for (var i = 0; i < 8; i++) {
        h.add(1);
      }
      h.mark('CNN');
      expect(h.length, 14);
      h.add(1);
      expect(h.markers, [
        const LossMarker(5, 'MLP'),
        const LossMarker(14, 'CNN'),
      ]);
      h
        ..mark('RNN')
        ..add(1); // commits point 15 and decimates
      expect(h.length, 8);
      expect(h.markers, [
        const LossMarker(2, 'MLP'),
        const LossMarker(7, 'CNN'),
        const LossMarker(7, 'RNN'),
      ]);
    });

    test('a mark waits for the next committed point', () {
      final h = LossHistory(capacity: 16);
      for (var i = 0; i < 16; i++) {
        h.add(1);
      }
      expect(h.samplesPerPoint, 2);
      h
        ..mark('CNN')
        ..add(1); // pending: 1 of 2
      expect(h.markers, isEmpty);
      h.add(1);
      expect(h.markers, [LossMarker(h.length - 1, 'CNN')]);
    });

    test('keeps at most maxMarkers markers, dropping the oldest', () {
      final h = LossHistory();
      for (var i = 0; i < LossHistory.maxMarkers + 5; i++) {
        h
          ..mark('m$i')
          ..add(1);
      }
      expect(h.markers.length, LossHistory.maxMarkers);
      expect(h.markers.first.label, 'm5');
      expect(h.markers.last.label, 'm${LossHistory.maxMarkers + 4}');
    });

    test('markers are read-only', () {
      final h = LossHistory();
      expect(
        () => h.markers.add(const LossMarker(0, 'x')),
        throwsUnsupportedError,
      );
    });
  });

  group('noise stability', () {
    test('a sample keeps its jitter across decimation', () {
      // Capacity 16 folds one more time than capacity 32 for the same
      // samples, so its points are pair averages of the larger buffer's.
      final small = LossHistory(capacity: 16, noise: 0.2, seed: 9);
      final large = LossHistory(capacity: 32, noise: 0.2, seed: 9);
      for (var i = 0; i < 32; i++) {
        small.add(engineLoss(i));
        large.add(engineLoss(i));
      }
      expect(small.samplesPerPoint, 4);
      expect(large.samplesPerPoint, 2);
      expect(large.length, 2 * small.length);
      for (var i = 0; i < small.length; i++) {
        expect(small[i], closeTo((large[2 * i] + large[2 * i + 1]) / 2, 1e-15));
      }
    });

    test('a JSON round trip at any moment gives the same points', () {
      final reference = LossHistory(capacity: 16, noise: 0.15, seed: 5);
      for (var i = 0; i < 700; i++) {
        if (i == 100 || i == 400) reference.mark('s$i');
        reference.add(engineLoss(i));
      }

      // Round trips land before, during and after decimations, and while a
      // point is half filled.
      for (final cut in [1, 15, 16, 17, 99, 100, 101, 333, 699]) {
        var h = LossHistory(capacity: 16, noise: 0.15, seed: 5);
        for (var i = 0; i < 700; i++) {
          if (i == cut) h = roundTrip(h);
          if (i == 100 || i == 400) h.mark('s$i');
          h.add(engineLoss(i));
        }
        expect(pointsOf(h), pointsOf(reference), reason: 'cut at $cut');
        expect(h.markers, reference.markers, reason: 'cut at $cut');
        expect(h.samplesPerPoint, reference.samplesPerPoint);
      }
    });

    test('a new run wiggles differently', () {
      final h = LossHistory(noise: 0.2);
      for (var i = 0; i < 20; i++) {
        h.add(1);
      }
      final firstRun = pointsOf(h);
      h.startRun();
      for (var i = 0; i < 20; i++) {
        h.add(1);
      }
      expect(pointsOf(h), isNot(firstRun));
    });
  });

  group('startRun', () {
    test('clears points, markers, first, latest and pending state', () {
      final h = LossHistory(capacity: 16, noise: 0);
      for (var i = 0; i < 40; i++) {
        if (i == 20) h.mark('CNN');
        h.add(2.0 - i * 0.01);
      }
      h
        ..add(0.1) // pending sample
        ..mark('RNN'); // pending mark
      expect(h.samplesPerPoint, greaterThan(1));
      final version = h.version;
      var notified = 0;
      h.addListener(() => notified++);

      h.startRun();
      expect(notified, 1);
      expect(h.version, greaterThan(version));
      expect(h.length, 0);
      expect(h.markers, isEmpty);
      expect(h.first, isNull);
      expect(h.latest, isNull);
      expect(h.samplesPerPoint, 1);

      // No pending sample or mark leaks into the new run.
      h.add(3);
      expect(pointsOf(h), [3.0]);
      expect(h.first, 3);
      expect(h.markers, isEmpty);
    });
  });

  group('fromJson rejects out-of-range data', () {
    test('a huge capacity or a bogus samplesPerPoint is a FormatException', () {
      final base = LossHistory(capacity: 16).toJson();
      for (final patch in <Map<String, Object?>>[
        {'capacity': 1 << 40},
        {'samplesPerPoint': 1e300},
        {'samplesPerPoint': 3},
        {'samplesPerPoint': 1 << 30},
      ]) {
        expect(
          () => LossHistory.fromJson({...base, ...patch}),
          throwsFormatException,
          reason: '$patch',
        );
      }
    });
  });

  group('notifications', () {
    test('exactly one per accepted sample, none for marks', () {
      const capacity = 16;
      final h = LossHistory(capacity: capacity);
      var notified = 0;
      h.addListener(() => notified++);

      // Independent model of the commit schedule.
      var spp = 1;
      var pending = 0;
      var length = 0;
      var commits = 0;
      for (var i = 0; i < 5000; i++) {
        if (i % 97 == 0) h.mark('m$i'); // never notifies
        final before = notified;
        h.add(engineLoss(i));
        pending++;
        final commit = pending == spp;
        if (commit) {
          commits++;
          pending = 0;
          length++;
          if (length == capacity) {
            length ~/= 2;
            spp *= 2;
          }
        }
        expect(notified - before, 1, reason: 'sample $i');
        expect(h.length, length);
        expect(h.samplesPerPoint, spp);
      }
      expect(commits, greaterThan(0));
      expect(notified, 5000);
    });

    test('version changes on every accepted sample and mark', () {
      final h = LossHistory(capacity: 16);
      for (var i = 0; i < 16; i++) {
        h.add(1);
      }
      expect(h.samplesPerPoint, 2);
      var v = h.version;
      h.add(1); // pending only
      expect(h.version, greaterThan(v));
      v = h.version;
      h.mark('x');
      expect(h.version, greaterThan(v));
    });
  });

  group('JSON', () {
    test('round-trips every field', () {
      final h = LossHistory(capacity: 32, noise: 0.07, seed: 11);
      for (var i = 0; i < 150; i++) {
        if (i == 30) h.mark('MLP');
        h.add(engineLoss(i));
      }
      h
        ..add(0.2)
        ..mark('CNN');
      final copy = roundTrip(h);
      expect(copy.capacity, 32);
      expect(copy.noise, 0.07);
      expect(copy.seed, 11);
      expect(copy.length, h.length);
      expect(pointsOf(copy), pointsOf(h));
      expect(copy.samplesPerPoint, h.samplesPerPoint);
      expect(copy.first, h.first);
      expect(copy.latest, h.latest);
      expect(copy.markers, h.markers);
      expect(copy.toJson(), h.toJson());
    });

    test('an empty history round-trips', () {
      final copy = roundTrip(LossHistory());
      expect(copy.length, 0);
      expect(copy.first, isNull);
      expect(copy.latest, isNull);
      expect(copy.capacity, 256);
      expect(copy.noise, 0.04);
    });

    test('accepts integers where doubles are expected', () {
      // dart2js encodes 2.0 as "2".
      final h = LossHistory.fromJson(<String, Object?>{
        'capacity': 16,
        'noise': 0,
        'points': [2, 1, 0.5],
        'first': 2,
        'latest': 1,
      });
      expect(pointsOf(h), [2.0, 1.0, 0.5]);
      expect(h.first, 2.0);
    });

    test('repairs values it cannot draw', () {
      final h = LossHistory.fromJson(<String, Object?>{
        'capacity': 16,
        'points': [1.0, -1.0, 0.0, 0.5, double.infinity, double.nan],
        'markers': [
          {'index': 99, 'label': 'late'},
        ],
        'first': -3,
      });
      expect(pointsOf(h), [1.0, 0.5]);
      expect(h.markers, [const LossMarker(1, 'late')]);
      expect(h.first, isNull);
    });

    test('folds a save with too many points', () {
      final h = LossHistory.fromJson(<String, Object?>{
        'capacity': 16,
        'noise': 0,
        'points': [for (var i = 0; i < 20; i++) i + 1.0],
        'markers': [
          {'index': 18, 'label': 'x'},
        ],
      });
      expect(h.length, lessThan(16));
      expect(h.samplesPerPoint, 2);
      expect(h[0], 1.5);
      expect(h.markers.single.index, 9);
    });

    test('throws FormatException on malformed input', () {
      final bad = <Map<String, Object?>>[
        {'capacity': 15},
        {'capacity': 8},
        {'capacity': 'big'},
        {'noise': 2},
        {'points': 'nope'},
        {
          'points': ['a'],
        },
        {
          'markers': [3],
        },
        {
          'markers': [
            {'index': 'a', 'label': 'x'},
          ],
        },
        {
          'markers': [
            {'index': double.nan, 'label': 'x'},
          ],
        },
        {
          'pendingMarks': [1],
        },
        {'format': 2},
      ];
      for (final json in bad) {
        expect(
          () => LossHistory.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/src/scene/hash.dart';
import 'package:neural_viz/src/scene/tap_tracker.dart';

/// Wave start times recorded by [tracker] so far (watched after each
/// update, since the ring forgets old waves).
class _Recorder {
  _Recorder(this.tracker);

  final TapTracker tracker;
  final starts = <double>[];
  final _seen = <(double, int)>{};

  void update(double t, int count) {
    tracker.update(t, count);
    _collect();
  }

  void tap(double t) {
    tracker.tap(t);
    _collect();
  }

  void _collect() {
    for (var i = 0; i < TapTracker.maxWaves; i++) {
      final start = tracker.waveStart[i];
      if (start.isFinite && _seen.add((start, tracker.waveSerial[i]))) {
        starts.add(start);
      }
    }
  }

  /// Most wave starts inside any window of [length] seconds.
  int maxStartsWithin(double length) {
    final sorted = [...starts]..sort();
    var best = 0;
    for (var i = 0; i < sorted.length; i++) {
      var j = i;
      while (j < sorted.length && sorted[j] - sorted[i] <= length) {
        j++;
      }
      best = math.max(best, j - i);
    }
    return best;
  }
}

double _closedFormHeat(List<double> taps, double t) {
  var sum = 0.0;
  for (final ti in taps) {
    if (t >= ti) sum += 0.12 * math.exp(-(t - ti) / 0.8);
  }
  return math.min(1, sum);
}

void main() {
  group('TapTracker baseline', () {
    test('the first value fires nothing, however large', () {
      final taps = TapTracker()..update(1, 5000);
      expect(taps.serial, 0);
      expect(taps.aliveWaves(1), 0);
      expect(taps.heat(1), 0);
    });

    test('a decrease only re-baselines', () {
      final taps = TapTracker()
        ..update(0, 50)
        ..update(1, 10);
      expect(taps.serial, 0);
      expect(taps.aliveWaves(1), 0);
      expect(taps.heat(1), 0);
      // The next increase counts from the new baseline.
      taps.update(2, 11);
      expect(taps.serial, 1);
      expect(taps.aliveWaves(2), 1);
    });

    test('an unchanged value fires nothing', () {
      final taps = TapTracker()
        ..update(0, 3)
        ..update(1, 3)
        ..update(2, 3);
      expect(taps.serial, 0);
    });

    test('+1 fires exactly one wave', () {
      final taps = TapTracker()
        ..update(0, 10)
        ..update(1, 11);
      expect(taps.serial, 1);
      expect(taps.aliveWaves(1), 1);
      expect(taps.aliveWaves(1 + TapTracker.waveLife - 0.001), 1);
      expect(taps.aliveWaves(1 + TapTracker.waveLife), 0);
      expect(taps.heat(1), closeTo(0.12, 1e-12));
      final slot = taps.waveStart.indexOf(1);
      expect(slot, isNot(-1));
      expect(taps.waveAmp[slot], 1);
      expect(taps.waveSerial[slot], 1);
    });

    test('+2 and +3 fire one wave with a stronger amplitude', () {
      for (final delta in const [2, 3]) {
        final taps = TapTracker()
          ..update(0, 0)
          ..update(1, delta);
        expect(taps.serial, delta);
        expect(taps.aliveWaves(1), 1);
        final slot = taps.waveStart.indexOf(1);
        expect(taps.waveAmp[slot], closeTo(1 + 0.35 * (delta - 1), 1e-12));
        expect(taps.heat(1), closeTo(0.12 * delta, 1e-12));
      }
    });

    test('a jump of more than 3 fires one wave and the rest as heat', () {
      final taps = TapTracker()
        ..update(0, 100)
        ..update(1, 105);
      expect(taps.aliveWaves(1), 1);
      expect(taps.serial, 1);
      expect(taps.heat(1), closeTo(5 * 0.12, 1e-12));
      final slot = taps.waveStart.indexOf(1);
      expect(taps.waveAmp[slot], 1);

      // A jump no human can tap (a restored or imported save) only moves
      // the baseline: no wave, no heat.
      final big = TapTracker()
        ..update(0, 0)
        ..update(1, TapTracker.maxTapsPerUpdate + 1);
      expect(big.aliveWaves(1), 0);
      expect(big.heat(1), 0);
      big.update(2, TapTracker.maxTapsPerUpdate + 2);
      expect(big.aliveWaves(2), 1, reason: 'taps after the jump still count');
    });
  });

  group('TapTracker rate limits', () {
    test('20 taps in one second start at most 3 waves', () {
      final rec = _Recorder(TapTracker());
      rec.update(0, 0);
      for (var i = 1; i <= 20; i++) {
        rec.update(i * 0.05, i);
      }
      expect(rec.starts.length, lessThanOrEqualTo(3));
      expect(rec.maxStartsWithin(1.0), lessThanOrEqualTo(3));
    });

    test('no second ever holds more than 3 wave starts', () {
      // Tapping exactly at the minimum spacing, and random bursts.
      final sequences = <List<double>>[
        [for (var i = 0; i < 40; i++) i / 3],
        [for (var i = 0; i < 40; i++) i * TapTracker.minWaveGap],
        [for (var i = 0; i < 100; i++) i * 0.1],
        for (var seed = 0; seed < 50; seed++)
          [for (var i = 0, t = 0.0; i < 80; i++, t += hash01(seed, i) * 0.4) t],
      ];
      for (final sequence in sequences) {
        final rec = _Recorder(TapTracker());
        for (final t in sequence) {
          rec.tap(t);
        }
        expect(
          rec.maxStartsWithin(1.0),
          lessThanOrEqualTo(3),
          reason: 'starts ${rec.starts}',
        );
        // Feedback flashes (prediction checks) follow the starts, so they
        // are at least 250 ms apart too.
        final sorted = [...rec.starts]..sort();
        for (var i = 1; i < sorted.length; i++) {
          expect(sorted[i] - sorted[i - 1], greaterThanOrEqualTo(0.25));
        }
      }
    });

    test('at most 4 waves are alive at once', () {
      for (var seed = 0; seed < 30; seed++) {
        final taps = TapTracker();
        var t = 0.0;
        for (var i = 0; i < 200; i++) {
          t += hash01(seed, i) * 0.2;
          taps.tap(t);
          expect(taps.aliveWaves(t), lessThanOrEqualTo(TapTracker.maxWaves));
          expect(taps.aliveWaves(t), greaterThanOrEqualTo(1));
        }
      }
    });

    test('taps that cannot start a wave boost the newest one, capped', () {
      final taps = TapTracker()..tap(0);
      for (var i = 1; i <= 10; i++) {
        taps.tap(i * 0.01);
      }
      final slot = taps.waveStart.indexOf(0);
      expect(taps.waveAmp[slot], closeTo(1.7, 1e-12));
      expect(taps.aliveWaves(0.1), 1);
      // Later taps inside the gap only add heat.
      taps.tap(0.2);
      expect(taps.aliveWaves(0.2), 1);
      expect(taps.waveAmp[slot], closeTo(1.7, 1e-12));
      expect(taps.serial, 12);
    });
  });

  group('TapTracker heat', () {
    test('matches the closed form', () {
      final times = <double>[];
      final taps = TapTracker();
      var t = 0.0;
      for (var i = 0; i < 25; i++) {
        t += hash01(5, i) * 0.6;
        times.add(t);
        taps.tap(t);
      }
      for (var probe = 0.0; probe < t + 3; probe += 0.05) {
        expect(taps.heat(probe), closeTo(_closedFormHeat(times, probe), 1e-12));
      }
    });

    test('is about 0.45 at 4 taps per second and 1 at 10', () {
      double steady(double rate) {
        final taps = TapTracker();
        for (var i = 0; i < 60; i++) {
          taps.tap(i / rate);
        }
        return taps.heat(59 / rate);
      }

      expect(steady(4), closeTo(0.45, 0.04));
      expect(steady(10), 1);
    });

    test('never exceeds 1 and decays to 0', () {
      final taps = TapTracker();
      for (var i = 0; i < 500; i++) {
        taps.tap(i * 0.01);
        expect(taps.heat(i * 0.01), lessThanOrEqualTo(1));
      }
      expect(taps.heat(5), 1);
      expect(taps.heat(30), lessThan(1e-6));
    });
  });
}

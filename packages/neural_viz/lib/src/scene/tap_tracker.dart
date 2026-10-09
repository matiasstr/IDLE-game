import 'dart:math' as math;
import 'dart:typed_data';

/// Turns a monotonic training counter into training waves and "heat".
///
/// - The first value and any decrease only set the baseline, so loading a
///   save never fires a burst.
/// - At most one wave starts every [minWaveGap] seconds (3 per second, safe
///   for photosensitive viewers) and at most [maxWaves] are alive. Extra taps
///   boost the newest wave or just heat the network.
class TapTracker {
  static const minWaveGap = 0.333;
  static const maxWaves = 4;
  static const waveLife = 1.0;
  static const _heatPerTap = 0.12, _heatTau = 0.8;
  static const _heatSlots = 32;

  int? _baseline;
  int _serial = 0;

  final Float64List _heatTimes = Float64List(_heatSlots)
    ..fillRange(0, _heatSlots, double.negativeInfinity);
  int _heatNext = 0;

  /// Wave ring: start time, amplitude and serial.
  final Float64List waveStart = Float64List(maxWaves)
    ..fillRange(0, maxWaves, double.negativeInfinity);
  final Float64List waveAmp = Float64List(maxWaves);
  final Int32List waveSerial = Int32List(maxWaves);
  int _waveNext = 0;
  double _lastWave = double.negativeInfinity;

  /// Number of taps ever registered (not reset by re-baselining).
  int get serial => _serial;

  /// Feeds the latest counter value seen at scene time [t].
  void update(double t, int count) {
    final baseline = _baseline;
    _baseline = count;
    if (baseline == null || count <= baseline) return;
    final delta = count - baseline;
    if (delta > 3) {
      tap(t);
      for (var i = 1; i < math.min(delta, _heatSlots); i++) {
        _addHeat(t);
      }
    } else {
      for (var i = 0; i < delta; i++) {
        tap(t);
      }
    }
  }

  /// Registers one manual training step at [t].
  void tap(double t) {
    _serial++;
    _addHeat(t);
    if (t - _lastWave >= minWaveGap && aliveWaves(t) < maxWaves) {
      final slot = _waveNext;
      _waveNext = (_waveNext + 1) % maxWaves;
      waveStart[slot] = t;
      waveAmp[slot] = 1;
      waveSerial[slot] = _serial;
      _lastWave = t;
    } else if (t - _lastWave < 0.150) {
      final newest = (_waveNext + maxWaves - 1) % maxWaves;
      waveAmp[newest] = math.min(1.7, waveAmp[newest] + 0.35);
    }
  }

  void _addHeat(double t) {
    _heatTimes[_heatNext] = t;
    _heatNext = (_heatNext + 1) % _heatSlots;
  }

  int aliveWaves(double t) {
    var alive = 0;
    for (var i = 0; i < maxWaves; i++) {
      final age = t - waveStart[i];
      if (age >= 0 && age < waveLife) alive++;
    }
    return alive;
  }

  /// 0–1: about 0.45 when tapping 4 times per second, 1 at 10 per second.
  double heat(double t) {
    var sum = 0.0;
    for (var i = 0; i < _heatSlots; i++) {
      final age = t - _heatTimes[i];
      if (age >= 0) sum += _heatPerTap * math.exp(-age / _heatTau);
    }
    return math.min(1, sum);
  }
}

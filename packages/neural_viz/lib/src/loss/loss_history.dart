import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../scene/hash.dart';

/// Training-loss samples of the current run, in fixed memory.
///
/// Feed it once per second of play with `add(engine.loss(state))`, call
/// [mark] when a stage is reached and [startRun] when a paper is published.
/// `LossChart` draws it. Persist it with [toJson] and [LossHistory.fromJson].
///
/// Memory never grows: at most [capacity] points are kept. When the buffer
/// fills up, neighbouring points are averaged in pairs, so the whole run
/// always fits and the curve keeps its shape; every point then stands for
/// twice as many samples ([samplesPerPoint]).
class LossHistory extends ChangeNotifier {
  LossHistory({this.capacity = 256, this.noise = 0.04, this.seed = 0})
    : assert(capacity >= 16 && capacity.isEven),
      assert(noise >= 0 && noise < 1),
      _points = Float64List(capacity);

  /// Restores a history saved with [toJson].
  ///
  /// Throws a [FormatException] when [json] is not a saved history. Values
  /// that cannot be drawn (non-finite or non-positive points) are dropped and
  /// out-of-range marker indices are clamped, so a hand-edited save still
  /// loads.
  factory LossHistory.fromJson(Map<String, Object?> json) {
    final format = _readInt(json, 'format', 1);
    if (format != 1) {
      throw FormatException('Unsupported LossHistory format $format');
    }
    final capacity = _readInt(json, 'capacity', 256);
    if (capacity < 16 || capacity.isOdd) {
      throw FormatException('Invalid LossHistory capacity $capacity');
    }
    final noise = _readDouble(json, 'noise') ?? 0.04;
    if (!(noise >= 0 && noise < 1)) {
      throw FormatException('Invalid LossHistory noise $noise');
    }
    final history = LossHistory(
      capacity: capacity,
      noise: noise,
      seed: _readInt(json, 'seed', 0),
    );
    history
      .._run = _readInt(json, 'run', 0)
      .._serial = _readInt(json, 'serial', 0)
      .._samplesPerPoint = _readInt(json, 'samplesPerPoint', 1)
      .._first = _readPositive(json, 'first')
      .._latest = _readPositive(json, 'latest');
    if (history._samplesPerPoint < 1) history._samplesPerPoint = 1;

    final points = _readList(json, 'points');
    var folds = 0;
    for (var i = 0; i < points.length; i++) {
      final value = points[i];
      if (value is! num) {
        throw const FormatException('LossHistory points must be numbers');
      }
      final v = value.toDouble();
      if (!v.isFinite || v <= 0) continue;
      history._points[history._length++] = v;
      // More points than fit (a hand-edited save): fold them like add does.
      if (history._length == capacity) {
        history._decimate();
        folds++;
      }
    }

    final pendingCount = _readInt(json, 'pendingCount', 0);
    final pendingSum = _readDouble(json, 'pendingSum') ?? 0;
    if (pendingCount > 0 &&
        pendingCount < history._samplesPerPoint &&
        pendingSum.isFinite &&
        pendingSum > 0) {
      history
        .._pendingCount = pendingCount
        .._pendingSum = pendingSum;
    }

    final markers = _readList(json, 'markers');
    for (var i = 0; i < markers.length; i++) {
      final entry = markers[i];
      if (entry is! Map) {
        throw const FormatException('LossHistory markers must be objects');
      }
      final index = entry['index'];
      final label = entry['label'];
      if (index is! num || !index.isFinite || label is! String) {
        throw const FormatException('Invalid LossHistory marker');
      }
      if (history._length == 0) continue;
      final clamped = (index.toInt() >> folds).clamp(0, history._length - 1);
      history._addMarker(LossMarker(clamped, label));
    }

    final pendingMarks = _readList(json, 'pendingMarks');
    for (var i = 0; i < pendingMarks.length; i++) {
      final label = pendingMarks[i];
      if (label is! String) {
        throw const FormatException('LossHistory pendingMarks must be strings');
      }
      history.mark(label);
    }
    return history;
  }

  /// Most points kept. Even and at least 16.
  final int capacity;

  /// Cosmetic minibatch jitter. Each sample is stored as
  /// `loss·(1 + noise·(2h−1))`, with h hashed from the sample's serial number,
  /// so it is stable across decimation and reloads. 0 disables it.
  final double noise;

  /// Varies the jitter pattern.
  final int seed;

  /// Upper bound on [markers]; the oldest is dropped beyond it.
  static const int maxMarkers = 32;

  final Float64List _points;
  int _length = 0;
  int _samplesPerPoint = 1;
  double _pendingSum = 0;
  int _pendingCount = 0;

  /// Samples added in this run; hashed for the jitter.
  int _serial = 0;

  /// Runs started; hashed for the jitter so each run wiggles differently.
  int _run = 0;

  double? _first;
  double? _latest;
  int _version = 0;

  final List<LossMarker> _markers = <LossMarker>[];
  late final List<LossMarker> _markersView = UnmodifiableListView(_markers);
  final List<String> _pendingMarks = <String>[];

  /// Number of stored points, at most `capacity − 1`.
  int get length => _length;

  /// Stored (jittered, averaged) value of point [index], oldest first.
  double operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    return _points[index];
  }

  /// Last raw value passed to [add] (no jitter), or null.
  double? get latest => _latest;

  /// First raw value of this run, used for the "▼ 98.2%" delta.
  double? get first => _first;

  /// Engine samples averaged into each point (1, 2, 4, ...).
  int get samplesPerPoint => _samplesPerPoint;

  /// Increments on every change; painters cache on it.
  int get version => _version;

  /// Stages reached in this run, oldest first. Read-only view.
  List<LossMarker> get markers => _markersView;

  /// Adds one sample; call it once per second of play.
  ///
  /// NaN, ±infinity and values <= 0 are ignored. Samples are averaged into a
  /// pending point; when [capacity] points exist, pairs are averaged in
  /// place, marker indices are halved and [samplesPerPoint] doubles.
  /// Notifies once per committed point.
  void add(double loss) {
    if (!loss.isFinite || loss <= 0) return;
    _first ??= loss;
    _latest = loss;
    final h = hash01(seed, _serial, _run);
    _serial++;
    _pendingSum += loss * (1 + noise * (2 * h - 1));
    _pendingCount++;
    _version++;
    if (_pendingCount < _samplesPerPoint) return;

    final index = _length;
    _points[_length++] = _pendingSum / _pendingCount;
    _pendingSum = 0;
    _pendingCount = 0;
    for (var i = 0; i < _pendingMarks.length; i++) {
      _addMarker(LossMarker(index, _pendingMarks[i]));
    }
    _pendingMarks.clear();
    if (_length == capacity) _decimate();
    notifyListeners();
  }

  /// Marks a stage reached (e.g. 'CNN') at the next committed point.
  void mark(String label) {
    if (_pendingMarks.length == maxMarkers) _pendingMarks.removeAt(0);
    _pendingMarks.add(label);
    _version++;
  }

  /// New run (`publishPaper`): clears points, markers, [first] and pending
  /// samples. Notifies once.
  void startRun() {
    _length = 0;
    _samplesPerPoint = 1;
    _pendingSum = 0;
    _pendingCount = 0;
    _serial = 0;
    _run++;
    _first = null;
    _latest = null;
    _markers.clear();
    _pendingMarks.clear();
    _version++;
    notifyListeners();
  }

  /// For the app's save file (the core save codec does not include it).
  Map<String, Object?> toJson() => <String, Object?>{
    'format': 1,
    'capacity': capacity,
    'noise': noise,
    'seed': seed,
    'run': _run,
    'serial': _serial,
    'samplesPerPoint': _samplesPerPoint,
    'points': List<double>.generate(_length, (i) => _points[i]),
    'pendingSum': _pendingSum,
    'pendingCount': _pendingCount,
    'first': _first,
    'latest': _latest,
    'markers': [
      for (final m in _markers)
        <String, Object?>{'index': m.index, 'label': m.label},
    ],
    'pendingMarks': List<String>.of(_pendingMarks),
  };

  /// Averages neighbouring pairs in place: the buffer goes from [capacity]
  /// points (always even) to half, and each point now covers twice the
  /// samples. The mean of the points is unchanged.
  void _decimate() {
    final half = _length >> 1;
    for (var i = 0; i < half; i++) {
      _points[i] = (_points[2 * i] + _points[2 * i + 1]) * 0.5;
    }
    _length = half;
    for (var i = 0; i < _markers.length; i++) {
      final m = _markers[i];
      _markers[i] = LossMarker(m.index >> 1, m.label);
    }
    _samplesPerPoint *= 2;
  }

  void _addMarker(LossMarker marker) {
    if (_markers.length == maxMarkers) _markers.removeAt(0);
    _markers.add(marker);
  }

  static int _readInt(Map<String, Object?> json, String key, int fallback) {
    final value = json[key];
    if (value == null) return fallback;
    if (value is num && value.isFinite) return value.toInt();
    throw FormatException('LossHistory.$key must be a number', value);
  }

  static double? _readDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw FormatException('LossHistory.$key must be a number', value);
  }

  static double? _readPositive(Map<String, Object?> json, String key) {
    final value = _readDouble(json, key);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  static List<Object?> _readList(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return const <Object?>[];
    if (value is List) return value;
    throw FormatException('LossHistory.$key must be a list', value);
  }
}

/// A stage reached during the run, drawn as a hairline on the chart.
@immutable
class LossMarker {
  const LossMarker(this.index, this.label);

  /// Point index in the [LossHistory] (halved on every decimation).
  final int index;

  /// Short name, e.g. 'CNN'. Shown when there is room.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is LossMarker && other.index == index && other.label == label;

  @override
  int get hashCode => Object.hash(index, label);

  @override
  String toString() => 'LossMarker($index, $label)';
}

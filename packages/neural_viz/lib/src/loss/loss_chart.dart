import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../api/viz_theme.dart';
import 'loss_history.dart';

/// TensorBoard-style loss curve: a faint jittered trace, a bold debiased EMA,
/// a log y axis, evolution markers and a value readout.
///
/// Designed for 240–360 × 72–120 px; below 64 px of height it switches to a
/// compact sparkline (line, area and readout only). The background is
/// transparent so it sits on the app's card. Fills its bounded constraints
/// (320 × 96 along an unbounded axis).
///
/// No ticker: it repaints only when [history] notifies (once per committed
/// point), and rebuilds its paths only when the history or the size changed.
class LossChart extends StatefulWidget {
  const LossChart({
    super.key,
    required this.history,
    this.minLoss = 0.005,
    this.maxLoss = 3.0,
    this.smoothing = 0.6,
    this.showAxis = true,
    this.showReadout = true,
    this.valueLabel = 'loss',
    this.theme,
    this.semanticLabel,
  }) : assert(minLoss > 0 && maxLoss > minLoss),
       assert(smoothing >= 0 && smoothing < 1);

  /// The samples to draw.
  final LossHistory history;

  /// Bottom of the log y axis. Smaller values are drawn on it.
  final double minLoss;

  /// Top of the log y axis. Larger values are drawn on it.
  final double maxLoss;

  /// EMA weight of the bold line (TensorBoard's default 0.6). 0 draws the raw
  /// values as the bold line, with no faint trace.
  final double smoothing;

  /// Dashed decade guides and their labels. Ignored in compact mode.
  final bool showAxis;

  /// Current value and the drop since the start of the run, top right.
  final bool showReadout;

  /// Short name shown before the value in the readout.
  final String valueLabel;

  /// Colors and font. Defaults to the [NeuralVizTheme] registered in the
  /// app's `ThemeData`, else the Neural Idle tokens.
  final NeuralVizTheme? theme;

  /// Localized description, e.g. "Training loss". The semantics value is the
  /// formatted number. Falls back to [valueLabel].
  final String? semanticLabel;

  @override
  State<LossChart> createState() => _LossChartState();
}

/// Readout format: "2.30" for values >= 1, otherwise 3 significant digits
/// ("0.0421").
@visibleForTesting
String formatLoss(double value) =>
    value >= 1 ? value.toStringAsFixed(2) : value.toStringAsPrecision(3);

/// Drop from [first] to [latest] in percent, as "98.2%". Negative when the
/// loss went up.
@visibleForTesting
double lossDeltaPercent(double first, double latest) =>
    (first - latest) / first * 100;

/// TensorBoard's debiased exponential moving average of [history] into [out]
/// (at least `history.length` long).
///
/// `last = last·w + (1 − w)·y`, divided by `1 − wⁿ` so the first points are
/// not pulled toward 0.
@visibleForTesting
void debiasedEma(LossHistory history, double smoothing, Float64List out) {
  var last = 0.0;
  var weightPow = 1.0;
  final keep = 1 - smoothing;
  for (var i = 0; i < history.length; i++) {
    last = last * smoothing + keep * history[i];
    weightPow *= smoothing;
    out[i] = last / (1 - weightPow);
  }
}

class _LossChartState extends State<LossChart> {
  final _ChartCache _cache = _ChartCache();

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        widget.theme ??
        Theme.of(context).extension<NeuralVizTheme>() ??
        const NeuralVizTheme();
    final style = _ChartStyle(
      theme: theme,
      minLoss: widget.minLoss,
      maxLoss: widget.maxLoss,
      smoothing: widget.smoothing,
      showAxis: widget.showAxis,
      showReadout: widget.showReadout,
      valueLabel: widget.valueLabel,
      devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      textScaler:
          (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling).clamp(
            maxScaleFactor: 1.3,
          ),
    );
    final history = widget.history;
    final chart = RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) => CustomPaint(
          size: Size(
            constraints.hasBoundedWidth ? constraints.maxWidth : 320,
            constraints.hasBoundedHeight ? constraints.maxHeight : 96,
          ),
          painter: _LossChartPainter(history, _cache, style),
        ),
      ),
    );
    final label = widget.semanticLabel ?? widget.valueLabel;
    return ListenableBuilder(
      listenable: history,
      builder: (context, child) => Semantics(
        container: true,
        label: label,
        value: _hasValue(history) ? formatLoss(history.latest!) : null,
        child: child,
      ),
      child: ExcludeSemantics(child: chart),
    );
  }
}

bool _hasValue(LossHistory history) =>
    history.length >= 2 && history.latest != null;

/// Everything the picture depends on besides the history and the size.
@immutable
class _ChartStyle {
  const _ChartStyle({
    required this.theme,
    required this.minLoss,
    required this.maxLoss,
    required this.smoothing,
    required this.showAxis,
    required this.showReadout,
    required this.valueLabel,
    required this.devicePixelRatio,
    required this.textScaler,
  });

  final NeuralVizTheme theme;
  final double minLoss;
  final double maxLoss;
  final double smoothing;
  final bool showAxis;
  final bool showReadout;
  final String valueLabel;
  final double devicePixelRatio;
  final TextScaler textScaler;

  @override
  bool operator ==(Object other) =>
      other is _ChartStyle &&
      other.theme == theme &&
      other.minLoss == minLoss &&
      other.maxLoss == maxLoss &&
      other.smoothing == smoothing &&
      other.showAxis == showAxis &&
      other.showReadout == showReadout &&
      other.valueLabel == valueLabel &&
      other.devicePixelRatio == devicePixelRatio &&
      other.textScaler == textScaler;

  @override
  int get hashCode => Object.hash(
    theme,
    minLoss,
    maxLoss,
    smoothing,
    showAxis,
    showReadout,
    valueLabel,
    devicePixelRatio,
    textScaler,
  );
}

class _LossChartPainter extends CustomPainter {
  _LossChartPainter(this.history, this.cache, this.style)
    : super(repaint: history);

  final LossHistory history;
  final _ChartCache cache;
  final _ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) =>
      cache.paint(canvas, size, history, style);

  @override
  bool shouldRepaint(_LossChartPainter oldDelegate) =>
      !identical(oldDelegate.history, history) ||
      !identical(oldDelegate.cache, cache) ||
      oldDelegate.style != style;
}

/// A single-line [TextPainter] that is laid out again only when its text,
/// style or width limit changes.
class _Label {
  _Label({bool ellipsis = false})
    : painter = TextPainter(
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: ellipsis ? '…' : null,
        textWidthBasis: TextWidthBasis.longestLine,
      );

  final TextPainter painter;
  String? _text;
  TextStyle? _style;
  TextScaler? _scaler;
  double _maxWidth = double.infinity;

  void set(
    String text,
    TextStyle style,
    TextScaler scaler, [
    double maxWidth = double.infinity,
  ]) {
    if (text == _text &&
        identical(style, _style) &&
        scaler == _scaler &&
        maxWidth == _maxWidth) {
      return;
    }
    _text = text;
    _style = style;
    _scaler = scaler;
    _maxWidth = maxWidth;
    painter
      ..text = TextSpan(text: text, style: style)
      ..textScaler = scaler
      ..layout(maxWidth: maxWidth);
  }

  /// Lays [text] out in at most [room] pixels, ellipsized when it does not
  /// fit. Lays out again only when the text or the whole-pixel room of a
  /// truncated label changes.
  void fit(String text, TextStyle style, TextScaler scaler, double room) {
    if (text != _text || !identical(style, _style) || scaler != _scaler) {
      set(text, style, scaler);
    }
    final fits = painter.maxIntrinsicWidth <= room;
    set(text, style, scaler, fits ? double.infinity : room.floorToDouble());
  }

  double get width => painter.width;
  double get height => painter.height;
  double get baseline =>
      painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);

  void paint(Canvas canvas, double x, double y) =>
      painter.paint(canvas, Offset(x, y));

  void dispose() => painter.dispose();
}

// Layout constants, in logical pixels.
const double _kCompactHeight = 64;
const double _kHeadRadius = 2.25;
const double _kHaloRadius = 8;
const double _kDiamond = 2.5; // half diagonal
const double _kMarkerLabelGap = 36;
// Diamond, padding and clearance from the neighbouring diamond or label.
const double _kMarkerLabelInset = 12;
const double _kTriangleWidth = 6;

/// Paths, paints and text of one chart, rebuilt only when their inputs
/// change. Lives in the widget's state so it survives painter rebuilds.
class _ChartCache {
  // Inputs of the current layout and data.
  _ChartStyle? _style;
  Size _size = Size.zero;
  LossHistory? _history;
  int _version = -1;
  bool _dataDirty = true;

  // Layout.
  bool _compact = false;
  Rect _plot = Rect.zero;
  double _logMax = 0;
  double _yScale = 0;
  double _readoutRight = 0;
  double _readoutBaseline = 0;
  int _guideCount = 0;
  final Float64List _guideY = Float64List(_maxGuides);
  Float32List _guidePoints = Float32List(0);
  Float32List _baselinePoints = Float32List(0);

  // Data.
  bool _hasCurve = false;
  final Path _raw = Path();
  final Path _ema = Path();
  final Path _area = Path();
  final Path _diamonds = Path();
  final Path _triangle = Path();
  Float64List _smoothed = Float64List(0);
  Offset _head = Offset.zero;
  bool _hasDelta = false;
  double _deltaX = 0;
  double _valueX = 0;
  double _labelX = 0;
  int _markerCount = 0;
  final Float64List _markerX = Float64List(LossHistory.maxMarkers);
  // Label left edge, or NaN when the label is hidden.
  final Float64List _markerLabelX = Float64List(LossHistory.maxMarkers);

  // Paints and shaders.
  final Paint _guidePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.butt;
  final Paint _baselinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.butt;
  final Paint _markerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _diamondPaint = Paint()..style = PaintingStyle.fill;
  final Paint _rawPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint _emaPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.75
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _areaPaint = Paint()..style = PaintingStyle.fill;
  final Paint _haloPaint = Paint()..style = PaintingStyle.fill;
  final Paint _corePaint = Paint()..style = PaintingStyle.fill;
  final Paint _trianglePaint = Paint()..style = PaintingStyle.fill;
  ui.Gradient? _areaShader;
  ui.Gradient? _haloShader;

  // Text.
  TextStyle _axisStyle = const TextStyle();
  TextStyle _labelStyle = const TextStyle();
  TextStyle _valueStyle = const TextStyle();
  TextStyle _deltaDownStyle = const TextStyle();
  TextStyle _deltaUpStyle = const TextStyle();
  final List<_Label> _axisLabels = List<_Label>.generate(
    _maxGuides,
    (_) => _Label(),
  );
  final List<_Label> _markerLabels = List<_Label>.generate(
    LossHistory.maxMarkers,
    (_) => _Label(ellipsis: true),
  );
  final _Label _readoutLabel = _Label();
  final _Label _value = _Label();
  final _Label _delta = _Label();
  final _Label _valueTemplate = _Label();
  final _Label _deltaTemplate = _Label();

  static const int _maxGuides = 8;

  void dispose() {
    for (final label in _axisLabels) {
      label.dispose();
    }
    for (final label in _markerLabels) {
      label.dispose();
    }
    _readoutLabel.dispose();
    _value.dispose();
    _delta.dispose();
    _valueTemplate.dispose();
    _deltaTemplate.dispose();
    _areaShader?.dispose();
    _haloShader?.dispose();
  }

  void paint(Canvas canvas, Size size, LossHistory history, _ChartStyle style) {
    if (size.width <= 0 || size.height <= 0) return;
    if (style != _style) {
      _applyStyle(style);
      _size = Size.zero; // force a layout
    }
    if (size != _size) {
      _size = size;
      _layout(style, size);
      _dataDirty = true;
    }
    if (_dataDirty ||
        !identical(history, _history) ||
        history.version != _version) {
      _history = history;
      _version = history.version;
      _dataDirty = false;
      _rebuild(history, style);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final drawPlot = _plot.width >= 8 && _plot.height >= 4;
    if (!_compact && style.showAxis && drawPlot) _paintAxis(canvas);
    if (!_hasCurve && drawPlot) {
      canvas.drawRawPoints(ui.PointMode.lines, _baselinePoints, _baselinePaint);
    }
    if (_hasCurve) {
      if (!_compact) _paintMarkers(canvas);
      canvas.drawPath(_area, _areaPaint);
      if (!_compact && style.smoothing > 0) canvas.drawPath(_raw, _rawPaint);
      canvas.drawPath(_ema, _emaPaint);
      if (!_compact) _paintHead(canvas);
    }
    if (style.showReadout) _paintReadout(canvas);
    canvas.restore();
  }

  void _applyStyle(_ChartStyle style) {
    _style = style;
    final t = style.theme;
    TextStyle mono(double size, Color color) => TextStyle(
      fontFamily: t.monoFontFamily,
      fontSize: size,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: color,
    );
    _axisStyle = mono(9, t.textMuted);
    _labelStyle = mono(9, t.textMuted);
    _valueStyle = mono(11, t.textPrimary);
    _deltaDownStyle = mono(9, t.success);
    _deltaUpStyle = mono(9, t.textMuted);

    _guidePaint.color = t.border;
    _baselinePaint.color = t.signal.withValues(alpha: 0.3);
    _markerPaint.color = t.structure.withValues(alpha: 0.25);
    _diamondPaint.color = t.structure.withValues(alpha: 0.9);
    _rawPaint.color = t.signal.withValues(alpha: 0.22);
    _emaPaint.color = t.signal;
    _corePaint.color = Color.lerp(t.signal, t.textPrimary, 0.35)!;

    _haloShader?.dispose();
    _haloShader = ui.Gradient.radial(
      Offset.zero,
      _kHaloRadius,
      <Color>[
        t.signal.withValues(alpha: 0.5),
        t.signal.withValues(alpha: 0.14),
        t.signal.withValues(alpha: 0),
      ],
      const <double>[0, 0.4, 1],
    );
    _haloPaint.shader = _haloShader;

    final scaler = style.textScaler;
    _readoutLabel.set(style.valueLabel, _labelStyle, scaler);
    // Widest strings the readout shows, so compact mode reserves a steady
    // width.
    _valueTemplate.set('0.00000', _valueStyle, scaler);
    _deltaTemplate.set('100.0%', _deltaDownStyle, scaler);
  }

  void _layout(_ChartStyle style, Size size) {
    final w = size.width;
    final h = size.height;
    final scaler = style.textScaler;
    _compact = h < _kCompactHeight;

    // Decade guides between the bounds: 1, .1, .01 by default.
    _guideCount = 0;
    var axisWidth = 0.0;
    final top = (math.log(style.maxLoss) / math.ln10 + 1e-9).floor();
    for (var k = top; _guideCount < _maxGuides; k--) {
      final d = math.pow(10, k).toDouble();
      if (d <= style.minLoss) break;
      if (d > style.maxLoss) continue;
      _guideY[_guideCount] = d;
      final text = k >= 0
          ? '${math.pow(10, k).toInt()}'
          : '.${'0' * (-k - 1)}1';
      final label = _axisLabels[_guideCount];
      label.set(text, _axisStyle, scaler);
      axisWidth = math.max(axisWidth, label.width);
      _guideCount++;
    }

    final valueHeight = _valueTemplate.height;
    if (_compact) {
      final readoutWidth = style.showReadout ? _readoutWidth() : 0.0;
      _plot = Rect.fromLTRB(
        1,
        3,
        w - (style.showReadout ? readoutWidth + 10 : 1),
        h - 3,
      );
      _readoutRight = w;
      _readoutBaseline = (h - valueHeight) / 2 + _valueTemplate.baseline;
    } else {
      final band = style.showReadout ? valueHeight + 4 : 0.0;
      final gutter = style.showAxis && _guideCount > 0 ? axisWidth + 6 : 2.0;
      _plot = Rect.fromLTRB(gutter, band + 5, w - 5, h - 5);
      _readoutRight = _plot.right;
      _readoutBaseline = _valueTemplate.baseline;
    }
    if (_plot.width < 0 || _plot.height < 0) {
      _plot = Rect.fromLTWH(_plot.left, _plot.top, 0, 0);
    }

    _logMax = math.log(style.maxLoss);
    final logRange = _logMax - math.log(style.minLoss);
    _yScale = _plot.height / logRange;

    // Snap horizontal hairlines to the device pixel grid.
    final dpr = style.devicePixelRatio;
    for (var i = 0; i < _guideCount; i++) {
      _guideY[i] = _snap(_y(_guideY[i]), dpr);
    }
    _guidePoints = _dashes(_guideY, _guideCount, 2, 4);
    final baseline = Float64List(1)..[0] = _snap(_y(math.ln10), dpr);
    _baselinePoints = _dashes(baseline, 1, 4, 4);

    _areaShader?.dispose();
    _areaShader = ui.Gradient.linear(
      Offset(0, _plot.top),
      Offset(0, _plot.bottom),
      <Color>[
        style.theme.signal.withValues(alpha: 0.16),
        style.theme.signal.withValues(alpha: 0),
      ],
    );
    _areaPaint.shader = _areaShader;
  }

  double _readoutWidth() =>
      _readoutLabel.width +
      4 +
      _valueTemplate.width +
      8 +
      _kTriangleWidth +
      3 +
      _deltaTemplate.width;

  /// Horizontal dashes ([on] px, [off] px) across the plot at each y.
  Float32List _dashes(Float64List ys, int count, double on, double off) {
    final step = on + off;
    final perLine = _plot.width <= 0 ? 0 : (_plot.width / step).ceil();
    final points = Float32List(count * perLine * 4);
    var j = 0;
    for (var i = 0; i < count; i++) {
      final y = ys[i];
      for (var d = 0; d < perLine; d++) {
        final x = _plot.left + d * step;
        points[j++] = x;
        points[j++] = y;
        points[j++] = math.min(x + on, _plot.right);
        points[j++] = y;
      }
    }
    return points;
  }

  /// y of a loss value, clamped to the plot.
  double _y(double loss) {
    final style = _style!;
    final v = loss < style.minLoss
        ? style.minLoss
        : (loss > style.maxLoss ? style.maxLoss : loss);
    return _plot.top + (_logMax - math.log(v)) * _yScale;
  }

  /// Centers a 1 px line on device pixels.
  static double _snap(double v, double dpr) =>
      ((v * dpr - dpr / 2).roundToDouble() + dpr / 2) / dpr;

  void _rebuild(LossHistory history, _ChartStyle style) {
    _raw.reset();
    _ema.reset();
    _area.reset();
    _diamonds.reset();
    _triangle.reset();
    _markerCount = 0;
    final n = history.length;
    _hasCurve = n >= 2 && _plot.width >= 8 && _plot.height >= 4;

    if (_hasCurve) {
      if (_smoothed.length < n) _smoothed = Float64List(history.capacity);
      debiasedEma(history, style.smoothing, _smoothed);
      final dx = _plot.width / (n - 1);
      final left = _plot.left;

      if (!_compact && style.smoothing > 0) _buildRaw(history, dx);

      _area.moveTo(left, _plot.bottom);
      for (var i = 0; i < n; i++) {
        final x = left + i * dx;
        final y = _y(_smoothed[i]);
        if (i == 0) {
          _ema.moveTo(x, y);
        } else {
          _ema.lineTo(x, y);
        }
        _area.lineTo(x, y);
      }
      _area
        ..lineTo(_plot.right, _plot.bottom)
        ..close();
      _head = Offset(_plot.right, _y(_smoothed[n - 1]));

      if (!_compact) _buildMarkers(history, style, dx);
    }
    _buildReadout(history, style);
  }

  /// The faint trace. When there are more points than pixels, each pixel
  /// column keeps its min and max so spikes survive.
  void _buildRaw(LossHistory history, double dx) {
    final n = history.length;
    final left = _plot.left;
    if (n <= _plot.width) {
      _raw.moveTo(left, _y(history[0]));
      for (var i = 1; i < n; i++) {
        _raw.lineTo(left + i * dx, _y(history[i]));
      }
      return;
    }
    var column = (left).floor();
    var lo = _y(history[0]);
    var hi = lo;
    var loFirst = true;
    var started = false;
    for (var i = 1; i <= n; i++) {
      final x = left + i * dx;
      final c = x.floor();
      if (i == n || c != column) {
        final cx = (column + 0.5).clamp(left, _plot.right).toDouble();
        final a = loFirst ? lo : hi;
        final b = loFirst ? hi : lo;
        if (!started) {
          _raw.moveTo(cx, a);
          started = true;
        } else {
          _raw.lineTo(cx, a);
        }
        if (b != a) _raw.lineTo(cx, b);
        if (i == n) break;
        column = c;
        lo = _y(history[i]);
        hi = lo;
        loFirst = true;
      } else {
        final y = _y(history[i]);
        if (y < lo) {
          lo = y;
          loFirst = false;
        }
        if (y > hi) {
          hi = y;
          loFirst = true;
        }
      }
    }
  }

  void _buildMarkers(LossHistory history, _ChartStyle style, double dx) {
    final markers = history.markers;
    final n = history.length;
    final dpr = style.devicePixelRatio;
    for (var i = 0; i < markers.length; i++) {
      final m = markers[i];
      if (m.index < 0 || m.index >= n) continue;
      _markerX[_markerCount++] = _snap(_plot.left + m.index * dx, dpr);
    }
    final cy = _plot.top + _kDiamond;
    var prevLabelRight = _plot.left;
    var k = 0;
    for (var i = 0; i < markers.length; i++) {
      final m = markers[i];
      if (m.index < 0 || m.index >= n) continue;
      final x = _markerX[k];
      _diamonds
        ..moveTo(x, cy - _kDiamond)
        ..lineTo(x + _kDiamond, cy)
        ..lineTo(x, cy + _kDiamond)
        ..lineTo(x - _kDiamond, cy)
        ..close();

      // The label goes right of the hairline, or left of it for the newest
      // marker when it sits near the head.
      final label = _markerLabels[k];
      final nextX = k + 1 < _markerCount ? _markerX[k + 1] : _plot.right;
      _markerLabelX[k] = double.nan;
      if (nextX - x >= _kMarkerLabelGap) {
        label.fit(
          m.label,
          _axisStyle,
          style.textScaler,
          nextX - x - _kMarkerLabelInset,
        );
        _markerLabelX[k] = x + _kDiamond + 3;
        prevLabelRight = _markerLabelX[k] + label.width;
      } else if (k + 1 == _markerCount &&
          x - math.max(prevLabelRight, _plot.left) >= _kMarkerLabelGap) {
        final room =
            x - math.max(prevLabelRight, _plot.left) - _kMarkerLabelInset;
        label.fit(m.label, _axisStyle, style.textScaler, room);
        _markerLabelX[k] = x - _kDiamond - 3 - label.width;
      } else {
        prevLabelRight = x;
      }
      k++;
    }
  }

  /// Readout strings and positions, right-aligned:
  /// `label value ▼ delta`.
  void _buildReadout(LossHistory history, _ChartStyle style) {
    final scaler = style.textScaler;
    final latest = history.latest;
    final first = history.first;
    var x = _readoutRight;
    _hasDelta = false;
    if (!_hasValue(history)) {
      _value.set('—', _valueStyle, scaler);
    } else {
      _value.set(formatLoss(latest!), _valueStyle, scaler);
      if (first != null) {
        _hasDelta = true;
        final pct = lossDeltaPercent(first, latest);
        final down = pct >= 0;
        _delta.set(
          '${pct.abs().toStringAsFixed(1)}%',
          down ? _deltaDownStyle : _deltaUpStyle,
          scaler,
        );
        x -= _delta.width;
        _deltaX = x;
        x -= 3 + _kTriangleWidth;
        // A solid triangle instead of a glyph, so it never depends on font
        // fallback. Sits on the x-height of the delta text.
        final tip = _readoutBaseline - 1.5;
        final base = tip - 4.5;
        _triangle.reset();
        if (down) {
          _triangle
            ..moveTo(x, base)
            ..lineTo(x + _kTriangleWidth, base)
            ..lineTo(x + _kTriangleWidth / 2, tip);
        } else {
          _triangle
            ..moveTo(x, tip)
            ..lineTo(x + _kTriangleWidth, tip)
            ..lineTo(x + _kTriangleWidth / 2, base);
        }
        _triangle.close();
        _trianglePaint.color = down
            ? style.theme.success
            : style.theme.textMuted;
        x -= 8;
      }
    }
    x -= _value.width;
    _valueX = x;
    _labelX = x - 4 - _readoutLabel.width;
  }

  void _paintAxis(Canvas canvas) {
    canvas.drawRawPoints(ui.PointMode.lines, _guidePoints, _guidePaint);
    for (var i = 0; i < _guideCount; i++) {
      final label = _axisLabels[i];
      final y = (_guideY[i] - label.height / 2).clamp(0.0, _size.height);
      label.paint(canvas, _plot.left - 6 - label.width, y.toDouble());
    }
  }

  void _paintMarkers(Canvas canvas) {
    if (_markerCount == 0) return;
    final top = _plot.top + _kDiamond * 2 + 1;
    for (var i = 0; i < _markerCount; i++) {
      final x = _markerX[i];
      canvas.drawLine(Offset(x, top), Offset(x, _plot.bottom), _markerPaint);
    }
    canvas.drawPath(_diamonds, _diamondPaint);
    final cy = _plot.top + _kDiamond;
    for (var i = 0; i < _markerCount; i++) {
      final lx = _markerLabelX[i];
      if (lx.isNaN) continue;
      final label = _markerLabels[i];
      label.paint(canvas, lx, cy - label.height / 2);
    }
  }

  void _paintHead(Canvas canvas) {
    canvas
      ..save()
      ..translate(_head.dx, _head.dy)
      ..drawCircle(Offset.zero, _kHaloRadius, _haloPaint)
      ..restore()
      ..drawCircle(_head, _kHeadRadius, _corePaint);
  }

  void _paintReadout(Canvas canvas) {
    final baseline = _readoutBaseline;
    if (_hasDelta) {
      _delta.paint(canvas, _deltaX, baseline - _delta.baseline);
      canvas.drawPath(_triangle, _trianglePaint);
    }
    _value.paint(canvas, _valueX, baseline - _value.baseline);
    _readoutLabel.paint(canvas, _labelX, baseline - _readoutLabel.baseline);
  }
}

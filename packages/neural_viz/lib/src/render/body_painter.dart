import 'dart:ui';

import '../api/viz_theme.dart';
import '../scene/layout.dart';

/// Draws neuron bodies. Used by both the static picture and the dynamic
/// layer, so a body looks the same whichever layer draws it.
class BodyPainter {
  BodyPainter(NeuralVizTheme theme, {bool highContrast = false})
    : _fillColor = theme.surfaceRaised,
      _rimColor = theme.structure.withValues(alpha: 0.55),
      _rimWidth = highContrast ? 1.75 : 1.25;

  /// Opacity steps with a cached paint pair each: fading or back-of-ring
  /// bodies reuse paints instead of allocating colors every frame.
  static const _alphaSteps = 32;

  final Color _fillColor, _rimColor;
  final double _rimWidth;
  final List<Paint?> _fills = List.filled(_alphaSteps + 1, null);
  final List<Paint?> _rims = List.filled(_alphaSteps + 1, null);
  final Path _diamond = Path();

  Paint _fillAt(int step) => _fills[step] ??= Paint()
    ..color = _fillColor.withValues(alpha: _fillColor.a * step / _alphaSteps);

  Paint _rimAt(int step) => _rims[step] ??= Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _rimWidth
    ..color = _rimColor.withValues(alpha: _rimColor.a * step / _alphaSteps);

  void paint(
    Canvas canvas,
    double x,
    double y,
    double r,
    int shape, [
    double alpha = 1,
  ]) {
    final step = (alpha.clamp(0.0, 1.0) * _alphaSteps).round();
    if (step == 0) return;
    final fill = _fillAt(step), rim = _rimAt(step);
    switch (NeuronShape.values[shape]) {
      case NeuronShape.circle:
        canvas.drawCircle(Offset(x, y), r, fill);
        canvas.drawCircle(Offset(x, y), r, rim);
      case NeuronShape.square:
        final rect = RRect.fromLTRBR(
          x - r,
          y - r,
          x + r,
          y + r,
          Radius.circular(r * 0.5),
        );
        canvas.drawRRect(rect, fill);
        canvas.drawRRect(rect, rim);
      case NeuronShape.diamond:
        final d = r * 1.2;
        _diamond
          ..reset()
          ..moveTo(x, y - d)
          ..lineTo(x + d, y)
          ..lineTo(x, y + d)
          ..lineTo(x - d, y)
          ..close();
        canvas.drawPath(_diamond, fill);
        canvas.drawPath(_diamond, rim);
    }
  }
}

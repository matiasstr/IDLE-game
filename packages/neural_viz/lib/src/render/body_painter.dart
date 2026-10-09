import 'dart:ui';

import '../api/viz_theme.dart';
import '../scene/layout.dart';

/// Draws neuron bodies. Used by both the static picture and the dynamic
/// layer, so a body looks the same whichever layer draws it.
class BodyPainter {
  BodyPainter(NeuralVizTheme theme, {bool highContrast = false})
    : _fillColor = theme.surfaceRaised,
      _rimColor = theme.structure.withValues(alpha: 0.55),
      _fill = Paint()..color = theme.surfaceRaised,
      _rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highContrast ? 1.75 : 1.25
        ..color = theme.structure.withValues(alpha: 0.55);

  final Color _fillColor, _rimColor;
  final Paint _fill, _rim;
  final Path _diamond = Path();

  void paint(
    Canvas canvas,
    double x,
    double y,
    double r,
    int shape, [
    double alpha = 1,
  ]) {
    if (alpha < 1) {
      _fill.color = _fillColor.withValues(alpha: _fillColor.a * alpha);
      _rim.color = _rimColor.withValues(alpha: _rimColor.a * alpha);
    }
    switch (NeuronShape.values[shape]) {
      case NeuronShape.circle:
        canvas.drawCircle(Offset(x, y), r, _fill);
        canvas.drawCircle(Offset(x, y), r, _rim);
      case NeuronShape.square:
        final rect = RRect.fromLTRBR(
          x - r,
          y - r,
          x + r,
          y + r,
          Radius.circular(r * 0.5),
        );
        canvas.drawRRect(rect, _fill);
        canvas.drawRRect(rect, _rim);
      case NeuronShape.diamond:
        final d = r * 1.2;
        _diamond
          ..reset()
          ..moveTo(x, y - d)
          ..lineTo(x + d, y)
          ..lineTo(x, y + d)
          ..lineTo(x - d, y)
          ..close();
        canvas.drawPath(_diamond, _fill);
        canvas.drawPath(_diamond, _rim);
    }
    if (alpha < 1) {
      _fill.color = _fillColor;
      _rim.color = _rimColor;
    }
  }
}

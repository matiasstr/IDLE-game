import 'dart:ui';

import '../api/network_kind.dart';
import '../scene/motif.dart';
import 'attention.dart';

/// Transformer: blocks on plates, two-headed attention fans and residual
/// skips.
///
/// - Static: a plate under each attention layer and three faint violet
///   residual arcs (layer l → l + 2) below the network.
/// - Per frame: in each block a query lights up every `lerp(2.4, 1.2, E)` s
///   (blocks a third of a period apart). Head A (cyan) arcs to the keys on
///   the left, head B (violet) on the right, with softmax weights that get
///   peakier as the model trains; the two strongest keys pulse back into
///   the query.
class TransformerMotif extends Motif {
  const TransformerMotif();

  static final double _heroTime =
      NetworkKind.transformer.heroTime.inMicroseconds / 1e6;

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    paintResiduals(canvas, ctx, alpha: 0.22);
    paintPlates(canvas, ctx, AttentionGeometry.of(ctx.layout));
  }

  @override
  void evaluate(FrameContext ctx) {
    evaluateAttention(
      ctx,
      AttentionGeometry.of(ctx.layout),
      causal: false,
      heroTime: _heroTime,
      // Global attention: keys anywhere in the sequence can win.
      locality: 0.3,
    );
  }
}

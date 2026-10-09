import 'dart:ui';

import '../api/network_kind.dart';
import '../api/viz_types.dart';
import '../scene/motif.dart';
import 'attention.dart';

/// LLM: the transformer's blocks and attention, plus what makes it a
/// language model.
///
/// - Causal mask: a query attends only to the rows above it, and the query
///   walks down the sequence one row per cycle, so the arcs draw a growing
///   triangle.
/// - Depth: each plate has two border-only copies stacked behind it (high
///   quality only), for the many blocks one column stands for.
/// - Autoregressive loop: a dashed violet arch from the logits back to the
///   input tokens.
/// - Token stream: cyan pills drift out of the logits into the right margin
///   at a rate tied to production (about 0.7/s at rest up to 8/s), plus one
///   per training tap at +420 ms; a few ride the loop back to the input.
class LlmMotif extends Motif {
  const LlmMotif();

  static final double _heroTime = NetworkKind.llm.heroTime.inMicroseconds / 1e6;

  @override
  void paintUnder(Canvas canvas, StaticContext ctx) {
    final geometry = AttentionGeometry.of(ctx.layout);
    paintLoop(canvas, ctx, geometry);
    paintPlates(canvas, ctx, geometry, depth: ctx.quality == VizQuality.high);
  }

  @override
  void evaluate(FrameContext ctx) {
    final geometry = AttentionGeometry.of(ctx.layout);
    evaluateAttention(ctx, geometry, causal: true, heroTime: _heroTime);
    evaluateTokens(ctx, geometry, heroTime: _heroTime);
  }
}

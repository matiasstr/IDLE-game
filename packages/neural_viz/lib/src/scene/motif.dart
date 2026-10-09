import 'dart:typed_data';
import 'dart:ui';

import '../api/viz_theme.dart';
import '../api/viz_types.dart';
import 'frame_buffers.dart';
import 'layout.dart';
import 'tap_tracker.dart';

/// The signature look of one architecture, on top of the shared network
/// (neurons, edges, signals, training waves).
///
/// Internal extension point: one implementation per [NetworkKind], chosen
/// in `motifs/motifs.dart`. Static parts are recorded once into the network
/// picture; [evaluate] runs every frame and must not allocate.
abstract class Motif {
  const Motif();

  /// Drawn into the static picture before the edges: plates, panels, bands.
  void paintUnder(Canvas canvas, StaticContext ctx) {}

  /// Drawn into the static picture after the neuron bodies: glyphs, loops,
  /// static arcs, small labels.
  void paintOver(Canvas canvas, StaticContext ctx) {}

  /// Per-frame motion: add sprites and lit lines to `ctx.frame` and adjust
  /// `ctx.actS` / `ctx.actM`. Runs after signals and waves and before the
  /// halos and cores are emitted. Scale every added alpha by
  /// `ctx.motifAlpha`, which is 0 while the network is transforming.
  void evaluate(FrameContext ctx) {}
}

/// What a motif needs to record its static parts.
class StaticContext {
  StaticContext({
    required this.layout,
    required this.theme,
    required this.strength,
    required this.contrast,
    required this.highContrast,
    required this.quality,
  });

  final NetworkLayout layout;
  final NeuralVizTheme theme;

  /// Display strength of each layout edge (see `EdgeStyle.strength`).
  final Float32List strength;
  final double contrast;
  final bool highContrast;

  /// Resolved tier: never [VizQuality.auto].
  final VizQuality quality;
}

/// Packed 0xRRGGBB values of the theme, for sprite tints.
class SceneColors {
  SceneColors(NeuralVizTheme theme)
    : signal = _rgb(theme.signal),
      structure = _rgb(theme.structure),
      success = _rgb(theme.success),
      accent = _rgb(theme.accent),
      textPrimary = _rgb(theme.textPrimary),
      textSecondary = _rgb(theme.textSecondary),
      textMuted = _rgb(theme.textMuted),
      border = _rgb(theme.border);

  final int signal, structure, success, accent;
  final int textPrimary, textSecondary, textMuted, border;

  static int _rgb(Color c) => c.toARGB32() & 0xffffff;
}

/// The scene state a motif can read and write during one frame. A single
/// instance is reused every frame.
class FrameContext {
  FrameContext(this.frame, this.taps);

  /// Where to add sprites and lines.
  final FrameBuffers frame;

  /// Recent training waves (`waveStart`, `waveAmp`, `waveSerial`).
  final TapTracker taps;

  late NetworkLayout layout;
  late SceneColors colors;
  late VizQuality quality;

  /// Scene time in seconds.
  double t = 0;

  /// Production energy, 0–1 (eased).
  double energy = 0;

  /// Signal travel distance in layer gaps since the start (see EnergyTrack).
  double flow = 0;

  /// Recent tapping intensity, 0–1.
  double heat = 0;

  double accuracy = 0.1;

  /// Progress to the next stage (0 at the last stage).
  double progress = 0;
  bool hasNextStage = false;

  /// Training contrast, 0–1 (see EdgeStyle.contrast).
  double contrast = 0;

  /// Opacity for motif effects: 0 while transforming, 1 when settled.
  double motifAlpha = 1;

  bool reducedMotion = false;

  /// Current drawn position, radius and opacity of every neuron (rings
  /// rotate, transitions move them).
  late Float32List x, y, r, alpha;

  /// Signal activation (drives the cyan hot core) and model activation
  /// (drives the violet halo), per neuron.
  late Float32List actS, actM;

  /// Index of the output neuron the network currently predicts.
  int predicted = 0;

  int get seed => layout.topology.seed;
}

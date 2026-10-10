import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../api/network_kind.dart';
import '../api/network_topology.dart';
import '../api/viz_theme.dart';
import '../api/viz_types.dart';
import '../motifs/motifs.dart';
import '../render/sprite_atlas.dart';
import '../render/static_recorder.dart';
import 'easing.dart';
import 'edge_style.dart';
import 'energy_track.dart';
import 'frame_buffers.dart';
import 'hash.dart';
import 'layout.dart';
import 'motif.dart';
import 'tap_tracker.dart';
import 'transition.dart';

/// Notifies the static layer that its pictures changed.
class StaticChanges extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Everything the network view draws, as a function of the input history
/// and scene time.
///
/// The widget feeds inputs stamped with scene time ([setInputs]) and drives
/// time ([tick]). The painters call [ensureLayout] and [evaluate]; the
/// latter is pure, so evaluating the same time twice gives identical
/// buffers, whatever the frame rate.
class VizScene {
  VizScene({required NetworkTopology topology, required int stage})
    : _topology = topology,
      _stage = stage {
    _ctx = FrameContext(frame, taps);
    _motif = motifFor(topology.kind);
  }

  static const _maxSlots = 140;
  static const _maxHops = 9;
  static const _memory = 0.35;

  /// Marks a cached route that ends in a neuron with no outgoing edges.
  static const _deadRoute = -2;

  final FrameBuffers frame = FrameBuffers();
  final EnergyTrack energy = EnergyTrack();
  final TapTracker taps = TapTracker();
  final StaticChanges staticChanges = StaticChanges();
  late final FrameContext _ctx;

  // ------------------------------------------------------------ settings

  NeuralVizTheme theme = const NeuralVizTheme();
  VizQuality requestedQuality = VizQuality.auto;
  bool showCaptions = true;
  bool paintBackground = true;
  bool highContrast = false;
  bool reducedMotion = false;
  bool playIntro = true;

  ValueChanged<VizTransition>? onTransitionPeak;
  ValueChanged<VizTransition>? onTransitionEnd;

  // -------------------------------------------------------------- inputs

  NetworkTopology _topology;
  NetworkTopology? _next;
  int _stage;
  double _accuracy = 0.1, _progress = 0;
  double _afterglowAt = double.negativeInfinity;
  double _surgeAt = double.negativeInfinity;
  double _autoWaveAt = double.negativeInfinity;
  late Motif _motif;

  NetworkTopology get topology => _topology;
  int get stage => _stage;

  // ------------------------------------------------------- layout cache

  Size _size = Size.zero;
  double _dpr = 1;
  NetworkLayout? _layout;
  NetworkLayout? get layout => _layout;
  VizQuality _quality = VizQuality.high;
  VizQuality get quality => _quality;
  Float32List _strength = Float32List(0);
  Float32List _routeWeight = Float32List(0);
  double _contrast = -1;
  bool _settingsDirty = true;
  bool _ghostDirty = true;
  SpriteAtlas? _atlas;
  SpriteAtlas? get atlas => _atlas;
  late SceneColors _colors;

  final Float32List _ghostX = Float32List(FrameBuffers.maxNeurons);
  final Float32List _ghostY = Float32List(FrameBuffers.maxNeurons);
  final Float32List _ghostR = Float32List(FrameBuffers.maxNeurons);
  int _ghostCount = 0;

  ui.Picture? _background, _network, _previousNetwork;

  /// Pictures replaced during a frame; disposed at the next paint, once no
  /// layer tree being built can reference them.
  final List<ui.Picture> _retired = [];

  void _retire(ui.Picture? picture) {
    if (picture != null) _retired.add(picture);
  }

  ui.Picture? get background => _background;
  ui.Picture? get network => _network;
  ui.Picture? get previousNetwork => _previousNetwork;
  int _backgroundKey = 0;

  SceneTransition? _transition;

  /// Callbacks of superseded transitions, delivered on the next tick.
  final List<VizTransition> _pendingPeaks = [], _pendingEnds = [];

  /// Whether topology changes animate. Off for a frozen external clock,
  /// which would never let a transition finish.
  bool animateTransitions = true;
  SceneTransition? get transition => _transition;

  /// Debug counters.
  int debugLayoutBuilds = 0, debugNetworkRecords = 0;

  // ------------------------------------------------- per-frame scratch

  final Float32List _x = Float32List(FrameBuffers.maxNeurons);
  final Float32List _y = Float32List(FrameBuffers.maxNeurons);
  final Float32List _r = Float32List(FrameBuffers.maxNeurons);
  final Float32List _a = Float32List(FrameBuffers.maxNeurons);
  final Float32List _angle = Float32List(FrameBuffers.maxNeurons);
  final Float32List _actS = Float32List(FrameBuffers.maxNeurons);
  final Float32List _actM = Float32List(FrameBuffers.maxNeurons);

  final Int32List _pathNodes = Int32List(_maxSlots * _maxHops);
  final Float64List _pathCycle = Float64List(_maxSlots);
  final Int32List _burstPath = Int32List(_maxHops);

  // AGI edges inside each unit's angular window, rebuilt every frame.
  final Int32List _ringSrc = Int32List(800), _ringDst = Int32List(800);
  final Float32List _ringFactor = Float32List(800);
  final Float32List _ringStrength = Float32List(800);
  final Uint8List _ringNegative = Uint8List(800);
  int _ringEdges = 0;
  bool _ringEdgesFresh = false;

  /// Whether the static layer should draw the network picture.
  bool get staticNetworkVisible => _transition == null && _layout != null;

  /// Whether frames are needed even with reduced motion: a transition or a
  /// tap fade is running. After a tap, time keeps moving until the next tap
  /// could start a wave, so a ticker stopped in between never stamps the
  /// following taps inside the rate limit (which would swallow them).
  bool isAnimatingAt(double t) =>
      _transition != null || t - taps.lastWaveStart < TapTracker.minWaveGap;

  static const _reducedTapFade = 0.15;

  // ================================================================ inputs

  /// Applies the latest widget values, stamped with scene time [t].
  void setInputs({
    required double t,
    required NetworkTopology topology,
    required int stage,
    NetworkTopology? nextTopology,
    double productionPerSecond = 0,
    int trainingCount = 0,
    double progress = 0,
    double accuracy = 0.1,
  }) {
    if (topology != _topology) {
      _startTransition(t, topology, stage);
    }
    final stageChanged = stage != _stage;
    _stage = stage;
    if (nextTopology != _next) {
      _next = nextTopology;
      _ghostDirty = true;
    }

    final target = productionEnergy(productionPerSecond);
    final quantized = (target * 512).roundToDouble() / 512;
    if (quantized != energy.target) {
      if (quantized - energy.target >= 0.004 &&
          t - _surgeAt >= 1.2 &&
          _transition == null) {
        _surgeAt = t;
      }
      energy.setTarget(t, quantized);
    }

    // Taps while the network transforms (including the one that triggered
    // the change) only heat it: the transition fires its own first wave.
    final transition = _transition;
    taps.update(
      t,
      trainingCount,
      heatOnly: transition != null && !transition.isDone(t),
    );

    _accuracy = accuracy.isNaN ? 0.1 : accuracy.clamp(0.0, 1.0);
    _progress = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);

    // The static layer only repaints when told: a new contrast bucket (the
    // network picture is re-recorded) or stage (the background haze) must
    // reach it now, not at the next resize. Paint can't notify, so do it
    // here, while the widget updates.
    if (_layout != null &&
        (stageChanged ||
            EdgeStyle.contrast(_accuracy, _progress, _next == null) !=
                _contrast)) {
      staticChanges.fire();
    }
  }

  /// Marks theme / quality / caption / background settings as changed.
  void invalidateSettings() {
    _settingsDirty = true;
    staticChanges.fire();
  }

  void _startTransition(double t, NetworkTopology topology, int stage) {
    final running = _transition;
    final previousStage = _stage;
    _topology = topology;
    _motif = motifFor(topology.kind);
    if (running != null && running.notifies) {
      // The superseded transition still reports, on the next tick (never
      // during build), so peak/end listeners stay balanced.
      if (!running.peakFired) _pendingPeaks.add(running.info);
      _pendingEnds.add(running.info);
    }
    if (_layout == null || _size.isEmpty || !animateTransitions) {
      // Nothing drawn yet, or a frozen clock that would never finish a
      // transition: just switch.
      _transition = null;
      _retire(_previousNetwork);
      _previousNetwork = null;
      _layout = null;
      staticChanges.fire();
      return;
    }
    final kind = stage > previousStage
        ? VizTransitionKind.evolve
        : (stage < previousStage
              ? VizTransitionKind.reset
              : VizTransitionKind.crossfade);
    final to = _buildLayout(topology);

    // What is on screen right now becomes the outgoing network. If the
    // running transition hasn't shown its new neurons yet, that is still
    // its own outgoing network (and picture), not its invisible target.
    final NetworkLayout from;
    final Float32List fromX, fromY, fromR, fromA;
    final double fromContrast, initialHandover;
    final ui.Picture? outgoing;
    if (running != null &&
        running.from != null &&
        running.elapsed(t) < running.spawnAt) {
      // Still showing the running transition's outgoing network: inherit it,
      // its picture and how far that picture had handed over.
      from = running.from!;
      fromX = running.fromX;
      fromY = running.fromY;
      fromR = running.fromR;
      fromA = running.fromA;
      fromContrast = running.fromContrast;
      initialHandover = running.handoverAt(running.elapsed(t));
      outgoing = _previousNetwork;
      _retire(_network);
    } else {
      from = _layout!;
      final n = from.neuronCount;
      fromX = Float32List.fromList(Float32List.sublistView(_x, 0, n));
      fromY = Float32List.fromList(Float32List.sublistView(_y, 0, n));
      fromR = Float32List.fromList(Float32List.sublistView(_r, 0, n));
      fromA = Float32List.fromList(Float32List.sublistView(_a, 0, n));
      fromContrast = _contrast;
      _retire(_previousNetwork);
      if (running == null) {
        // Settled: the static picture is what's on screen; hand it over.
        initialHandover = 0;
        outgoing = _network;
      } else {
        // Mid-flight: the dynamic drawing is on screen; take it as is.
        initialHandover = 1;
        outgoing = null;
        _retire(_network);
      }
    }
    final transition = SceneTransition(
      info: VizTransition(kind: kind, fromStage: previousStage, toStage: stage),
      start: t,
      to: to,
      from: from,
      fromX: fromX,
      fromY: fromY,
      fromR: fromR,
      fromA: fromA,
      fromContrast: fromContrast,
      initialHandover: initialHandover,
      reducedMotion: reducedMotion,
    );
    // The outgoing picture (with captions and motif decorations) fades out
    // instead of vanishing on the first frame.
    _previousNetwork = outgoing;
    _network = null;
    _transition = transition;
    // The reborn network fires its first wave as it settles.
    _autoWaveAt = switch (transition.style) {
      TransitionStyle.mitosis ||
      TransitionStyle.collapse => t + transition.settleAt,
      _ => double.negativeInfinity,
    };
    _adoptLayout(to);
    staticChanges.fire();
  }

  // ================================================================== time

  /// Advances transition bookkeeping to scene time [t]: fires the peak and
  /// end callbacks and finishes transitions. Call before painting a frame,
  /// never during paint.
  void tick(double t) {
    if (_pendingPeaks.isNotEmpty || _pendingEnds.isNotEmpty) {
      final peaks = List.of(_pendingPeaks), ends = List.of(_pendingEnds);
      _pendingPeaks.clear();
      _pendingEnds.clear();
      for (final info in peaks) {
        onTransitionPeak?.call(info);
      }
      for (final info in ends) {
        onTransitionEnd?.call(info);
      }
    }
    final transition = _transition;
    if (transition == null) return;
    if (!transition.peakFired && transition.elapsed(t) >= transition.peakAt) {
      transition.peakFired = true;
      if (transition.notifies) onTransitionPeak?.call(transition.info);
    }
    if (transition.isDone(t)) {
      _transition = null;
      _retire(_previousNetwork);
      _previousNetwork = null;
      if (transition.style == TransitionStyle.mitosis) _afterglowAt = t;
      staticChanges.fire();
      if (transition.notifies) onTransitionEnd?.call(transition.info);
    }
  }

  // ================================================================ layout

  /// Builds or refreshes the layout and static pictures for this paint.
  /// The only place that allocates.
  void ensureLayout(Size size, double dpr, double t) {
    for (final picture in _retired) {
      picture.dispose();
    }
    _retired.clear();
    if (size.isEmpty) return;
    if (size != _size || dpr != _dpr) {
      _size = size;
      _dpr = dpr;
      _settingsDirty = true;
    }
    if (_atlas == null || _atlas!.scale != math.min(math.max(dpr, 1.0), 2.0)) {
      _atlas?.release();
      _atlas = SpriteAtlas.acquire(dpr);
    }
    if (_settingsDirty) {
      _settingsDirty = false;
      _colors = SceneColors(theme);
      _quality = requestedQuality != VizQuality.auto
          ? requestedQuality
          : (size.width >= 560 ? VizQuality.high : VizQuality.medium);
      _retire(_background);
      _background = null;
      if (_layout != null) _relayout();
    }
    if (_layout == null) {
      _adoptLayout(_buildLayout(_topology));
      if (playIntro && !reducedMotion) {
        final to = _layout!;
        _transition = SceneTransition(
          info: VizTransition(
            kind: VizTransitionKind.intro,
            fromStage: _stage,
            toStage: _stage,
          ),
          start: t,
          to: to,
          reducedMotion: false,
        );
      }
      playIntro = false;
    }
    final layout = _layout!;

    final contrast = EdgeStyle.contrast(_accuracy, _progress, _next == null);
    if (contrast != _contrast) {
      _contrast = contrast;
      for (var e = 0; e < layout.edgeCount; e++) {
        _strength[e] = EdgeStyle.strength(layout.weight[e], contrast);
      }
      _retire(_network);
      _network = null;
    }
    if (_ghostDirty) {
      _ghostDirty = false;
      _buildGhosts(layout);
    }

    final backgroundKey = Object.hash(
      _stage.clamp(0, 7),
      paintBackground,
      layout.captions.isNotEmpty,
    );
    if (_background == null || backgroundKey != _backgroundKey) {
      _retire(_background);
      _backgroundKey = backgroundKey;
      _background = StaticRecorder.background(
        size,
        theme,
        stage: _stage,
        paintBackground: paintBackground,
        cropMarks: layout.captions.isNotEmpty,
        highContrast: highContrast,
      );
    }
    _network ??= _recordNetwork(layout);
  }

  NetworkLayout _buildLayout(NetworkTopology topology) {
    debugLayoutBuilds++;
    return NetworkLayout.build(
      topology,
      _size,
      devicePixelRatio: _dpr,
      showCaptions: showCaptions,
    );
  }

  /// Rebuilds the layout for a new size or new settings. A transition in
  /// flight carries on at the same progress (and still fires its callbacks)
  /// on layouts rebuilt the same way; the old network restarts from its
  /// rest positions, and a crossfade's outgoing picture, recorded at the
  /// old size, is dropped.
  void _relayout() {
    _adoptLayout(_buildLayout(_topology));
    final tr = _transition;
    if (tr == null) return;
    _retire(_previousNetwork);
    _previousNetwork = null;
    final old = tr.from;
    final from = old == null ? null : _buildLayout(old.topology);
    Float32List? fromX, fromY, fromR;
    if (from != null) {
      final n = from.neuronCount;
      fromX = Float32List.fromList(from.x);
      fromY = Float32List.fromList(from.y);
      fromR = Float32List.fromList(from.radius);
      if (from.isRings) {
        // Rings had turned by the time the transition started.
        final c = from.center;
        for (var i = 0; i < n; i++) {
          final k = from.layerOf[i];
          final angle =
              from.ringAngle[i] + NetworkLayout.ringOmega(k) * tr.start;
          final s = math.sin(angle);
          fromX[i] = c.dx + from.ringRadius[k] * math.cos(angle);
          fromY[i] = c.dy + from.ringRadius[k] * kRingSquash * s;
          fromR[i] = from.radius[i] * (s < 0 ? 0.85 : 1);
        }
      }
    }
    _transition =
        SceneTransition(
            info: tr.info,
            start: tr.start,
            to: _layout!,
            from: from,
            fromX: fromX,
            fromY: fromY,
            fromR: fromR,
            reducedMotion: tr.reducedMotion,
          )
          ..peakFired = tr.peakFired
          ..endFired = tr.endFired;
  }

  void _adoptLayout(NetworkLayout layout) {
    _layout = layout;
    _strength = Float32List(layout.edgeCount);
    _routeWeight = Float32List(layout.edgeCount);
    for (var e = 0; e < layout.edgeCount; e++) {
      final s = EdgeStyle.strength(layout.weight[e], 1);
      _routeWeight[e] = s * s + 1e-4;
    }
    _contrast = -1;
    _ghostDirty = true;
    _pathCycle.fillRange(0, _maxSlots, -1);
    _retire(_network);
    _network = null;
    final n = layout.neuronCount;
    for (var i = 0; i < n; i++) {
      _x[i] = layout.x[i];
      _y[i] = layout.y[i];
      _r[i] = layout.radius[i];
      _a[i] = 1;
    }
  }

  ui.Picture _recordNetwork(NetworkLayout layout) {
    debugNetworkRecords++;
    return StaticRecorder.network(
      StaticContext(
        layout: layout,
        theme: theme,
        strength: _strength,
        contrast: _contrast,
        highContrast: highContrast,
        quality: _quality,
      ),
      _motif,
    );
  }

  /// Positions of the next architecture's neurons that don't overlap the
  /// current ones: where mitosis will put new neurons.
  void _buildGhosts(NetworkLayout layout) {
    _ghostCount = 0;
    final next = _next;
    if (next == null || layout.isRings) return;
    final ghost = NetworkLayout.build(
      next,
      _size,
      devicePixelRatio: _dpr,
      showCaptions: showCaptions,
    );
    for (var g = 0; g < ghost.neuronCount; g++) {
      var free = true;
      for (var n = 0; n < layout.neuronCount && free; n++) {
        final dx = ghost.x[g] - layout.x[n], dy = ghost.y[g] - layout.y[n];
        if (dx * dx + dy * dy < 4 * layout.r * layout.r) free = false;
      }
      if (free && _ghostCount < FrameBuffers.maxNeurons) {
        _ghostX[_ghostCount] = ghost.x[g];
        _ghostY[_ghostCount] = ghost.y[g];
        _ghostR[_ghostCount] = ghost.radius[g];
        _ghostCount++;
      }
    }
  }

  // ============================================================== evaluate

  /// Fills [frame] with everything the dynamic layer draws at time [t].
  void evaluate(double t) {
    final layout = _layout;
    frame.clear();
    if (layout == null || _atlas == null) return;
    frame.glow.atlasScale = _atlas!.scale;
    frame.cores.atlasScale = _atlas!.scale;

    final n = layout.neuronCount;
    // With reduced motion the network holds the still of its kind's hero
    // time, at the current production: only fades (tap feedback,
    // crossfades) follow t. [tm] is the time everything else moves by.
    final still = reducedMotion;
    final tm = still ? layout.kind.heroTime.inMicroseconds / 1e6 : t;
    final e = still ? energy.target : energy.energy(t);
    final heat = still ? 0.0 : taps.heat(t);
    final sinceEvolve = t - _afterglowAt;
    final afterglow = !still && sinceEvolve >= 0 && sinceEvolve < 6
        ? 0.15 * math.exp(-sinceEvolve / 2)
        : 0.0;

    _restPositions(layout, tm);

    final ctx = _ctx
      ..layout = layout
      ..colors = _colors
      ..quality = _quality
      ..t = tm
      ..energy = e
      ..flow = still ? EnergyTrack.speed(e) * tm : energy.flow(t)
      ..heat = heat
      ..accuracy = _accuracy
      ..progress = _next == null ? 0 : _progress
      ..hasNextStage = _next != null
      ..contrast = _contrast
      ..motifAlpha = 1
      ..reducedMotion = reducedMotion
      ..x = _x
      ..y = _y
      ..r = _r
      ..alpha = _a
      ..actS = _actS
      ..actM = _actM;

    // Model activation: a slow breath from input to output, plus smooth
    // flicker while the model is untrained.
    final breathPhase = 2 * math.pi * tm / 5.5;
    final noiseStep = (tm * 1.5).floorToDouble();
    final noiseT = smoothstep(0, 1, tm * 1.5 - noiseStep);
    final flicker = 0.12 * (1 - _contrast);
    for (var i = 0; i < n; i++) {
      final layer = layout.layerOf[i];
      final v = lerp(
        hash01(layout.topology.seed, i, noiseStep.toInt()),
        hash01(layout.topology.seed, i, noiseStep.toInt() + 1),
        noiseT,
      );
      _actS[i] = 0;
      _actM[i] =
          0.10 +
          0.30 * e +
          0.06 * math.sin(breathPhase - 0.6 * layer) +
          flicker * (v - 0.5) * 2;
    }

    var signalAlpha = 1.0;
    final transition = _transition;
    if (transition != null && !transition.isDone(t)) {
      signalAlpha = _evaluateTransition(transition, layout, t, tm);
      ctx.motifAlpha = frame.networkPictureAlpha;
    } else if (layout.isRings) {
      _drawRings(layout, tm);
    }

    if (layout.isRings) _ringEdgesAt(layout, tm);

    _predict(layout, tm);
    if (signalAlpha > 0) {
      _signals(layout, tm, e, heat, afterglow, signalAlpha);
    }
    _waves(layout, t, signalAlpha);
    if (transition == null) _progressEffects(layout, tm);
    _motif.evaluate(ctx);
    _emitNeurons(layout);
  }

  /// Positions at rest: columns are fixed; rings counter-rotate.
  void _restPositions(NetworkLayout layout, double t) {
    _ringEdgesFresh = false;
    final n = layout.neuronCount;
    if (!layout.isRings) {
      for (var i = 0; i < n; i++) {
        _x[i] = layout.x[i];
        _y[i] = layout.y[i];
        _r[i] = layout.radius[i];
        _a[i] = 1;
      }
      return;
    }
    final c = layout.center;
    for (var k = 0; k < layout.layerCount; k++) {
      final omega = NetworkLayout.ringOmega(k);
      final radius = layout.ringRadius[k];
      for (var i = layout.layerStart[k]; i < layout.layerStart[k + 1]; i++) {
        final angle = layout.ringAngle[i] + omega * t;
        final s = math.sin(angle);
        _angle[i] = angle;
        _x[i] = c.dx + radius * math.cos(angle);
        _y[i] = c.dy + radius * kRingSquash * s;
        // The back half of each ring sits further away.
        final back = s < 0;
        _r[i] = layout.radius[i] * (back ? 0.85 : 1);
        _a[i] = back ? 0.7 : 1;
      }
    }
  }

  /// Rotating rings can't be cached: bodies and their edges are drawn here.
  void _drawRings(NetworkLayout layout, double t) {
    _ringEdgesAt(layout, t);
    for (var k = 0; k < _ringEdges; k++) {
      final s = _ringSrc[k], d = _ringDst[k];
      final alpha =
          EdgeStyle.alpha(_ringStrength[k], highContrast: highContrast) *
          _ringFactor[k] *
          math.min(_a[s], _a[d]);
      frame.addBaseEdge(
        _x[s],
        _y[s],
        _x[d],
        _y[d],
        _ringNegative[k] == 1,
        alpha,
        false,
      );
    }
    // Back half first so the front overlaps it.
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < layout.neuronCount; i++) {
        final back = _a[i] < 1;
        if (back != (pass == 0)) continue;
        frame.addBody(_x[i], _y[i], _r[i], _a[i], layout.shape[i]);
      }
    }
  }

  /// Each ring unit links to units on the next ring within ±40°, fading in
  /// from 40° to 22°: as the rings turn, links fade out and form elsewhere.
  void _ringEdgesAt(NetworkLayout layout, double t) {
    // Rest angles only change once per evaluate: compute the links once.
    if (_ringEdgesFresh) return;
    _ringEdgesFresh = true;
    _ringEdges = 0;
    const window = 40 * math.pi / 180, full = 22 * math.pi / 180;
    for (var k = 0; k + 1 < layout.layerCount; k++) {
      for (var a = layout.layerStart[k]; a < layout.layerStart[k + 1]; a++) {
        for (
          var b = layout.layerStart[k + 1];
          b < layout.layerStart[k + 2];
          b++
        ) {
          final d = _angleDistance(_angle[a], _angle[b]);
          if (d >= window || _ringEdges >= _ringSrc.length) continue;
          final w =
              2 *
                  hash01(
                    layout.topology.seed,
                    100 + k,
                    a - layout.layerStart[k],
                    b - layout.layerStart[k + 1],
                  ) -
              1;
          _ringSrc[_ringEdges] = a;
          _ringDst[_ringEdges] = b;
          _ringFactor[_ringEdges] = smoothstep(window, full, d);
          _ringStrength[_ringEdges] = EdgeStyle.strength(w, _contrast);
          _ringNegative[_ringEdges] = w < 0 ? 1 : 0;
          _ringEdges++;
        }
      }
    }
  }

  static int _wrap(int i, int n) {
    final r = i % n;
    return r < 0 ? r + n : r;
  }

  static double _angleDistance(double a, double b) {
    var d = (a - b) % (2 * math.pi);
    if (d < 0) d += 2 * math.pi;
    return d > math.pi ? 2 * math.pi - d : d;
  }

  /// Rotates the predicted class every 3.5 s and lights the outputs by
  /// confidence: the predicted one at max(accuracy, 1/n).
  void _predict(NetworkLayout layout, double t) {
    final last = layout.layerCount - 1;
    final first = layout.layerStart[last];
    final count = layout.layerSize(last);
    final seed = layout.topology.seed;
    final period = (t / 3.5).floor();
    _ctx.predicted = first + hash32(seed, period, 3) % count;
    if (count < 2) return;
    final p = math.max(_accuracy, 1 / count);
    final rest = (1 - p) / (count - 1);
    final fade = smoothstep(0, 0.4, t - period * 3.5);
    final previous = first + hash32(seed, period - 1, 3) % count;
    for (var i = first; i < first + count; i++) {
      var confidence = i == _ctx.predicted ? p : rest;
      if (fade < 1) {
        final before = i == previous ? p : rest;
        confidence = lerp(before, confidence, fade);
      }
      _actS[i] += 0.15 + 0.6 * confidence;
    }
  }

  // ------------------------------------------------------------- signals

  int get _gaps =>
      _layout!.isRings ? _layout!.layerCount + 1 : _layout!.layerCount - 1;

  /// Layer coordinate of a neuron along the signal chain (rings: the core
  /// is 0, ring k is k + 1).
  double _layerPos(NetworkLayout layout, int n) =>
      layout.layerOf[n] + (layout.isRings ? 1.0 : 0.0);

  void _signals(
    NetworkLayout layout,
    double t,
    double e,
    double heat,
    double afterglow,
    double signalAlpha,
  ) {
    final edgeCount = layout.isRings ? _ringEdges : layout.edgeCount;
    final factor = switch (_quality) {
      VizQuality.low => 0.35,
      VizQuality.medium => 0.6,
      _ => 1.0,
    };
    final cap =
        ((_size.width * _size.height / 2600).round().clamp(24, 140) * factor)
            .round();
    final nMax = math.min(cap, 4 + (0.6 * edgeCount).round());
    final drive = math
        .pow(clamp01(e + 0.25 * heat + afterglow), 0.85)
        .toDouble();
    final active = 3 + (nMax - 3) * drive;
    final g = _gaps;
    final cycle = g / 0.8;
    final flow = _ctx.flow;
    final speed = EnergyTrack.speed(e);
    final density = math.min(1.0, math.sqrt((0.5 * edgeCount + 8) / active));
    final seed = layout.topology.seed;
    final slots = math.min(_maxSlots, active.ceil());
    final trails = _quality != VizQuality.low;
    final memoryFor = layout.kind == NetworkKind.rnn ? 1.2 : _memory;

    for (var k = 0; k < slots; k++) {
      final fade = smoothstep(0, 1, active - k) * signalAlpha;
      if (fade <= 0) continue;
      final m = 0.85 + 0.3 * hash01(seed, k, 1);
      final o = hash01(seed, k, 2);
      final phase = flow * m + o * cycle;
      final cyc = (phase / cycle).floorToDouble();
      final s = phase - cyc * cycle;
      final path = _path(layout, k, cyc, t, s, m, speed);
      if (path < 0) continue;
      if (s >= g) {
        // Resting: the last neuron keeps a fading memory of the arrival.
        final last = _pathNodes[path + g];
        if (last >= 0) {
          _actS[last] += 0.6 * math.exp(-(s - g) / (m * speed) / _memory);
        }
        continue;
      }
      final seg = s.floor();
      final u = s - seg;
      final from = _pathNodes[path + seg], to = _pathNodes[path + seg + 1];
      final memory = from >= 0 && layout.layerOf[from] > 0
          ? memoryFor
          : _memory;
      if (from >= 0) {
        _actS[from] += 0.6 * math.exp(-u / (m * speed) / memory);
      }
      final strength = 0.85 * fade * density * (0.6 + 0.4 * e);
      _comet(layout, from, to, u, e, strength, _colors.signal, trails);
    }
  }

  /// Draws a signal head (and trail) a fraction [u] along the edge
  /// [from] → [to]. Node -1 is the AGI core.
  void _comet(
    NetworkLayout layout,
    int from,
    int to,
    double u,
    double e,
    double strength,
    int rgb,
    bool trail,
  ) {
    final c = layout.center;
    final x1 = from < 0 ? c.dx : _x[from], y1 = from < 0 ? c.dy : _y[from];
    final x2 = to < 0 ? c.dx : _x[to], y2 = to < 0 ? c.dy : _y[to];
    final dx = x2 - x1, dy = y2 - y1;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 0.5) return;
    final hx = x1 + dx * u, hy = y1 + dy * u;
    final r = layout.r;
    if (trail) {
      final trailLength = math.min((0.10 + 0.22 * e) * layout.gap, u * length);
      if (trailLength > 2) {
        final angle = math.atan2(dy, dx);
        final ux = dx / length, uy = dy / length;
        frame.glow.add(
          Sprites.streakFor(trailLength),
          hx - ux * trailLength / 2,
          hy - uy * trailLength / 2,
          trailLength,
          rgb,
          0.55 * strength,
          angle,
        );
      }
    }
    frame.glow.add(Sprites.dot, hx, hy, 0.8 * r + 2.5, rgb, strength);
  }

  /// Returns the offset of slot [k]'s path in [_pathNodes] for cycle [cyc],
  /// computing it when the cycle changes. Signals follow strong weights.
  int _path(
    NetworkLayout layout,
    int k,
    double cyc,
    double t,
    double s,
    double m,
    double speed,
  ) {
    final offset = k * _maxHops;
    if (layout.isRings) {
      // Ring links move, so the route is re-derived from where the signal
      // was when it left each neuron (deterministic in t).
      _ringRoute(layout, offset, k, cyc, t, s, m, speed);
      return offset;
    }
    if (_pathCycle[k] == cyc) {
      return _pathNodes[offset] == _deadRoute ? -1 : offset;
    }
    _pathCycle[k] = cyc;
    final seed = layout.topology.seed;
    final cycle = cyc.toInt();
    var node =
        layout.layerStart[0] + hash32(seed, k, cycle) % layout.layerSize(0);
    _pathNodes[offset] = node;
    for (var hop = 1; hop < layout.layerCount; hop++) {
      node = _weightedNext(layout, node, hash01(seed, k, cycle, hop));
      _pathNodes[offset + hop] = node;
      if (node < 0) {
        // Pruned layouts can strand a route; remember it for the whole
        // cycle so every evaluation of this cycle skips the slot alike.
        _pathNodes[offset] = _deadRoute;
        return -1;
      }
    }
    return offset;
  }

  /// Picks the next neuron by route weight. Route weights are the fully
  /// trained strengths (|w|^1.6), not the current contrast's, so a contrast
  /// change never re-routes a signal mid-flight.
  int _weightedNext(NetworkLayout layout, int node, double u) {
    final start = layout.outStart[node], end = layout.outStart[node + 1];
    if (start == end) return -1;
    var total = 0.0;
    for (var i = start; i < end; i++) {
      total += _routeWeight[layout.outEdges[i]];
    }
    var target = u * total;
    for (var i = start; i < end; i++) {
      final edge = layout.outEdges[i];
      target -= _routeWeight[edge];
      if (target <= 0) return layout.edgeDst[edge];
    }
    return layout.edgeDst[layout.outEdges[end - 1]];
  }

  void _ringRoute(
    NetworkLayout layout,
    int offset,
    int k,
    double cyc,
    double t,
    double s,
    double m,
    double speed,
  ) {
    final seed = layout.topology.seed;
    final cycle = cyc.toInt();
    final rings = layout.layerCount;
    _pathNodes[offset] = -1;
    var node = -1;
    for (var hop = 1; hop <= rings; hop++) {
      final ring = hop - 1;
      final first = layout.layerStart[ring], count = layout.layerSize(ring);
      if (node < 0) {
        node = first + hash32(seed, k, cycle, hop) % count;
      } else {
        // When did the signal leave `node`? Then pick, among the two units
        // of the next ring nearest to it at that moment, by hash.
        final departed = t - (s - (hop - 1)) / (m * speed);
        final from =
            layout.ringAngle[node] +
            NetworkLayout.ringOmega(ring - 1) * departed;
        // Units are evenly spaced, so the nearest one is a rounding away and
        // the second nearest is its neighbor on the remainder's side.
        final step = 2 * math.pi / count;
        final base =
            layout.ringAngle[first] + NetworkLayout.ringOmega(ring) * departed;
        final position = (from - base) / step;
        final nearest = position.roundToDouble();
        final best = first + _wrap(nearest.toInt(), count);
        final second =
            first +
            _wrap(nearest.toInt() + (position >= nearest ? 1 : -1), count);
        node = hash01(seed, k, cycle, hop) < 0.7 ? best : second;
      }
      _pathNodes[offset + hop] = node;
    }
    _pathNodes[offset + rings + 1] = -1;
  }

  // --------------------------------------------------------------- waves

  /// Training waves: a forward sheet of light, burst comets, the prediction
  /// check and a violet backprop sweep. Also purchase surges and the first
  /// wave after an evolution.
  void _waves(NetworkLayout layout, double t, double signalAlpha) {
    for (var i = 0; i < TapTracker.maxWaves; i++) {
      final age = t - taps.waveStart[i];
      if (age < 0 || age >= TapTracker.waveLife) continue;
      if (_transition != null) continue; // taps only heat while transforming
      if (reducedMotion) {
        _reducedTap(layout, age);
        continue;
      }
      _wave(layout, age, taps.waveAmp[i], taps.waveSerial[i], full: true);
    }
    final auto = t - _autoWaveAt;
    if (auto >= 0 && auto < TapTracker.waveLife && !reducedMotion) {
      _wave(layout, auto, 1, -1, full: false, check: false);
    }
    final surge = t - _surgeAt;
    if (surge >= 0 && surge < 0.6 && _transition == null && !reducedMotion) {
      _forward(layout, surge / 0.6, 0.4);
    }
  }

  void _reducedTap(NetworkLayout layout, double age) {
    if (age > _reducedTapFade) return;
    final boost = 1 - age / _reducedTapFade;
    for (var i = layout.layerStart[0]; i < layout.layerStart[1]; i++) {
      _actS[i] += 0.8 * boost;
    }
  }

  void _wave(
    NetworkLayout layout,
    double age,
    double amp,
    int serial, {
    required bool full,
    bool check = true,
  }) {
    final g = _gaps;
    final r = layout.r;
    // Ripple on the inputs.
    if (full && age < 0.25) {
      final q = age / 0.25;
      final radius = 3 * r * easeOutCubic(q) + r;
      for (var i = layout.layerStart[0]; i < layout.layerStart[1]; i++) {
        frame.glow.add(
          Sprites.ring,
          _x[i],
          _y[i],
          radius * 2 * 48 / 42,
          _colors.signal,
          0.6 * (1 - q),
        );
      }
    }
    // Forward front.
    if (age < 0.42) _forward(layout, age / 0.42, amp);
    // Burst comets along strong routes.
    if (full) {
      final comets = switch (_quality) {
        VizQuality.low => 4,
        VizQuality.medium => 8,
        _ => 12,
      };
      for (var j = 0; j < comets; j++) {
        final s = (age - 0.03 - 0.03 * j) * 2.2;
        if (s < 0 || s >= g) continue;
        _burstRoute(layout, serial, j);
        final seg = s.floor();
        final from = _burstPath[seg], to = _burstPath[seg + 1];
        _comet(
          layout,
          from,
          to,
          s - seg,
          1,
          0.9 * math.min(1, amp),
          _colors.signal,
          _quality != VizQuality.low,
        );
      }
    }
    // Prediction check on the predicted output.
    if (check && age >= 0.42) {
      final out = _ctx.predicted;
      final correct = hash01(layout.topology.seed, serial, 7) < _accuracy;
      if (correct && age < 0.77) {
        final q = (age - 0.42) / 0.35;
        frame.cores.add(
          Sprites.ring,
          _x[out],
          _y[out],
          2.6 * _r[out] * 2 * 48 / 42,
          _colors.success,
          0.9 * (1 - q),
        );
        frame.cores.add(
          Sprites.dot,
          _x[out],
          _y[out],
          1.4 * _r[out],
          _colors.success,
          0.9 * (1 - q),
        );
      } else if (!correct && age < 0.67) {
        frame.cores.add(
          Sprites.dot,
          _x[out],
          _y[out],
          1.4 * _r[out],
          _colors.accent,
          0.45 * (1 - (age - 0.42) / 0.25),
        );
      }
    }
    // Backprop sweep.
    if (age >= 0.48 && age < 0.98) {
      final xb = g * (1 - (age - 0.48) / 0.5);
      _sweep(layout, xb, 0.35 * amp, backward: true);
    }
  }

  void _forward(NetworkLayout layout, double q, double amp) {
    final xw = _gaps * easeInOutSine(q);
    _sweep(layout, xw, amp, backward: false);
  }

  /// Lights neurons near layer coordinate [front] and the edges it is
  /// crossing: cyan going forward, violet going backward.
  void _sweep(
    NetworkLayout layout,
    double front,
    double amp, {
    required bool backward,
  }) {
    final n = layout.neuronCount;
    for (var i = 0; i < n; i++) {
      final boost = amp * gauss(_layerPos(layout, i) - front, 0.45);
      if (backward) {
        _actM[i] += boost;
      } else {
        _actS[i] += 0.9 * boost;
      }
    }
    final gap = front.floor();
    final f = front - gap;
    final hue = backward ? LineHue.structure : LineHue.signal;
    final lo = backward ? f : math.max(0.0, f - 0.18);
    final hi = backward ? math.min(1.0, f + 0.18) : f;
    if (hi <= lo) return;
    if (layout.isRings) {
      final ring = gap - 1; // gap k + 1 links ring k to ring k + 1
      for (var k = 0; k < _ringEdges; k++) {
        final s = _ringSrc[k];
        if (layout.layerOf[s] != ring) continue;
        _flare(
          s,
          _ringDst[k],
          lo,
          hi,
          hue,
          amp * _ringStrength[k] * _ringFactor[k],
        );
      }
      return;
    }
    if (gap < 0 || gap >= layout.layerCount - 1) return;
    final from = layout.layerStart[gap], to = layout.layerStart[gap + 1];
    for (var src = from; src < to; src++) {
      for (var i = layout.outStart[src]; i < layout.outStart[src + 1]; i++) {
        final edge = layout.outEdges[i];
        _flare(src, layout.edgeDst[edge], lo, hi, hue, amp * _strength[edge]);
      }
    }
  }

  void _flare(int s, int d, double lo, double hi, LineHue hue, double alpha) {
    if (alpha < 0.03) return;
    final dx = _x[d] - _x[s], dy = _y[d] - _y[s];
    frame
        .litBucket(hue, alpha)
        .add(
          _x[s] + dx * lo,
          _y[s] + dy * lo,
          _x[s] + dx * hi,
          _y[s] + dy * hi,
        );
  }

  void _burstRoute(NetworkLayout layout, int serial, int j) {
    final seed = layout.topology.seed;
    if (layout.isRings) {
      _burstPath[0] = -1;
      for (var k = 0; k < layout.layerCount; k++) {
        _burstPath[k + 1] =
            layout.layerStart[k] +
            hash32(seed, 50000 + serial, j, k) % layout.layerSize(k);
      }
      _burstPath[layout.layerCount + 1] = -1;
      return;
    }
    var node =
        layout.layerStart[0] +
        hash32(seed, 50000 + serial, j) % layout.layerSize(0);
    _burstPath[0] = node;
    for (var hop = 1; hop < layout.layerCount; hop++) {
      final next = _weightedNext(
        layout,
        node,
        hash01(seed, 50000 + serial, j, hop),
      );
      node = next < 0 ? node : next;
      _burstPath[hop] = node;
    }
  }

  // ------------------------------------------------------------ progress

  /// Close to the next stage: dashed ghosts where new neurons will appear,
  /// then a violet shimmer and a 1.2 Hz heartbeat.
  void _progressEffects(NetworkLayout layout, double t) {
    if (_next == null) return;
    final p = _progress;
    if (p >= 0.70) {
      var alpha = 0.22 * smoothstep(0.70, 0.90, p);
      if (p >= 0.95 && !reducedMotion) {
        alpha *= 0.75 + 0.25 * math.sin(2 * math.pi * 1.2 * t);
      }
      for (var g = 0; g < _ghostCount; g++) {
        frame.glow.add(
          Sprites.dashRing,
          _ghostX[g],
          _ghostY[g],
          _ghostR[g] * 2.2 * 48 / 42,
          _colors.structure,
          alpha * 3,
        );
      }
    }
    if (p >= 0.85) {
      final pulse = reducedMotion
          ? 1.0
          : 0.6 + 0.4 * math.sin(2 * math.pi * 1.2 * t);
      final boost = 0.22 * smoothstep(0.85, 1, p) * pulse;
      for (var i = 0; i < layout.neuronCount; i++) {
        _actM[i] += boost;
      }
    }
  }

  // -------------------------------------------------------------- neurons

  /// Violet halos (model activation) and cyan hot cores (signals).
  void _emitNeurons(NetworkLayout layout) {
    final halos = switch (_quality) {
      VizQuality.low => 0.15,
      VizQuality.medium => 0.08,
      _ => 0.0,
    };
    for (var i = 0; i < layout.neuronCount; i++) {
      final a = _a[i];
      if (a <= 0.01 || _r[i] <= 0.1) continue;
      final m = clamp01(_actM[i]);
      if (m > halos) {
        frame.glow.add(
          Sprites.glow,
          _x[i],
          _y[i],
          6 * _r[i],
          _colors.structure,
          0.55 * m * a,
        );
      }
      final s = clamp01(_actS[i]);
      if (s > 0.01) {
        frame.cores.add(
          Sprites.dot,
          _x[i],
          _y[i],
          1.1 * _r[i] + 2,
          _colors.signal,
          s * a,
        );
      }
    }
  }

  // ---------------------------------------------------------- transitions

  /// Draws the network while it transforms. Returns the opacity for
  /// signals (0 while the structure is changing). The transition runs on
  /// [t]; rotating rings are placed at the motion time [tm].
  double _evaluateTransition(
    SceneTransition tr,
    NetworkLayout layout,
    double t,
    double tm,
  ) {
    final el = tr.elapsed(t);
    final settle = tr.settleAt;
    final fadeIn = tr.style == TransitionStyle.crossfade
        ? clamp01(el / tr.duration)
        : clamp01((el - settle) / (tr.duration - settle));
    // The static picture fades in over the dynamic drawing. For rings it
    // holds only the guides and motif statics, so it can fade in too.
    frame.networkPictureAlpha = fadeIn;
    if (tr.style == TransitionStyle.crossfade) {
      frame.previousPictureAlpha = 1 - fadeIn;
      for (var i = 0; i < layout.neuronCount; i++) {
        _a[i] *= fadeIn;
      }
      if (layout.isRings) _drawRings(layout, tm);
      return fadeIn;
    }
    final dynamicAlpha = layout.isRings ? 1.0 : 1 - fadeIn;
    final c = layout.center;
    final diagonal = math.sqrt(
      _size.width * _size.width + _size.height * _size.height,
    );

    double newFrom; // when new neurons start appearing
    double gx = c.dx, gy = c.dy; // collapse point / centroid
    final from = tr.from;
    if (from != null) {
      var sx = 0.0, sy = 0.0;
      final count = tr.style == TransitionStyle.collapse
          ? from.layerSize(from.layerCount - 1)
          : from.neuronCount;
      final first = tr.style == TransitionStyle.collapse
          ? from.layerStart[from.layerCount - 1]
          : 0;
      for (var i = first; i < first + count; i++) {
        sx += tr.fromX[i];
        sy += tr.fromY[i];
      }
      if (count > 0) {
        gx = sx / count;
        gy = sy / count;
      }
    }

    // The outgoing picture hands over to the dynamically drawn old network
    // during the first moments, so nothing cuts on the first frame.
    final handover = tr.handoverAt(el);
    if (tr.style == TransitionStyle.mitosis ||
        tr.style == TransitionStyle.collapse) {
      frame.previousPictureAlpha = 1 - handover;
    }

    switch (tr.style) {
      case TransitionStyle.mitosis:
        newFrom = 0.45;
        if (el < 0.8) {
          final push = el < 0.4
              ? 0.025 * easeInCubic(el / 0.4)
              : 0.025 * (1 - easeOutCubic((el - 0.4) / 0.4));
          frame
            ..scale = 1 + push
            ..scaleCenterX = c.dx
            ..scaleCenterY = c.dy;
        }
        if (from != null && el < 0.52) {
          final gather = easeInCubic(el / 0.4);
          final vanish = el < 0.4 ? 1.0 : 1 - (el - 0.4) / 0.12;
          _drawOld(tr, from, 1 + gather, vanish * handover, 0.6 * gather);
        }
        _shockwaves(tr, el, gx, gy, diagonal, 0.4, _colors.structure, 0.6);
        _bloom(el - 0.4, 0.4, gx, gy, 0.5 * diagonal, 0.35);
      case TransitionStyle.collapse:
        newFrom = 0.75;
        if (from != null && el < 0.75) {
          final q = easeInCubic(el / 0.7);
          _drawOld(
            tr,
            from,
            1 - q,
            (1 - clamp01((el - 0.6) / 0.15)) * handover,
            0.3 * q,
            pullX: gx,
            pullY: gy,
            pull: q,
          );
        }
        _shockwaves(tr, el, gx, gy, diagonal, 0.7, _colors.success, 0.45);
        _bloom(el - 0.7, 0.4, gx, gy, 0.25 * diagonal, 0.3);
      case TransitionStyle.unfold:
        newFrom = 0;
      case TransitionStyle.crossfade:
        newFrom = 0;
    }

    // New neurons: divide out of their parents (or unfold from the
    // collapse point) with a springy flight.
    final n = layout.neuronCount;
    final targetsAreRings = layout.isRings;
    for (var i = 0; i < n; i++) {
      final layer = layout.layerOf[i];
      final size = layout.layerSize(layer);
      final index = i - layout.layerStart[layer];
      final restX = _x[i], restY = _y[i], restR = _r[i];
      if (tr.style == TransitionStyle.unfold) {
        final q = clamp01((el - 0.08 * layer) / 0.3);
        _r[i] = restR * math.max(0, easeOutBack(q, 1.7));
        _a[i] = clamp01(q * 3);
        continue;
      }
      final delay =
          newFrom + 0.04 * layer + 0.018 * (index - (size - 1) / 2).abs();
      final q = clamp01((el - delay) / tr.flight);
      final p = tr.parent[i];
      double sx, sy, sr;
      bool moves;
      if (tr.style == TransitionStyle.mitosis && p >= 0) {
        sx = tr.fromX[p];
        sy = tr.fromY[p];
        sr = tr.fromR[p];
        moves = tr.firstChild[i] == 1;
      } else {
        sx = gx;
        sy = gy;
        sr = 0;
        moves = false;
      }
      if (el < newFrom) {
        _a[i] = 0;
        continue;
      }
      final k = easeOutBack(q, 1.2);
      if (targetsAreRings) {
        // Columns swirl into rings: interpolate in polar coordinates.
        final a0 = math.atan2(sy - c.dy, sx - c.dx);
        final r0 = math.sqrt(
          (sx - c.dx) * (sx - c.dx) + (sy - c.dy) * (sy - c.dy),
        );
        final a1 = math.atan2((restY - c.dy) / kRingSquash, restX - c.dx);
        final r1 = layout.ringRadius[layer];
        var da = (a1 - a0) % (2 * math.pi);
        if (da > math.pi) da -= 2 * math.pi;
        if (da < -math.pi) da += 2 * math.pi;
        final angle = a0 + da * k;
        final radius = lerp(r0, r1, k);
        final squash = lerp(1, kRingSquash, easeOutCubic(q));
        _x[i] = c.dx + radius * math.cos(angle);
        _y[i] = c.dy + radius * squash * math.sin(angle);
      } else {
        _x[i] = lerp(sx, restX, k);
        _y[i] = lerp(sy, restY, k);
      }
      _r[i] = moves
          ? lerp(sr, restR, easeOutCubic(q))
          : restR * easeOutCubic(q);
      _a[i] *= moves ? 1 : clamp01(q * 3);
    }

    // Edges weave in from source to target, a bright tip leading.
    final weaveFrom = tr.style == TransitionStyle.unfold ? 0.0 : newFrom + 0.4;
    if (el >= weaveFrom) {
      if (targetsAreRings) {
        _ringEdgesAt(layout, tm);
        for (var k = 0; k < _ringEdges; k++) {
          final s = _ringSrc[k], d = _ringDst[k];
          _weave(
            tr,
            el,
            s,
            d,
            k,
            layout.layerOf[s],
            _ringStrength[k],
            _ringNegative[k] == 1,
            dynamicAlpha * _ringFactor[k],
          );
        }
      } else {
        for (var e = 0; e < layout.edgeCount; e++) {
          final s = layout.edgeSrc[e];
          _weave(
            tr,
            el,
            s,
            layout.edgeDst[e],
            e,
            layout.layerOf[s],
            _strength[e],
            layout.weight[e] < 0,
            dynamicAlpha,
          );
        }
      }
    }
    for (var i = 0; i < n; i++) {
      frame.addBody(_x[i], _y[i], _r[i], _a[i] * dynamicAlpha, layout.shape[i]);
    }
    return el >= settle ? fadeIn : 0;
  }

  void _weave(
    SceneTransition tr,
    double el,
    int s,
    int d,
    int e,
    int layer,
    double strength,
    bool negative,
    double alpha,
  ) {
    final q = clamp01(
      (el - tr.weaveStart(e, layer)) / SceneTransition.weaveDuration,
    );
    if (q <= 0 || _a[s] <= 0 || _a[d] <= 0) return;
    final k = easeOutCubic(q);
    final x2 = lerp(_x[s], _x[d], k), y2 = lerp(_y[s], _y[d], k);
    frame.addBaseEdge(
      _x[s],
      _y[s],
      x2,
      y2,
      negative,
      EdgeStyle.alpha(strength, highContrast: highContrast) * alpha,
      EdgeStyle.isWide(strength),
    );
    if (q < 1) {
      frame.glow.add(Sprites.dot, x2, y2, 4, _colors.signal, 0.8 * (1 - q));
    }
  }

  /// The outgoing network, drawn from the snapshot: brighter while
  /// gathering, then vanishing; pulled towards ([pullX], [pullY]) by
  /// [pull] (0: not at all). Allocation-free, like the rest of evaluate.
  void _drawOld(
    SceneTransition tr,
    NetworkLayout from,
    double edgeGain,
    double visible,
    double glow, {
    double pullX = 0,
    double pullY = 0,
    double pull = 0,
  }) {
    if (visible <= 0) return;
    if (from.isRings) {
      _drawOldRingLinks(tr, from, edgeGain, visible, pullX, pullY, pull);
    } else {
      for (var e = 0; e < from.edgeCount; e++) {
        final s = from.edgeSrc[e], d = from.edgeDst[e];
        final strength = EdgeStyle.strength(from.weight[e], tr.fromContrast);
        final alpha = math.min(
          0.5,
          EdgeStyle.alpha(strength, highContrast: highContrast) * edgeGain,
        );
        frame.addBaseEdge(
          lerp(tr.fromX[s], pullX, pull),
          lerp(tr.fromY[s], pullY, pull),
          lerp(tr.fromX[d], pullX, pull),
          lerp(tr.fromY[d], pullY, pull),
          from.weight[e] < 0,
          alpha * visible,
          EdgeStyle.isWide(strength),
        );
      }
    }
    final shrink = 1 - 0.5 * pull;
    for (var i = 0; i < from.neuronCount; i++) {
      final x = lerp(tr.fromX[i], pullX, pull);
      final y = lerp(tr.fromY[i], pullY, pull);
      final r = tr.fromR[i] * shrink;
      final a = visible * (i < tr.fromA.length ? tr.fromA[i] : 1.0);
      frame.addBody(x, y, r, a, from.shape[i]);
      frame.glow.add(
        Sprites.glow,
        x,
        y,
        6 * r,
        _colors.structure,
        0.55 * clamp01(0.25 + glow) * a,
      );
    }
  }

  /// The old AGI rings' links as they were when the transition started:
  /// each unit to the next ring's units within its ±40° window.
  void _drawOldRingLinks(
    SceneTransition tr,
    NetworkLayout from,
    double edgeGain,
    double visible,
    double pullX,
    double pullY,
    double pull,
  ) {
    const window = 40 * math.pi / 180, full = 22 * math.pi / 180;
    final c = from.center;
    for (var k = 0; k + 1 < from.layerCount; k++) {
      for (var a = from.layerStart[k]; a < from.layerStart[k + 1]; a++) {
        final angleA = math.atan2(
          (tr.fromY[a] - c.dy) / kRingSquash,
          tr.fromX[a] - c.dx,
        );
        for (var b = from.layerStart[k + 1]; b < from.layerStart[k + 2]; b++) {
          final angleB = math.atan2(
            (tr.fromY[b] - c.dy) / kRingSquash,
            tr.fromX[b] - c.dx,
          );
          final d = _angleDistance(angleA, angleB);
          if (d >= window) continue;
          final w =
              2 *
                  hash01(
                    from.topology.seed,
                    100 + k,
                    a - from.layerStart[k],
                    b - from.layerStart[k + 1],
                  ) -
              1;
          final strength = EdgeStyle.strength(w, tr.fromContrast);
          final alpha = math.min(
            0.5,
            EdgeStyle.alpha(strength, highContrast: highContrast) * edgeGain,
          );
          final depth = math.min(
            a < tr.fromA.length ? tr.fromA[a] : 1.0,
            b < tr.fromA.length ? tr.fromA[b] : 1.0,
          );
          frame.addBaseEdge(
            lerp(tr.fromX[a], pullX, pull),
            lerp(tr.fromY[a], pullY, pull),
            lerp(tr.fromX[b], pullX, pull),
            lerp(tr.fromY[b], pullY, pull),
            w < 0,
            alpha * smoothstep(window, full, d) * depth * visible,
            false,
          );
        }
      }
    }
  }

  void _shockwaves(
    SceneTransition tr,
    double el,
    double x,
    double y,
    double diagonal,
    double at,
    int rgb,
    double reach,
  ) {
    final count = tr.style == TransitionStyle.mitosis
        ? tr.info.steps.clamp(1, 3)
        : 1;
    for (var j = 0; j < count; j++) {
      final q = (el - at - 0.12 * j) / 0.9;
      if (q < 0 || q >= 1) continue;
      frame.addRing(
        x,
        y,
        reach * diagonal * easeOutCubic(q),
        0.8 * (1 - q),
        rgb,
      );
    }
  }

  void _bloom(
    double age,
    double life,
    double x,
    double y,
    double size,
    double alpha,
  ) {
    if (age < 0 || age >= life) return;
    frame.glow.add(
      Sprites.glow,
      x,
      y,
      size,
      _colors.structure,
      alpha * (1 - age / life),
    );
  }

  // ------------------------------------------------------------- dispose

  void dispose() {
    for (final picture in _retired) {
      picture.dispose();
    }
    _retired.clear();
    _background?.dispose();
    _network?.dispose();
    _previousNetwork?.dispose();
    _atlas?.release();
    _atlas = null;
    staticChanges.dispose();
  }
}

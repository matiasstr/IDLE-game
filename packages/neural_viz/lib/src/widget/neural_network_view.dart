import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../api/network_topology.dart';
import '../api/viz_theme.dart';
import '../api/viz_types.dart';
import '../render/scene_renderer.dart';
import '../scene/viz_scene.dart';

/// The animated network at the center of the game screen.
///
/// Declarative: pass the current engine values on every rebuild. The view
/// eases and animates internally and never rebuilds widgets per frame. A
/// frame is a pure function of the input history and scene time, so it looks
/// the same at 30, 60 or 120 Hz and in tests.
///
/// Fills its bounded constraints (recommended: desktop 560–900 × 380–520,
/// mobile 360–430 × 240–320).
class NeuralNetworkView extends StatefulWidget {
  const NeuralNetworkView({
    super.key,
    required this.topology,
    required this.stage,
    this.nextTopology,
    this.productionPerSecond = 0,
    this.trainingCount = 0,
    this.progress = 0,
    this.accuracy = 0.1,
    this.onTrain,
    this.onTransitionPeak,
    this.onTransitionEnd,
    this.clock,
    this.theme,
    this.quality = VizQuality.auto,
    this.showCaptions = true,
    this.paintBackground = true,
    this.playIntro = true,
    this.semanticLabel,
  });

  /// What to draw now. A change plays a transition whose kind comes from
  /// [stage].
  final NetworkTopology topology;

  /// Stage index (`GameEngine.stageIndex`). When [topology] changes, a
  /// higher stage plays an evolution, a lower one a reset (a published
  /// paper) and the same stage a crossfade.
  final int stage;

  /// The next stage's topology. Enables the "about to evolve" ghosts and
  /// shimmer; null at the last stage disables them whatever [progress] says.
  final NetworkTopology? nextTopology;

  /// Hardware tokens per second (0 to ~1e12), mapped by [productionEnergy]:
  /// signal count, speed, trail length and glow.
  final double productionPerSecond;

  /// Monotonic count of manual training steps (`GameState.manualTrainings`).
  /// Each increase plays a forward and a backward pass. The first value seen
  /// and any decrease only reset the baseline, so loading a save never
  /// fires a burst.
  final int trainingCount;

  /// Progress to the next stage, 0–1 (`GameEngine.stageProgress`).
  final double progress;

  /// Accuracy 0–1 (`GameEngine.accuracy`): weight contrast, flicker while
  /// untrained and how often a training step predicts correctly.
  final double accuracy;

  /// Tap, click, Space or Enter on the network. When null the view captures
  /// no gestures and is not focusable.
  final VoidCallback? onTrain;

  /// Climax of a transition (evolution 400 ms in, reset 700 ms, crossfade
  /// halfway): a good moment for haptics or the app's stage card.
  final ValueChanged<VizTransition>? onTransitionPeak;
  final ValueChanged<VizTransition>? onTransitionEnd;

  /// External scene clock. When set, no ticker runs, the frame for
  /// `clock.value` is painted and the intro is skipped. For tests,
  /// screenshots and scrubbing.
  final ValueListenable<Duration>? clock;

  final NeuralVizTheme? theme;
  final VizQuality quality;

  /// Layer captions and corner marks (hidden below 380 px of width).
  final bool showCaptions;

  /// Chamber gradient, dot grid, haze and vignette. When false the view is
  /// transparent; keep the surface behind it dark, as glows are additive.
  final bool paintBackground;

  /// Short boot animation on first mount.
  final bool playIntro;

  /// Localized description, e.g. "Neural network: CNN". Without it (and
  /// without [onTrain]) the view is decorative and hidden from semantics.
  final String? semanticLabel;

  @override
  State<NeuralNetworkView> createState() => _NeuralNetworkViewState();
}

class _NeuralNetworkViewState extends State<NeuralNetworkView>
    with SingleTickerProviderStateMixin {
  late final VizScene _scene;
  late final Ticker _ticker;
  late final _FrameClock _frame;
  late SceneRenderer _renderer;
  late final CustomPainter _staticPainter, _dynamicPainter;

  double _tickerBase = 0;
  double _devicePixelRatio = 1;
  bool _reducedMotion = false;
  bool _inputsApplied = false;
  NeuralVizTheme? _theme;
  bool _highContrast = false;

  double get _t => _frame.t;

  @override
  void initState() {
    super.initState();
    _scene = VizScene(topology: widget.topology, stage: widget.stage)
      ..onTransitionPeak = _handlePeak
      ..onTransitionEnd = _handleEnd;
    _frame = _FrameClock(
      widget.clock != null
          ? _seconds(widget.clock!.value)
          : _seconds(widget.topology.kind.heroTime),
    );
    _ticker = createTicker(_onTick);
    _renderer = SceneRenderer(const NeuralVizTheme());
    _staticPainter = _StaticPainter(this);
    _dynamicPainter = _DynamicPainter(this);
    widget.clock?.addListener(_onClock);
  }

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  void _handlePeak(VizTransition t) => widget.onTransitionPeak?.call(t);
  void _handleEnd(VizTransition t) => widget.onTransitionEnd?.call(t);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final theme = _resolveTheme();
    _reducedMotion = reduced;
    _applySettings(theme, highContrast);
    if (!_inputsApplied) {
      _inputsApplied = true;
      _scene.playIntro =
          widget.playIntro && widget.clock == null && !_reducedMotion;
      _applyInputs();
    }
    _syncTicker();
  }

  NeuralVizTheme _resolveTheme() =>
      widget.theme ??
      Theme.of(context).extension<NeuralVizTheme>() ??
      const NeuralVizTheme();

  void _applySettings(NeuralVizTheme theme, bool highContrast) {
    final changed =
        theme != _theme ||
        highContrast != _highContrast ||
        _scene.reducedMotion != _reducedMotion ||
        _scene.requestedQuality != widget.quality ||
        _scene.showCaptions != widget.showCaptions ||
        _scene.paintBackground != widget.paintBackground;
    if (!changed) return;
    _theme = theme;
    _highContrast = highContrast;
    _renderer.update(theme, highContrast: highContrast);
    _scene
      ..theme = theme
      ..highContrast = highContrast
      ..reducedMotion = _reducedMotion
      ..requestedQuality = widget.quality
      ..showCaptions = widget.showCaptions
      ..paintBackground = widget.paintBackground
      ..invalidateSettings();
  }

  void _applyInputs() {
    _scene.setInputs(
      t: _t,
      topology: widget.topology,
      stage: widget.stage,
      nextTopology: widget.nextTopology,
      productionPerSecond: widget.productionPerSecond,
      trainingCount: widget.trainingCount,
      progress: widget.progress,
      accuracy: widget.accuracy,
    );
    _frame.changed();
  }

  @override
  void didUpdateWidget(NeuralNetworkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock?.removeListener(_onClock);
      widget.clock?.addListener(_onClock);
      if (widget.clock != null) _frame.t = _seconds(widget.clock!.value);
    }
    _applySettings(_resolveTheme(), _highContrast);
    _applyInputs();
    _syncTicker();
  }

  /// The ticker runs unless an external clock drives time; with reduced
  /// motion, only while a short fade is playing.
  void _syncTicker() {
    final wanted =
        widget.clock == null && (!_reducedMotion || _scene.isAnimatingAt(_t));
    if (wanted && !_ticker.isActive) {
      _tickerBase = _t;
      _ticker.start();
    } else if (!wanted && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final t = _tickerBase + _seconds(elapsed);
    _scene.tick(t);
    _frame.t = t;
    if (_reducedMotion && !_scene.isAnimatingAt(t)) _ticker.stop();
  }

  void _onClock() {
    final t = _seconds(widget.clock!.value);
    _scene.tick(t);
    _frame.t = t;
  }

  @override
  void reassemble() {
    super.reassemble();
    _scene.invalidateSettings();
  }

  @override
  void dispose() {
    widget.clock?.removeListener(_onClock);
    _ticker.dispose();
    _scene.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget view = RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _staticPainter, isComplex: true),
          ),
          RepaintBoundary(
            child: CustomPaint(
              painter: _dynamicPainter,
              isComplex: true,
              willChange: true,
            ),
          ),
        ],
      ),
    );
    final onTrain = widget.onTrain;
    if (onTrain != null) {
      view = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTrain();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTrain,
            excludeFromSemantics: true,
            child: view,
          ),
        ),
      );
    } else if (widget.semanticLabel != null) {
      view = Semantics(image: true, label: widget.semanticLabel, child: view);
    } else {
      view = ExcludeSemantics(child: view);
    }
    return view;
  }
}

/// Scene time; listeners repaint the dynamic layer.
class _FrameClock extends ChangeNotifier {
  _FrameClock(this._t);

  double _t;
  double get t => _t;
  set t(double value) {
    _t = value;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

class _StaticPainter extends CustomPainter {
  _StaticPainter(this.state) : super(repaint: state._scene.staticChanges);

  final _NeuralNetworkViewState state;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = state._scene;
    scene.ensureLayout(size, state._devicePixelRatio, state._t);
    final background = scene.background;
    if (background != null) canvas.drawPicture(background);
    final network = scene.network;
    if (network != null && scene.staticNetworkVisible) {
      canvas.drawPicture(network);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DynamicPainter extends CustomPainter {
  _DynamicPainter(this.state)
    : super(
        repaint: Listenable.merge([state._frame, state._scene.staticChanges]),
      );

  final _NeuralNetworkViewState state;

  @override
  void paint(Canvas canvas, Size size) {
    final scene = state._scene;
    scene.ensureLayout(size, state._devicePixelRatio, state._t);
    final atlas = scene.atlas;
    if (atlas == null) return;
    scene.evaluate(state._t);
    canvas.clipRect(Offset.zero & size);
    state._renderer.paint(
      canvas,
      scene.frame,
      atlas,
      network: scene.network,
      previousNetwork: scene.previousNetwork,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

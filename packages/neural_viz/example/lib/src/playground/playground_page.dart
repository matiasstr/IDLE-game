import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neural_viz/neural_viz.dart';

import '../widgets/shell.dart';
import 'controls_panel.dart';
import 'playground_model.dart';
import 'scene_clock.dart';
import 'stage_area.dart';

/// The default route: one live view and every input it takes.
///
/// Keyboard: Space trains, ←/→ change stage, P freezes time, `,`/`.` step a
/// frozen clock by 1/60 s and S copies a capture URL for the current still.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key, required this.onNavigate});

  final ValueChanged<ExampleRoute> onNavigate;

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage>
    with TickerProviderStateMixin {
  final PlaygroundModel _model = PlaygroundModel();
  late final SceneClock _clock;
  final FocusNode _keys = FocusNode(debugLabel: 'playground shortcuts');

  /// Keeps the view's state (and its clock) when the layout switches between
  /// one and two columns.
  final GlobalKey _viewKey = GlobalKey(debugLabel: 'network view');

  late final Timer _sim;
  final Stopwatch _simWatch = Stopwatch();
  bool _framePicked = false;
  Size _shownFrame = framePresets[4];

  final ValueNotifier<String?> _notice = ValueNotifier(null);
  Timer? _noticeTimer;
  final ValueNotifier<VizTransition?> _peak = ValueNotifier(null);
  Timer? _peakTimer;

  @override
  void initState() {
    super.initState();
    _clock = SceneClock(vsync: this, start: _model.def.kind.heroTime)
      ..start(reducedMotion: _model.reducedMotion);
    _simWatch.start();
    _sim = Timer.periodic(const Duration(milliseconds: 100), _onSim);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_framePicked) {
      _framePicked = true;
      // Start with the largest preset that fits next to the controls.
      final width = MediaQuery.sizeOf(context).width;
      final room = width >= kTwoColumnWidth
          ? width - kSidebarWidth - 1 - 64 - 2
          : width - 32 - 2;
      final limit = room >= 1100 ? room : math.min(room, 720.0);
      final fitting = framePresets.where((s) => s.width <= limit);
      _model.setFrame(fitting.isEmpty ? framePresets.first : fitting.last);
    }
  }

  @override
  void dispose() {
    _sim.cancel();
    _noticeTimer?.cancel();
    _peakTimer?.cancel();
    _clock.dispose();
    _model.dispose();
    _keys.dispose();
    _notice.dispose();
    _peak.dispose();
    super.dispose();
  }

  void _onSim(Timer _) {
    final dt = _simWatch.elapsedMicroseconds / 1e6;
    _simWatch
      ..reset()
      ..start();
    if (_clock.isFrozen) return;
    _model.advance(math.min(dt, 0.5));
  }

  // ------------------------------------------------------------- actions

  void _toggleFreeze() {
    setState(() => _clock.isFrozen ? _clock.resume() : _clock.freeze());
  }

  void _setReducedMotion(bool value) {
    _clock.reducedMotion = value;
    _model.setReducedMotion(value);
  }

  /// Prints a capture-mode URL that reproduces the current still (freeze
  /// first for an exact frame) and copies it when the clipboard allows.
  Future<void> _copyCaptureUrl() async {
    final params = _model.captureParams(_clock.seconds, _shownFrame);
    final url = Uri.base.replace(queryParameters: params).toString();
    debugPrint('capture: $url');
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } catch (_) {
      copied = false;
    }
    if (!mounted) return;
    _showNotice(copied ? 'Capture URL copied' : 'Capture URL in the console');
  }

  void _showNotice(String text) {
    _notice.value = text;
    _noticeTimer?.cancel();
    _noticeTimer = Timer(
      const Duration(seconds: 2),
      () => _notice.value = null,
    );
  }

  void _onPeak(VizTransition transition) {
    if (transition.kind == VizTransitionKind.intro) return;
    _peak.value = transition;
    _peakTimer?.cancel();
    _peakTimer = Timer(
      const Duration(milliseconds: 1800),
      () => _peak.value = null,
    );
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is KeyDownEvent;
    if (!down && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      _model.train();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (down) _model.previous();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (down) _model.next();
    } else if (key == LogicalKeyboardKey.keyP) {
      if (down) _toggleFreeze();
    } else if (key == LogicalKeyboardKey.comma) {
      _clock.step(-1);
    } else if (key == LogicalKeyboardKey.period) {
      _clock.step(1);
    } else if (key == LogicalKeyboardKey.keyS) {
      if (down) _copyCaptureUrl();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// Sliders and buttons keep focus after a click; hand it back to the page
  /// so the shortcuts keep working.
  void _reclaimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_keys.hasPrimaryFocus) _keys.requestFocus();
    });
  }

  // -------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return ExampleShell(
      route: ExampleRoute.playground,
      onNavigate: widget.onNavigate,
      trailing: const ShortcutHintsRow(),
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (_) => _reclaimFocus(),
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) => LayoutBuilder(builder: _layout),
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final twoColumns = constraints.maxWidth >= kTwoColumnWidth;
    // One column: 16 px gutters, narrowed (down to 12) so the smallest
    // preset still fits unscaled on a 390 px phone.
    final pad = twoColumns
        ? 32.0
        : ((constraints.maxWidth - framePresets.first.width - 2) / 2)
              .clamp(12.0, 16.0)
              .floorToDouble();
    final stageWidth = twoColumns
        ? constraints.maxWidth - kSidebarWidth - 1
        : constraints.maxWidth;
    // The 1 px border is drawn outside the view.
    final frame = _fit(_model.frame, stageWidth - 2 * pad - 2);
    _shownFrame = frame;

    // One column keeps the view pinned above the scrolling controls when
    // there is room, so every change can be seen as it is made.
    final pinned =
        !twoColumns &&
        constraints.maxHeight >= frame.height + _kStageChrome + 280;

    final stage = StageArea(
      model: _model,
      frame: frame,
      clock: _clock,
      notice: _notice,
      peak: _peak,
      viewKey: _viewKey,
      onTransitionPeak: _onPeak,
      onCopyUrl: _copyCaptureUrl,
      showInsights: twoColumns,
    );
    final controls = ControlsPanel(
      model: _model,
      frozen: _clock.isFrozen,
      onToggleFreeze: _toggleFreeze,
      onStep: _clock.step,
      onCopyUrl: _copyCaptureUrl,
      onReducedMotion: _setReducedMotion,
      showShortcuts: !twoColumns,
    );
    final insights = PlaygroundInsights(
      model: _model,
      wide: frame.width >= 620,
    );

    if (pinned) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: EdgeInsets.fromLTRB(pad, 16, pad, 6), child: stage),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, 22, pad, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [controls, const SizedBox(height: 32), insights],
              ),
            ),
          ),
        ],
      );
    }
    if (!twoColumns) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stage,
            const SizedBox(height: 28),
            controls,
            const SizedBox(height: 32),
            insights,
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 28, pad, 40),
            child: stage,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        SizedBox(
          width: kSidebarWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: controls,
          ),
        ),
      ],
    );
  }

  /// The preset, scaled down (aspect kept) when the screen is narrower.
  static Size _fit(Size preset, double available) {
    if (preset.width <= available) return preset;
    final width = math.max(available, 200.0).floorToDouble();
    return Size(width, (preset.height * width / preset.width).floorToDouble());
  }
}

const kTwoColumnWidth = 1040.0;
const kSidebarWidth = 344.0;

/// Height of the stage area around the frame (header, gaps, status line and
/// padding) in the pinned one-column layout.
const _kStageChrome = 140.0;

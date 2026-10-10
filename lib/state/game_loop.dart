import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/state/game_controller.dart';

/// Runs the game while [child] is on screen: advances the engine ten times
/// per second, credits time spent in the background as offline progress and
/// saves when the app is hidden.
class GameLoop extends ConsumerStatefulWidget {
  const GameLoop({super.key, required this.child});

  final Widget child;

  /// Seconds of play per game update (the UI refreshes at this rate; the
  /// network animation runs at the display's frame rate on its own).
  static const step = 0.1;

  /// A gap between frames longer than this means the app wasn't running
  /// (hidden tab, backgrounded app): it's credited as offline progress.
  static const awayThreshold = Duration(seconds: 5);

  @override
  ConsumerState<GameLoop> createState() => _GameLoopState();
}

class _GameLoopState extends ConsumerState<GameLoop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool? _reducedMotion;
  Duration _last = Duration.zero;
  late DateTime _lastWall;
  double _pending = 0;

  GameController get _controller => ref.read(gameControllerProvider.notifier);
  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _lifecycle = AppLifecycleListener(onHide: _save, onPause: _save);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With reduced motion nothing animates, so a timer drives the game
    // instead of the ticker, which would make every frame render.
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    _ticker.stop();
    _timer?.cancel();
    _last = Duration.zero;
    _lastWall = _now();
    if (reduced) {
      _timer = Timer.periodic(
        Duration(microseconds: (GameLoop.step * 1e6).round()),
        (_) => _onTimer(),
      );
    } else {
      unawaited(_ticker.start());
    }
  }

  void _onTick(Duration elapsed) {
    // Frame timestamps stop while the device sleeps; the wall clock doesn't.
    // The larger of the two gaps is the time the game wasn't running.
    final now = _now();
    final frameGap = elapsed - _last;
    final wallGap = now.difference(_lastWall);
    _last = elapsed;
    _lastWall = now;
    // Normal play is measured with frame time (exact, and fakeable in
    // tests); the wall clock only catches sleeps.
    _advance(frameGap, wallGap > frameGap ? wallGap : frameGap);
  }

  void _onTimer() {
    // Like frames, the timer pauses while the app is hidden (browsers would
    // only throttle it), so the whole absence is credited when it's back.
    if (!SchedulerBinding.instance.framesEnabled) return;
    final now = _now();
    final gap = now.difference(_lastWall);
    _lastWall = now;
    _advance(gap, gap);
  }

  /// Plays [played], unless [gap] says the game wasn't running: then the
  /// whole gap is credited as time away.
  void _advance(Duration played, Duration gap) {
    if (gap > GameLoop.awayThreshold) {
      _pending = 0;
      unawaited(_controller.resumeAfter(gap));
      return;
    }
    if (played <= Duration.zero) return; // e.g. the clock was set back
    _pending += played.inMicroseconds / Duration.microsecondsPerSecond;
    if (_pending >= GameLoop.step) {
      _controller.tick(_pending);
      _pending = 0;
    }
  }

  void _save() => _controller.save();

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

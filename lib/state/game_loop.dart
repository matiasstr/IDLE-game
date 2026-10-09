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
  Duration _last = Duration.zero;
  double _pending = 0;

  GameController get _controller => ref.read(gameControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _lifecycle = AppLifecycleListener(onHide: _save, onPause: _save);
  }

  void _onTick(Duration elapsed) {
    final gap = elapsed - _last;
    _last = elapsed;
    if (gap > GameLoop.awayThreshold) {
      _pending = 0;
      _controller.resumeAfter(gap);
      return;
    }
    _pending += gap.inMicroseconds / Duration.microsecondsPerSecond;
    if (_pending >= GameLoop.step) {
      _controller.tick(_pending);
      _pending = 0;
    }
  }

  void _save() => _controller.save();

  @override
  void dispose() {
    _ticker.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

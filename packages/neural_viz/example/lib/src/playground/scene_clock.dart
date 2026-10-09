import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// What the status line shows about time.
@immutable
class ClockStatus {
  const ClockStatus(this.seconds, this.fps, this.mode);

  final double seconds;
  final double fps;
  final ClockMode mode;
}

enum ClockMode { running, frozen, still }

/// Tracks the scene time of a [NeuralNetworkView] that runs its own ticker,
/// so the playground can freeze it without a jump.
///
/// The view starts at `kind.heroTime` and adds its ticker's elapsed time. A
/// ticker started in the same frame gets the same start timestamp, so this
/// mirror reads exactly the view's time. Freezing hands the view
/// [frozenClock] (an external clock) at the mirrored time; resuming removes
/// it, and both tickers restart from the frozen value in the same frame.
///
/// With reduced motion the view's ticker only runs for short fades, which the
/// mirror does not follow; a freeze after such fades may move the still by a
/// fraction of a second.
class SceneClock {
  SceneClock({required TickerProvider vsync, required Duration start})
    : _seconds = start.inMicroseconds / 1e6 {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  double _base = 0;
  double _seconds;
  bool _frozen = false;
  bool _still = false;
  double _fps = 0;
  double _lastStatus = double.negativeInfinity;

  /// The clock the view gets while frozen.
  final ValueNotifier<Duration> frozenClock = ValueNotifier(Duration.zero);

  /// Refreshed about four times per second while running.
  final ValueNotifier<ClockStatus> status = ValueNotifier(
    const ClockStatus(0, 0, ClockMode.running),
  );

  bool get isFrozen => _frozen;

  /// Current scene time in seconds.
  double get seconds =>
      _frozen ? frozenClock.value.inMicroseconds / 1e6 : _seconds;

  /// Call once from `initState`, in the frame the view mounts.
  void start({required bool reducedMotion}) {
    _still = reducedMotion;
    _sync();
  }

  /// Mirrors the view's ticker, which stops under reduced motion. Stopping is
  /// deferred to the end of the frame, where the view stops too.
  set reducedMotion(bool value) {
    if (value == _still) return;
    _still = value;
    if (value) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    } else {
      _sync();
    }
    _publish(force: true);
  }

  void freeze() {
    if (_frozen) return;
    _frozen = true;
    _sync();
    frozenClock.value = Duration(microseconds: (_seconds * 1e6).round());
    _publish(force: true);
  }

  void resume() {
    if (!_frozen) return;
    _seconds = frozenClock.value.inMicroseconds / 1e6;
    _frozen = false;
    _sync();
    _publish(force: true);
  }

  /// Moves a frozen clock by [frames] sixtieths of a second.
  void step(int frames) {
    if (!_frozen) return;
    final us = frozenClock.value.inMicroseconds + (frames * 1e6 / 60).round();
    frozenClock.value = Duration(microseconds: math.max(0, us));
    _publish(force: true);
  }

  void _sync() {
    final run = !_frozen && !_still;
    if (run && !_ticker.isActive) {
      _base = _seconds;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final t = _base + elapsed.inMicroseconds / 1e6;
    final dt = t - _seconds;
    _seconds = t;
    if (dt > 0 && dt < 0.25) {
      final instant = 1 / dt;
      _fps = _fps == 0 ? instant : _fps + (instant - _fps) * 0.1;
    }
    _publish();
  }

  void _publish({bool force = false}) {
    final now = seconds;
    if (!force && (now - _lastStatus).abs() < 0.25) return;
    _lastStatus = now;
    status.value = ClockStatus(
      now,
      _fps,
      _frozen
          ? ClockMode.frozen
          : (_still ? ClockMode.still : ClockMode.running),
    );
  }

  void dispose() {
    _ticker.dispose();
    frozenClock.dispose();
    status.dispose();
  }
}

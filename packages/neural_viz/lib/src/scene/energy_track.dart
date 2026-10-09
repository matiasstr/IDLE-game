import 'dart:math' as math;

/// Production energy over scene time, eased towards each new target, and the
/// "flow time" that signals travel by.
///
/// Both are closed-form between input events, so a frame depends only on the
/// input history and the time asked for, never on frame pacing:
///
///   E(t) = T + (E₀ − T)·e^(−Δ/τ)
///   v(E) = 1.2 + 1.6·E                       (layer gaps per second)
///   flow(t) = flow₀ + ∫ v(E) dt
///           = flow₀ + 1.2Δ + 1.6·[TΔ + (E₀ − T)·τ·(1 − e^(−Δ/τ))]
class EnergyTrack {
  /// Easing time constant, in seconds.
  static const tau = 0.6;
  static const baseSpeed = 1.2, energySpeed = 1.6;

  bool _started = false;
  double _t0 = 0, _e0 = 0, _target = 0, _flow0 = 0;

  double get target => _target;

  /// Speed of signals at energy [e], in layer gaps per second.
  static double speed(double e) => baseSpeed + energySpeed * e;

  /// Sets a new target at scene time [t]. The first call starts at the
  /// target with no easing.
  void setTarget(double t, double target) {
    if (!_started) {
      _started = true;
      _t0 = t;
      _e0 = target;
      _target = target;
      _flow0 = 0;
      return;
    }
    if (target == _target) return;
    final e = energy(t), f = flow(t);
    _t0 = t;
    _e0 = e;
    _flow0 = f;
    _target = target;
  }

  double energy(double t) {
    final dt = t - _t0;
    if (dt <= 0) return _e0;
    return _target + (_e0 - _target) * math.exp(-dt / tau);
  }

  double flow(double t) {
    final dt = t - _t0;
    if (dt <= 0) return _flow0 + speed(_e0) * dt;
    return _flow0 +
        baseSpeed * dt +
        energySpeed *
            (_target * dt + (_e0 - _target) * tau * (1 - math.exp(-dt / tau)));
  }
}

import 'dart:math' as math;

// Allocation-free easing helpers for the per-frame path.

double clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double lerp(double a, double b, double t) => a + (b - a) * t;

/// Hermite step between [edge0] and [edge1]. Works for edge0 > edge1 too,
/// which gives a falling step.
double smoothstep(double edge0, double edge1, double x) {
  final t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

double easeOutCubic(double t) {
  final u = 1 - clamp01(t);
  return 1 - u * u * u;
}

double easeInCubic(double t) {
  final u = clamp01(t);
  return u * u * u;
}

double easeInOutCubic(double t) {
  final u = clamp01(t);
  return u < 0.5 ? 4 * u * u * u : 1 - math.pow(-2 * u + 2, 3) / 2;
}

double easeInOutSine(double t) => -(math.cos(math.pi * clamp01(t)) - 1) / 2;

/// Overshoots by [s] before settling (s = 1.70158 is the classic back).
double easeOutBack(double t, [double s = 1.2]) {
  final u = clamp01(t) - 1;
  return 1 + (s + 1) * u * u * u + s * u * u;
}

/// Gaussian bump centered at 0.
double gauss(double x, double sigma) =>
    math.exp(-(x * x) / (2 * sigma * sigma));

/// Decays from 1 by e every [tau] seconds; 0 before [dt] starts.
double decay(double dt, double tau) => dt < 0 ? 0 : math.exp(-dt / tau);

double fract(double x) => x - x.floorToDouble();

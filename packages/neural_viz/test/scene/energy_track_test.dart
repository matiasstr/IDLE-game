import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/src/scene/energy_track.dart';
import 'package:neural_viz/src/scene/hash.dart';

/// A deterministic sequence of (time, target) events.
List<(double, double)> _events(int seed) {
  final events = <(double, double)>[];
  var t = hash01(seed, 0) * 2;
  final count = 1 + hash32(seed, 1) % 12;
  for (var i = 0; i < count; i++) {
    events.add((t, hash01(seed, 2, i)));
    // Mostly frame-scale gaps, sometimes long pauses.
    t += hash01(seed, 3, i) < 0.3
        ? hash01(seed, 4, i) * 0.05
        : hash01(seed, 5, i) * 2.5;
  }
  return events;
}

/// Integrates dE/dt = (T − E)/τ and d(flow)/dt = v(E) numerically with RK4,
/// from the first event to [end].
(double energy, double flow) _integrate(
  List<(double, double)> events,
  double end, {
  double dt = 1e-3,
}) {
  var e = events.first.$2;
  var flow = 0.0;
  var t = events.first.$1;
  var next = 1;
  var target = e;
  while (t < end) {
    // Step exactly onto the next event so the target changes there.
    final until = next < events.length && events[next].$1 < end
        ? events[next].$1
        : end;
    while (t < until) {
      final h = t + dt > until ? until - t : dt;
      double de(double e) => (target - e) / EnergyTrack.tau;
      double df(double e) => EnergyTrack.speed(e);
      final k1e = de(e), k1f = df(e);
      final k2e = de(e + h / 2 * k1e), k2f = df(e + h / 2 * k1e);
      final k3e = de(e + h / 2 * k2e), k3f = df(e + h / 2 * k2e);
      final k4e = de(e + h * k3e), k4f = df(e + h * k3e);
      e += h / 6 * (k1e + 2 * k2e + 2 * k3e + k4e);
      flow += h / 6 * (k1f + 2 * k2f + 2 * k3f + k4f);
      t += h;
    }
    t = until;
    if (next < events.length && events[next].$1 <= t) {
      target = events[next].$2;
      next++;
    }
  }
  return (e, flow);
}

EnergyTrack _track(List<(double, double)> events, double until) {
  final track = EnergyTrack();
  for (final (t, target) in events) {
    if (t > until) break;
    track.setTarget(t, target);
  }
  return track;
}

void main() {
  group('EnergyTrack', () {
    test('starts at the first target with no easing', () {
      final track = EnergyTrack()..setTarget(1, 0.7);
      expect(track.energy(1), 0.7);
      expect(track.energy(5), 0.7);
      expect(track.flow(1), 0);
      expect(track.flow(3), closeTo(2 * EnergyTrack.speed(0.7), 1e-12));
    });

    test('eases towards a new target with time constant τ', () {
      final track = EnergyTrack()
        ..setTarget(0, 0)
        ..setTarget(1, 1);
      expect(track.energy(1), 0);
      expect(track.energy(1 + EnergyTrack.tau), closeTo(1 - 0.36787944, 1e-6));
      expect(track.energy(20), closeTo(1, 1e-9));
      expect(track.target, 1);
    });

    test('closed form matches numerical integration of v(E(t))', () {
      for (var seed = 0; seed < 200; seed++) {
        final events = _events(seed);
        final end = events.last.$1 + 1.5;
        for (final probe in [
          events.first.$1 + 0.01,
          (events.first.$1 + end) / 2,
          end,
        ]) {
          final (e, flow) = _integrate(events, probe);
          final track = _track(events, probe);
          expect(track.energy(probe), closeTo(e, 1e-9), reason: 'seed $seed');
          expect(track.flow(probe), closeTo(flow, 1e-9), reason: 'seed $seed');
        }
      }
    });

    test(
      'values depend on the input history, not on how often they are read',
      () {
        final events = _events(7);
        final once = _track(events, 100);
        const at = 7.3;
        final energyOnce = once.energy(at), flowOnce = once.flow(at);
        for (final step in const [1 / 60, 1 / 120, 1 / 30, 0.0137]) {
          final stepped = _track(events, 100);
          for (var t = 0.0; t < at; t += step) {
            stepped
              ..energy(t)
              ..flow(t);
          }
          expect(stepped.energy(at), energyOnce);
          expect(stepped.flow(at), flowOnce);
        }
      },
    );

    test('flow keeps moving forward and is continuous at events', () {
      final events = _events(3);
      final track = EnergyTrack();
      var previous = double.negativeInfinity;
      var nextEvent = 0;
      for (var t = events.first.$1; t < events.last.$1 + 2; t += 0.01) {
        while (nextEvent < events.length && events[nextEvent].$1 <= t) {
          final before = nextEvent == 0 ? null : track.flow(t);
          track.setTarget(t, events[nextEvent].$2);
          if (before != null) expect(track.flow(t), closeTo(before, 1e-12));
          nextEvent++;
        }
        final f = track.flow(t);
        expect(f, greaterThanOrEqualTo(previous));
        previous = f;
      }
    });

    test('setting the same target again changes nothing', () {
      final a = EnergyTrack()
        ..setTarget(0, 0.2)
        ..setTarget(1, 0.8);
      final b = EnergyTrack()
        ..setTarget(0, 0.2)
        ..setTarget(1, 0.8)
        ..setTarget(1.5, 0.8)
        ..setTarget(2.5, 0.8);
      for (var t = 0.0; t < 5; t += 0.25) {
        expect(b.energy(t), a.energy(t));
        expect(b.flow(t), a.flow(t));
      }
    });
  });
}

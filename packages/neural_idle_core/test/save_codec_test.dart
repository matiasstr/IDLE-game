import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:test/test.dart';

void main() {
  const codec = SaveCodec();
  final savedAt = DateTime.utc(2026, 10, 9, 12);

  test('round-trips a game', () {
    const state = GameState(
      tokens: 1234.5,
      runTokens: 5678.25,
      lifetimeTokens: 1e12,
      citations: 7,
      generators: {'laptop': 12, 'gaming_gpu': 3},
      upgrades: {'relu', 'dropout'},
      manualTrainings: 321,
      papersPublished: 2,
      playSeconds: 3600.5,
    );
    final decoded = codec.decode(codec.encode(state, savedAt: savedAt))!;
    expect(decoded.state, state);
    expect(decoded.savedAt, savedAt);
  });

  test('rejects anything that is not a save', () {
    for (final raw in [
      '',
      'not json',
      '[]',
      '{}',
      '{"version": "1"}',
      '{"version": 1}',
      '{"version": 1, "savedAt": "yesterday"}',
    ]) {
      expect(codec.decode(raw), isNull, reason: raw);
    }
  });

  test('drops hardware and research that no longer exist', () {
    const raw = '{"version": 1, "savedAt": "2026-10-09T12:00:00Z", '
        '"generators": {"laptop": 3, "floppy_disk": 9, "gaming_gpu": 0}, '
        '"upgrades": ["relu", "blockchain", 42]}';
    final state = codec.decode(raw)!.state;
    expect(state.generators, {'laptop': 3});
    expect(state.upgrades, {'relu'});
  });

  test('resets invalid numbers', () {
    const raw = '{"version": 1, "savedAt": "2026-10-09T12:00:00Z", '
        '"tokens": -5, "runTokens": 50, "lifetimeTokens": 10, '
        '"citations": 1.5, "manualTrainings": -1, "playSeconds": "long"}';
    final state = codec.decode(raw)!.state;
    expect(state.tokens, 0);
    expect(state.runTokens, 50);
    expect(state.lifetimeTokens, 50, reason: 'never below the current run');
    expect(state.citations, 0);
    expect(state.manualTrainings, 0);
    expect(state.playSeconds, 0);
  });

  test('saves non-finite numbers without throwing', () {
    final raw = codec.encode(
      const GameState(tokens: double.infinity, runTokens: double.nan),
      savedAt: savedAt,
    );
    final state = codec.decode(raw)!.state;
    expect(state.tokens, double.maxFinite);
    expect(state.runTokens, 0);
  });
}

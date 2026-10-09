import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rules of the game, with the standard content.
final gameEngineProvider = Provider<GameEngine>((ref) => const GameEngine());

/// Wall clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final gameControllerProvider = NotifierProvider<GameController, GameSession>(
  GameController.new,
);

/// The player's game plus what the UI still has to tell them.
@immutable
class GameSession {
  const GameSession({required this.state, this.offline});

  final GameState state;

  /// Progress credited for time away, shown once and then dismissed.
  final OfflineProgress? offline;
}

/// Owns the [GameState]: applies the player's actions and time through the
/// engine, and keeps the save in [SharedPreferences] up to date.
class GameController extends Notifier<GameSession> {
  static const saveKey = 'neural_idle.save';

  /// Absences shorter than this are credited silently.
  static const reportedAbsence = Duration(minutes: 1);

  /// Seconds of play between autosaves.
  static const autosaveInterval = 10.0;

  double _sinceSave = 0;

  GameEngine get engine => ref.read(gameEngineProvider);
  SaveCodec get _codec => SaveCodec(engine.content);
  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  GameSession build() {
    ref.watch(gameEngineProvider);
    final raw = _preferences.getString(saveKey);
    final saved = raw == null ? null : _codec.decode(raw);
    if (saved == null) return const GameSession(state: GameState.initial);
    return _afterAbsence(saved.state, _now().difference(saved.savedAt));
  }

  GameSession _afterAbsence(
    GameState game,
    Duration away, [
    OfflineProgress? pending,
  ]) {
    final progress = engine.applyOfflineProgress(game, away);
    final worthTelling =
        progress.credited >= reportedAbsence && progress.tokensEarned > 0;
    return GameSession(
      state: progress.state,
      offline: worthTelling ? progress : pending,
    );
  }

  /// Advances the game by [seconds] of foreground play.
  void tick(double seconds) {
    if (!(seconds > 0)) return;
    _update(engine.advance(state.state, seconds));
    _sinceSave += seconds;
    if (_sinceSave >= autosaveInterval) save();
  }

  /// Credits time the game wasn't running: a hidden browser tab or an app
  /// in the background.
  void resumeAfter(Duration away) {
    state = _afterAbsence(state.state, away, state.offline);
    save();
  }

  /// One manual training step.
  void train() => _update(engine.train(state.state));

  bool buyGenerator(String generatorId, {int quantity = 1}) =>
      _apply(engine.buyGenerator(state.state, generatorId, quantity: quantity));

  bool buyUpgrade(String upgradeId) =>
      _apply(engine.buyUpgrade(state.state, upgradeId));

  /// Prestige: restarts the run for permanent citations.
  bool publishPaper() {
    final applied = _apply(engine.publishPaper(state.state));
    if (applied) save();
    return applied;
  }

  void resetProgress() {
    state = const GameSession(state: GameState.initial);
    save();
  }

  /// The current save as text, for backups and moving between devices.
  String exportSave() => _codec.encode(state.state, savedAt: _now());

  /// Replaces the game with an exported save. Returns false if [raw] isn't
  /// a valid save.
  bool importSave(String raw) {
    final data = _codec.decode(raw.trim());
    if (data == null) return false;
    state = GameSession(state: data.state);
    save();
    return true;
  }

  void dismissOffline() {
    if (state.offline != null) state = GameSession(state: state.state);
  }

  void save() {
    _sinceSave = 0;
    unawaited(
      _preferences.setString(
        saveKey,
        _codec.encode(state.state, savedAt: _now()),
      ),
    );
  }

  bool _apply(GameState? next) {
    if (next == null) return false;
    _update(next);
    return true;
  }

  void _update(GameState next) =>
      state = GameSession(state: next, offline: state.offline);
}

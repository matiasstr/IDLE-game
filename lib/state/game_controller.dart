import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_viz/neural_viz.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The rules of the game, with the standard content.
final gameEngineProvider = Provider<GameEngine>((ref) => const GameEngine());

/// Wall clock, overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final gameControllerProvider = NotifierProvider<GameController, GameSession>(
  GameController.new,
);

/// Training loss of the current run, for the loss chart. Saved with the
/// game; a missing or corrupt copy starts a fresh chart.
final lossHistoryProvider = Provider<LossHistory>((ref) {
  final raw = ref
      .watch(sharedPreferencesProvider)
      .getString(GameController.lossKey);
  var history = _freshLossHistory();
  if (raw != null) {
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) history = LossHistory.fromJson(json);
    } on Object {
      // Corrupt or out-of-range data: keep the fresh chart.
    }
  }
  ref.onDispose(history.dispose);
  return history;
});

/// A visible minibatch wiggle, like a real training curve.
LossHistory _freshLossHistory() => LossHistory(noise: 0.12);

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
  static const lossKey = 'neural_idle.loss';

  /// Absences shorter than this are credited silently.
  static const reportedAbsence = Duration(minutes: 1);

  /// Seconds of play between autosaves.
  static const autosaveInterval = 10.0;

  double _sinceSave = 0;
  double _sinceLossSample = 0;

  /// When this instance last wrote (or loaded) the save. A stored save newer
  /// than this was written by another tab or window.
  DateTime? _lastWrite;

  GameEngine get engine => ref.read(gameEngineProvider);
  SaveCodec get _codec => SaveCodec(engine.content);
  SharedPreferences get _preferences => ref.read(sharedPreferencesProvider);
  DateTime _now() => ref.read(clockProvider)();
  LossHistory get _loss => ref.read(lossHistoryProvider);

  @override
  GameSession build() {
    ref.watch(gameEngineProvider);
    final saved = _readSave();
    _lastWrite = saved?.savedAt;
    if (saved == null) return const GameSession(state: GameState.initial);
    final session = _afterAbsence(
      saved.state,
      _now().difference(saved.savedAt),
    );
    if (session.offline != null) {
      // Evolutions while away belong on the loss chart too.
      _trackStages(saved.state, session.state);
      _loss.add(engine.loss(session.state));
    }
    return session;
  }

  SaveData? _readSave() {
    final raw = _preferences.getString(saveKey);
    return raw == null ? null : _codec.decode(raw);
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
    _sinceLossSample += seconds;
    // The epsilon absorbs float drift (ten 0.1 s ticks add up to 0.999…).
    if (_sinceLossSample >= 1 - 1e-6) {
      _sinceLossSample = _sinceLossSample >= 2
          ? 0
          : (_sinceLossSample - 1).clamp(0.0, 1.0);
      _loss.add(engine.loss(state.state));
    }
    _sinceSave += seconds;
    if (_sinceSave >= autosaveInterval) unawaited(_autosave());
  }

  /// Credits time the game wasn't running: a hidden browser tab, an app in
  /// the background or a sleeping device. If another tab saved meanwhile,
  /// its newer game is adopted instead, so time is never credited twice.
  Future<void> resumeAfter(Duration away) async {
    if (await _adoptNewerSave()) return;
    final before = state.state;
    state = _afterAbsence(state.state, away, state.offline);
    _trackStages(before, state.state);
    _loss.add(engine.loss(state.state));
    _write();
  }

  /// One manual training step.
  void train() => _update(engine.train(state.state));

  bool buyGenerator(String generatorId, {int quantity = 1}) =>
      _apply(engine.buyGenerator(state.state, generatorId, quantity: quantity));

  /// Buys as many units of a generator as the tokens allow (false if not
  /// even one).
  bool buyMax(String generatorId) {
    final count = engine.maxAffordable(state.state, generatorId);
    return count > 0 && buyGenerator(generatorId, quantity: count);
  }

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
    _loss.startRun();
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
    _loss.startRun();
    save();
    return true;
  }

  void dismissOffline() {
    if (state.offline != null) state = GameSession(state: state.state);
  }

  /// Writes the save right away (used when the app is being hidden, which
  /// may be the last chance to write).
  void save() {
    _sinceSave = 0;
    _write();
  }

  /// Autosave: first checks whether another tab or window saved a newer
  /// game; if so that game wins (with the time since its save credited)
  /// instead of being overwritten.
  Future<void> _autosave() async {
    _sinceSave = 0;
    if (await _adoptNewerSave()) return;
    _write();
  }

  /// Adopts the stored game if someone else wrote it after our last write
  /// (or at all, if there was no save when this game started).
  Future<bool> _adoptNewerSave() async {
    try {
      await _preferences.reload();
    } on Object {
      return false;
    }
    if (!ref.mounted) return false;
    final stored = _readSave(), last = _lastWrite;
    if (stored == null) return false;
    if (last != null && !stored.savedAt.isAfter(last)) return false;
    final before = state.state;
    state = _afterAbsence(
      stored.state,
      _now().difference(stored.savedAt),
      state.offline,
    );
    _trackStages(before, state.state);
    _write();
    return true;
  }

  void _write() {
    final now = _now();
    _lastWrite = now;
    unawaited(
      _preferences.setString(saveKey, _codec.encode(state.state, savedAt: now)),
    );
    unawaited(_preferences.setString(lossKey, jsonEncode(_loss.toJson())));
  }

  bool _apply(GameState? next) {
    if (next == null) return false;
    _update(next);
    return true;
  }

  void _update(GameState next) {
    final before = state.state;
    state = GameSession(state: next, offline: state.offline);
    _trackStages(before, next);
  }

  /// Marks evolutions on the loss chart; a new run (published paper)
  /// starts a new chart.
  void _trackStages(GameState before, GameState after) {
    final from = engine.stageIndex(before), to = engine.stageIndex(after);
    if (after.papersPublished > before.papersPublished) {
      _loss.startRun();
    } else {
      // Every stage crossed, also several at once after time away.
      for (var stage = from + 1; stage <= to; stage++) {
        _loss.mark(engine.content.architectures[stage].name.en);
      }
    }
  }
}

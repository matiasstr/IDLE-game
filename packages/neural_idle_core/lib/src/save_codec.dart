import 'dart:convert';

import 'content/game_content.dart';
import 'game_state.dart';

/// A decoded save: the game plus when it was written, which is what offline
/// progress is measured from.
class SaveData {
  const SaveData({required this.state, required this.savedAt});

  final GameState state;
  final DateTime savedAt;
}

/// Converts a [GameState] to a versioned JSON string and back.
///
/// Decoding is defensive: hardware or research that no longer exists is
/// dropped and invalid numbers are reset, so a stale or hand-edited save can
/// never crash the game.
class SaveCodec {
  const SaveCodec([this.content = GameContent.standard]);

  /// Bump when the format changes and migrate older versions in [decode].
  static const version = 1;

  final GameContent content;

  String encode(GameState state, {required DateTime savedAt}) => jsonEncode({
        'version': version,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'tokens': _finite(state.tokens),
        'runTokens': _finite(state.runTokens),
        'lifetimeTokens': _finite(state.lifetimeTokens),
        'citations': state.citations,
        'generators': {
          for (final entry in state.generators.entries)
            if (entry.value > 0) entry.key: entry.value,
        },
        'upgrades': state.upgrades.toList()..sort(),
        'manualTrainings': state.manualTrainings,
        'papersPublished': state.papersPublished,
        'playSeconds': _finite(state.playSeconds),
      });

  /// Returns null when [raw] is not a Neural Idle save.
  SaveData? decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?> || json['version'] is! int) return null;

    final savedAtRaw = json['savedAt'];
    final savedAt = savedAtRaw is String ? DateTime.tryParse(savedAtRaw) : null;
    if (savedAt == null) return null;

    final generatorsRaw = json['generators'];
    final generators = <String, int>{
      if (generatorsRaw is Map<String, Object?>)
        for (final MapEntry(:key, :value) in generatorsRaw.entries)
          if (content.hasGenerator(key) && value is int && value > 0)
            key: value,
    };
    final upgradesRaw = json['upgrades'];
    final upgrades = <String>{
      if (upgradesRaw is List<Object?>)
        for (final id in upgradesRaw)
          if (id is String && content.hasUpgrade(id)) id,
    };

    final runTokens = _readDouble(json['runTokens']);
    return SaveData(
      savedAt: savedAt,
      state: GameState(
        tokens: _readDouble(json['tokens']),
        runTokens: runTokens,
        lifetimeTokens: _max(_readDouble(json['lifetimeTokens']), runTokens),
        citations: _readInt(json['citations']),
        generators: generators,
        upgrades: upgrades,
        manualTrainings: _readInt(json['manualTrainings']),
        papersPublished: _readInt(json['papersPublished']),
        playSeconds: _readDouble(json['playSeconds']),
      ),
    );
  }
}

double _readDouble(Object? value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : 0;

int _readInt(Object? value) => value is int && value >= 0 ? value : 0;

double _max(double a, double b) => a > b ? a : b;

/// JSON can't encode NaN or infinity.
double _finite(double value) {
  if (value.isNaN) return 0;
  return value.clamp(-double.maxFinite, double.maxFinite);
}

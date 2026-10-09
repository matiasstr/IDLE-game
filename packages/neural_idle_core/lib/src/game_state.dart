/// Everything saved for one player.
///
/// Immutable: the engine returns new instances instead of mutating, which
/// makes every rule a pure function and plays well with any state-management
/// layer. Treat [generators] and [upgrades] as read-only.
class GameState {
  const GameState({
    this.tokens = 0,
    this.runTokens = 0,
    this.lifetimeTokens = 0,
    this.citations = 0,
    this.generators = const {},
    this.upgrades = const {},
    this.manualTrainings = 0,
    this.papersPublished = 0,
    this.playSeconds = 0,
  });

  /// A brand-new game.
  static const initial = GameState();

  /// Spendable tokens.
  final double tokens;

  /// Tokens earned since the last published paper. Drives the architecture
  /// stage and the model's accuracy.
  final double runTokens;

  /// Tokens earned across every run.
  final double lifetimeTokens;

  /// Prestige currency earned by publishing papers.
  final int citations;

  /// Units owned per generator id.
  final Map<String, int> generators;

  /// Ids of the research upgrades bought in this run.
  final Set<String> upgrades;

  final int manualTrainings;
  final int papersPublished;

  /// Time the game has been running in the foreground, in seconds.
  final double playSeconds;

  int owned(String generatorId) => generators[generatorId] ?? 0;

  bool hasUpgrade(String upgradeId) => upgrades.contains(upgradeId);

  GameState copyWith({
    double? tokens,
    double? runTokens,
    double? lifetimeTokens,
    int? citations,
    Map<String, int>? generators,
    Set<String>? upgrades,
    int? manualTrainings,
    int? papersPublished,
    double? playSeconds,
  }) {
    return GameState(
      tokens: tokens ?? this.tokens,
      runTokens: runTokens ?? this.runTokens,
      lifetimeTokens: lifetimeTokens ?? this.lifetimeTokens,
      citations: citations ?? this.citations,
      generators: generators ?? this.generators,
      upgrades: upgrades ?? this.upgrades,
      manualTrainings: manualTrainings ?? this.manualTrainings,
      papersPublished: papersPublished ?? this.papersPublished,
      playSeconds: playSeconds ?? this.playSeconds,
    );
  }

  /// Returns a copy with [amount] tokens earned.
  GameState earn(double amount) => copyWith(
        tokens: tokens + amount,
        runTokens: runTokens + amount,
        lifetimeTokens: lifetimeTokens + amount,
      );

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.tokens == tokens &&
      other.runTokens == runTokens &&
      other.lifetimeTokens == lifetimeTokens &&
      other.citations == citations &&
      _sameCounts(other.generators, generators) &&
      other.upgrades.length == upgrades.length &&
      other.upgrades.containsAll(upgrades) &&
      other.manualTrainings == manualTrainings &&
      other.papersPublished == papersPublished &&
      other.playSeconds == playSeconds;

  @override
  int get hashCode => Object.hash(
        tokens,
        runTokens,
        lifetimeTokens,
        citations,
        Object.hashAllUnordered(
          generators.entries
              .where((e) => e.value != 0)
              .map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(upgrades),
        manualTrainings,
        papersPublished,
        playSeconds,
      );

  @override
  String toString() => 'GameState(tokens: $tokens, runTokens: $runTokens, '
      'lifetimeTokens: $lifetimeTokens, citations: $citations, '
      'generators: $generators, upgrades: $upgrades)';
}

/// Map equality where a missing key and a count of 0 mean the same thing.
bool _sameCounts(Map<String, int> a, Map<String, int> b) {
  for (final key in {...a.keys, ...b.keys}) {
    if ((a[key] ?? 0) != (b[key] ?? 0)) return false;
  }
  return true;
}

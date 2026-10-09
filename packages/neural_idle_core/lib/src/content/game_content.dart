import 'architectures.dart';
import 'generators.dart';
import 'upgrades.dart';

/// All the data and balance knobs the engine runs on.
///
/// The engine never reads the global `k*` lists directly, so tests can run
/// the rules against small, hand-made content.
class GameContent {
  const GameContent({
    required this.generators,
    required this.upgrades,
    required this.architectures,
    this.baseTapValue = 1,
    this.citationBonus = 0.02,
    this.citationScale = 10,
    this.publishStage = 4,
    this.offlineCap = const Duration(hours: 8),
  });

  static const standard = GameContent(
    generators: kGenerators,
    upgrades: kUpgrades,
    architectures: kArchitectures,
  );

  /// Hardware in shop order.
  final List<GeneratorDef> generators;
  final List<UpgradeDef> upgrades;

  /// Stages ordered by threshold; the first one must start at 0.
  final List<ArchitectureDef> architectures;

  /// Tokens earned by one manual training step before upgrades.
  final double baseTapValue;

  /// Production bonus per citation (0.02 = +2%).
  final double citationBonus;

  /// Citations earned for publishing right at [publishStage]; grows with the
  /// cube root of the tokens earned in the run, so longer runs pay off
  /// without making the next run trivial.
  final double citationScale;

  /// First stage at which a paper can be published (prestige).
  final int publishStage;

  /// Longest absence credited as offline progress.
  final Duration offlineCap;

  GeneratorDef generator(String id) => generators.firstWhere(
        (g) => g.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'Unknown generator'),
      );

  UpgradeDef upgrade(String id) => upgrades.firstWhere(
        (u) => u.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'Unknown upgrade'),
      );

  bool hasGenerator(String id) => generators.any((g) => g.id == id);

  bool hasUpgrade(String id) => upgrades.any((u) => u.id == id);
}

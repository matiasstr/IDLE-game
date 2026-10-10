import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/state/game_controller.dart';
import 'package:neural_idle/state/game_loop.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/game_icons.dart';
import 'package:neural_idle/ui/game_text.dart';
import 'package:neural_idle/ui/layout/narrow_layout.dart';
import 'package:neural_idle/ui/layout/wide_layout.dart';
import 'package:neural_idle/ui/widgets/ai_speech_bubble.dart';
import 'package:neural_idle/ui/widgets/generator_card.dart';
import 'package:neural_idle/ui/widgets/language_toggle.dart';
import 'package:neural_idle/ui/widgets/model_status_panel.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:neural_idle/ui/widgets/resource_tile.dart';
import 'package:neural_idle/ui/widgets/settings_sheet.dart';
import 'package:neural_idle/ui/widgets/store_tabs.dart';
import 'package:neural_idle/ui/widgets/train_button.dart';
import 'package:neural_idle/ui/widgets/upgrade_card.dart';
import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_viz/neural_viz.dart';

/// The game screen: maps the engine state to the presentational widgets.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _offlineVisible = false;

  /// The network view's captions use the app's mono font.
  static final _vizTheme = NeuralVizTheme(
    monoFontFamily: AppTextStyles.number().fontFamily ?? 'JetBrains Mono',
  );

  /// Keep the network and loss chart alive when the layout switches between
  /// its scrolling and non-scrolling forms (short windows, the soft
  /// keyboard): a remount would replay the intro and drop a running
  /// evolution.
  final _networkKey = GlobalKey(debugLabel: 'network');
  final _lossChartKey = GlobalKey(debugLabel: 'loss-chart');

  GameController get _controller => ref.read(gameControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOffline());
  }

  /// Tells the player what their AI did while they were away (once).
  Future<void> _showOffline() async {
    final offline = ref.read(gameControllerProvider).offline;
    if (offline == null || _offlineVisible || !mounted) return;
    _offlineVisible = true;
    final text = GameText.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => OfflineProgressDialog(
        duration: text.duration(offline.credited),
        tokensGained: text.amount(offline.tokensEarned),
      ),
    );
    _offlineVisible = false;
    if (!mounted) return;
    // A newer report (another absence) may have arrived while the dialog
    // was open: show that one instead of dismissing it unseen.
    if (identical(ref.read(gameControllerProvider).offline, offline)) {
      _controller.dismissOffline();
    } else {
      unawaited(_showOffline());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider.select((s) => s.offline), (_, next) {
      if (next != null) _showOffline();
    });
    final game = ref.watch(gameControllerProvider).state;
    final engine = ref.watch(gameEngineProvider);
    final lossHistory = ref.watch(lossHistoryProvider);
    final l10n = AppLocalizations.of(context);
    final text = GameText.of(context);

    final architecture = engine.architecture(game);
    final next = engine.nextArchitecture(game);
    final stage = engine.stageIndex(game);
    final production = engine.productionPerSecond(game);
    final accuracy = engine.accuracy(game);

    final hardware = _hardwareList(engine, game, text);
    final research = _researchList(engine, game, text);

    Widget resources() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.resourceOverview.toUpperCase(), style: AppTextStyles.eyebrow),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.token_outlined,
          label: l10n.tokens,
          value: text.amount(game.tokens),
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.bolt_rounded,
          label: l10n.tokensPerSecond,
          value: text.rate(production),
        ),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.track_changes_rounded,
          label: l10n.accuracy,
          value: text.percent(accuracy),
          accent: AppColors.neonViolet,
        ),
        const SizedBox(height: 24),
        ModelStatusPanel(
          architecture: text.of(architecture.name),
          stage: stage + 1,
          totalStages: engine.content.architectures.length,
          accuracy: accuracy,
          accuracyLabel: text.percent(accuracy),
          loss: text.loss(engine.loss(game)),
          nextArchitecture: next == null ? null : text.of(next.name),
          progressToNext: engine.stageProgress(game),
        ),
        const SizedBox(height: 12),
        NeonPanel(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SizedBox(
            height: 96,
            child: LossChart(
              key: _lossChartKey,
              history: lossHistory,
              theme: _vizTheme,
              decimalSeparator: text.decimalSeparator,
              valueLabel: l10n.loss.toLowerCase(),
              semanticLabel: l10n.loss,
            ),
          ),
        ),
      ],
    );

    final visualization = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: NeuralNetworkView(
        key: _networkKey,
        topology: NetworkTopology.fromId(architecture.id, architecture.layers),
        nextTopology: next == null
            ? null
            : NetworkTopology.fromId(next.id, next.layers),
        stage: stage,
        productionPerSecond: production,
        trainingCount: game.manualTrainings,
        progress: engine.stageProgress(game),
        accuracy: accuracy,
        onTrain: _controller.train,
        theme: _vizTheme,
        semanticLabel: '${l10n.architecture}: ${text.of(architecture.name)}',
      ),
    );

    // The AI says something new every few seconds of play.
    final speech = AiSpeechBubble(
      text: text.of(engine.phrase(game, (game.playSeconds / 9).floor())),
    );

    Widget trainButton() => TrainButton(
      label: l10n.train,
      gainLabel: text.gain(engine.tapValue(game)),
      onTap: _controller.train,
    );

    return GameLoop(
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppSpacing.wideBreakpoint;
              final topBar = _TopBar(
                wide: wide,
                onDebugAway: () => unawaited(
                  _controller.resumeAfter(const Duration(hours: 2)),
                ),
              );
              if (wide) {
                return WideLayout(
                  topBar: topBar,
                  resources: resources(),
                  training: LayoutBuilder(
                    builder: (context, trainingConstraints) {
                      final content = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: visualization),
                          const SizedBox(height: 16),
                          speech,
                          trainButton(),
                          const SizedBox(height: 12),
                          Text(
                            l10n.trainingHint,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      );
                      return trainingConstraints.maxHeight < 440
                          ? SingleChildScrollView(
                              child: SizedBox(height: 520, child: content),
                            )
                          : content;
                    },
                  ),
                  store: StoreTabs(hardware: hardware, research: research),
                );
              }
              return NarrowLayout(
                topBar: topBar,
                resources: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompactMetric(
                          label: l10n.tokens,
                          value: text.amount(game.tokens),
                          color: AppColors.neonCyan,
                        ),
                      ),
                      Expanded(
                        child: _CompactMetric(
                          label: l10n.tokensPerSecond,
                          value: text.rate(production),
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: _CompactMetric(
                          label: l10n.accuracy,
                          value: text.percent(accuracy),
                          color: AppColors.neonViolet,
                        ),
                      ),
                    ],
                  ),
                ),
                visualization: visualization,
                speech: speech,
                trainButton: trainButton(),
                store: StoreTabs(
                  hardware: hardware,
                  research: research,
                  stats: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: resources(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Unlocked hardware, plus a mystery card for the next tier.
  Widget _hardwareList(GameEngine engine, GameState game, GameText text) {
    final generators = [
      for (final generator in engine.content.generators)
        if (engine.generatorVisibility(game, generator.id) !=
            GeneratorVisibility.hidden)
          generator,
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      itemCount: generators.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final generator = generators[index];
        final locked =
            engine.generatorVisibility(game, generator.id) ==
            GeneratorVisibility.teased;
        final cost = engine.generatorCost(game, generator.id);
        return GeneratorCard(
          key: ValueKey('hardware-${generator.id}'),
          icon: generatorIcon(generator.id),
          name: text.of(generator.name),
          description: text.of(generator.description),
          owned: game.owned(generator.id),
          cost: text.amount(cost),
          production: text.rate(engine.unitProduction(game, generator.id)),
          canAfford: !locked && game.tokens >= cost,
          locked: locked,
          onBuy: locked ? null : () => _controller.buyGenerator(generator.id),
        );
      },
    );
  }

  /// Research available now (cheapest first), then what's already bought.
  Widget _researchList(GameEngine engine, GameState game, GameText text) {
    final available = engine.availableUpgrades(game);
    final purchased = [
      for (final upgrade in engine.content.upgrades)
        if (game.hasUpgrade(upgrade.id)) upgrade,
    ];
    final upgrades = [...available, ...purchased];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      itemCount: upgrades.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final upgrade = upgrades[index];
        final bought = game.hasUpgrade(upgrade.id);
        return UpgradeCard(
          key: ValueKey('research-${upgrade.id}'),
          name: text.of(upgrade.name),
          description: text.of(upgrade.description),
          effect: text.of(engine.effectLabel(upgrade)),
          cost: text.amount(upgrade.cost),
          canAfford: !bought && game.tokens >= upgrade.cost,
          purchased: bought,
          onBuy: bought ? null : () => _controller.buyUpgrade(upgrade.id),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide, required this.onDebugAway});

  final bool wide;
  final VoidCallback onDebugAway;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: AppColors.neonCyan, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (wide) Text(l10n.trainingLab, style: AppTextStyles.eyebrow),
              ],
            ),
          ),
          if (wide) ...[const LanguageToggle(), const SizedBox(width: 12)],
          if (kDebugMode)
            IconButton(
              key: const ValueKey('debug-offline'),
              tooltip: l10n.debugOffline,
              onPressed: onDebugAway,
              icon: const Icon(
                Icons.bug_report_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          IconButton(
            key: const ValueKey('settings-button'),
            tooltip: l10n.settings,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const SettingsSheet(),
            ),
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 4),
      Text(value, style: AppTextStyles.number(size: 18, color: color)),
    ],
  );
}

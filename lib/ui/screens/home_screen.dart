import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/app_info.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/state/game_controller.dart';
import 'package:neural_idle/state/game_loop.dart';
import 'package:neural_idle/state/onboarding.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/game_icons.dart';
import 'package:neural_idle/ui/game_text.dart';
import 'package:neural_idle/ui/layout/narrow_layout.dart';
import 'package:neural_idle/ui/layout/wide_layout.dart';
import 'package:neural_idle/ui/widgets/ai_speech_bubble.dart';
import 'package:neural_idle/ui/widgets/buy_amount_selector.dart';
import 'package:neural_idle/ui/widgets/coach_mark.dart';
import 'package:neural_idle/ui/widgets/evolution_banner.dart';
import 'package:neural_idle/ui/widgets/generator_card.dart';
import 'package:neural_idle/ui/widgets/language_toggle.dart';
import 'package:neural_idle/ui/widgets/model_status_panel.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:neural_idle/ui/widgets/publish_paper_card.dart';
import 'package:neural_idle/ui/widgets/resource_tile.dart';
import 'package:neural_idle/ui/widgets/settings_sheet.dart';
import 'package:neural_idle/ui/widgets/stats_panel.dart';
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

  /// What first-run hints point at.
  final _trainKey = GlobalKey(debugLabel: 'train');
  final _firstHardwareKey = GlobalKey(debugLabel: 'first-hardware');
  final _researchTabKey = GlobalKey(debugLabel: 'research-tab');

  BuyAmount _buyAmount = BuyAmount.one;

  VoidCallback? _closeBanner;

  // The first-run hint on screen, where its target was, and where the
  // target was last seen (a hint moves only once its target stops moving).
  VoidCallback? _closeCoach;
  OnboardingStep? _coachStep;
  Rect? _coachTarget;
  String? _coachText;
  Rect? _lastSeenTarget;

  /// Frame time since which nothing (dialog, sheet, offline report) covers
  /// the screen: hints wait for a closing one to finish its exit animation.
  Duration? _uncoveredSince;
  bool _hidingCoach = false;
  bool _coachSyncScheduled = false;

  GameController get _controller => ref.read(gameControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOffline());
  }

  @override
  void dispose() {
    _closeBanner?.call();
    _hideCoach();
    super.dispose();
  }

  /// Celebrates an evolution at the peak of its animation.
  void _onTransitionPeak(VizTransition transition) {
    // Not over dialogs or sheets (an imported save, the publish dialog);
    // the offline report already tells about evolutions while away.
    if (transition.kind != VizTransitionKind.evolve ||
        !mounted ||
        _offlineVisible ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    final architectures = ref.read(gameEngineProvider).content.architectures;
    final stage = transition.toStage.clamp(0, architectures.length - 1);
    final architecture = architectures[stage];
    final text = GameText.of(context);
    _closeBanner?.call();
    _closeBanner = showEvolutionBanner(
      context,
      architecture: text.of(architecture.name),
      description: text.of(architecture.description),
      stage: stage + 1,
      totalStages: architectures.length,
    );
  }

  // ------------------------------------------------------------ onboarding

  void _scheduleCoachSync() {
    if (_coachSyncScheduled) return;
    _coachSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _coachSyncScheduled = false;
      if (mounted) _syncCoach();
    });
  }

  /// Units per tap of the first hardware's Buy button (MAX buys at least
  /// one whenever one is affordable).
  int _firstHardwareQuantity(GameEngine engine, GameState game) =>
      _buyAmount == BuyAmount.ten ? 10 : 1;

  GlobalKey _coachTargetKey(OnboardingStep step) => switch (step) {
    OnboardingStep.train => _trainKey,
    OnboardingStep.buyHardware => _firstHardwareKey,
    OnboardingStep.evolve => _networkKey,
    OnboardingStep.research => _researchTabKey,
  };

  /// Where [key]'s widget is on screen, or null if it isn't laid out there
  /// (an inactive tab, scrolled away).
  Rect? _onScreen(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    if (!rect.overlaps(screen)) return null;
    // Whole pixels, so sub-pixel layout noise doesn't count as moving.
    return Rect.fromLTRB(
      rect.left.roundToDouble(),
      rect.top.roundToDouble(),
      rect.right.roundToDouble(),
      rect.bottom.roundToDouble(),
    );
  }

  String _coachMessage(OnboardingStep step, GameEngine engine, GameState game) {
    final l10n = AppLocalizations.of(context);
    final text = GameText.of(context);
    return switch (step) {
      OnboardingStep.train => l10n.hintTrain,
      OnboardingStep.buyHardware => l10n.hintBuyHardware(
        text.of(engine.content.generators.first.name),
      ),
      OnboardingStep.evolve => switch (engine.nextArchitecture(game)) {
        final next? => l10n.hintEvolve(
          text.amount(next.threshold),
          text.of(next.name),
        ),
        null => l10n.hintTrain,
      },
      OnboardingStep.research => l10n.hintResearch,
    };
  }

  /// Shows, moves or hides the first-run hint to match the game.
  void _syncCoach() {
    final engine = ref.read(gameEngineProvider);
    final game = ref.read(gameControllerProvider).state;
    // Not over dialogs, sheets or the offline report, nor while one of
    // them is still animating away.
    final covered =
        _offlineVisible || !(ModalRoute.of(context)?.isCurrent ?? true);
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final since = covered ? null : (_uncoveredSince ??= now);
    if (covered) _uncoveredSince = null;
    final settling =
        since == null || now - since < const Duration(milliseconds: 350);
    final step = settling
        ? null
        : onboardingStep(
            engine,
            game,
            ref.read(onboardingProvider),
            buyQuantity: _firstHardwareQuantity(engine, game),
          );
    final target = step == null ? null : _onScreen(_coachTargetKey(step));
    final message = step == null ? null : _coachMessage(step, engine, game);
    final seen = _lastSeenTarget;
    _lastSeenTarget = target;
    if (step == _coachStep && target == _coachTarget && message == _coachText) {
      return;
    }
    _hideCoach();
    // Wait for a moving target (a tab sliding in, a resize) to settle.
    if (step == null || target == null || target != seen) {
      if (step != null || (!covered && settling)) _scheduleCoachSync();
      return;
    }
    _coachStep = step;
    _coachTarget = target;
    _coachText = message;
    _closeCoach = showCoachMark(
      context,
      target: _coachTargetKey(step),
      message: message!,
      // Below the train button on phones would cover the store's tabs.
      preferAbove: step == OnboardingStep.train,
      onDismiss: () {
        // Tapped away: don't show this hint again.
        if (_hidingCoach) return;
        _closeCoach = null;
        _coachStep = null;
        _coachTarget = null;
        _coachText = null;
        ref.read(onboardingProvider.notifier).dismiss(step);
      },
    );
  }

  /// Removes the hint without counting it as dismissed.
  void _hideCoach() {
    final close = _closeCoach;
    _closeCoach = null;
    _coachStep = null;
    _coachTarget = null;
    _coachText = null;
    if (close == null) return;
    _hidingCoach = true;
    try {
      close();
    } finally {
      _hidingCoach = false;
    }
  }

  // ------------------------------------------------------------- actions

  void _hideBanner() {
    _closeBanner?.call();
    _closeBanner = null;
  }

  void _openSettings() {
    _hideBanner();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SettingsSheet(
          onResetProgress: _controller.resetProgress,
          exportSave: _controller.exportSave,
          importSave: _controller.importSave,
          version: appVersion,
        ),
      ),
    );
  }

  Future<void> _publish(GameEngine engine, GameState game) async {
    final text = GameText.of(context);
    final gain = engine.citationsForPublishing(game);
    _hideBanner();
    final confirmed = await showPublishPaperDialog(
      context,
      citationsGain: text.amount(gain.toDouble()),
      bonusAfter: text.factor(_multiplierWith(engine, game, gain)),
    );
    if (confirmed && mounted) _controller.publishPaper();
  }

  /// The citation multiplier after earning [gain] more citations.
  static double _multiplierWith(GameEngine engine, GameState game, int gain) =>
      engine.prestigeMultiplier(
        game.copyWith(citations: game.citations + gain),
      );

  /// Tells the player what their AI did while they were away (once).
  Future<void> _showOffline() async {
    final offline = ref.read(gameControllerProvider).offline;
    if (offline == null || _offlineVisible || !mounted) return;
    _offlineVisible = true;
    _hideBanner();
    final text = GameText.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => OfflineProgressDialog(
        duration: text.duration(offline.credited),
        tokensGained: text.amount(offline.tokensEarned),
        evolutions: offline.stagesGained,
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
      if (next != null) unawaited(_showOffline());
    });
    ref.watch(onboardingProvider);
    _scheduleCoachSync();
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
    final affordableResearch = engine
        .availableUpgrades(game)
        .where((upgrade) => game.tokens >= upgrade.cost)
        .length;

    // Prestige and lifetime numbers, in the Stats tab.
    final gain = engine.citationsForPublishing(game);
    final progressPanels = [
      PublishPaperCard(
        citationsGain: text.amount(gain.toDouble()),
        currentCitations: text.amount(game.citations.toDouble()),
        bonusAfter: text.factor(_multiplierWith(engine, game, gain)),
        enabled: engine.canPublish(game),
        onPublish: () => unawaited(_publish(engine, game)),
        // After the first paper, the hint is about the next one.
        lockedHint: game.papersPublished > 0
            ? l10n.publishLockedNext(
                text.of(
                  engine
                      .content
                      .architectures[engine.content.publishStage]
                      .name,
                ),
              )
            : null,
      ),
      const SizedBox(height: 12),
      StatsPanel(
        entries: [
          StatEntry(
            l10n.statsLifetimeTokens,
            text.amount(game.lifetimeTokens),
            icon: Icons.token_outlined,
            accent: AppColors.neonCyan,
          ),
          StatEntry(
            l10n.statsPlayTime,
            text.duration(
              Duration(milliseconds: (game.playSeconds * 1000).round()),
            ),
            icon: Icons.schedule_rounded,
          ),
          StatEntry(
            l10n.statsManualTrainings,
            text.amount(game.manualTrainings.toDouble()),
            icon: Icons.bolt_rounded,
          ),
          StatEntry(
            l10n.statsPapers,
            text.amount(game.papersPublished.toDouble()),
            icon: Icons.article_outlined,
          ),
          StatEntry(
            l10n.statsCitations,
            text.amount(game.citations.toDouble()),
            icon: Icons.format_quote_rounded,
            accent: AppColors.neonPink,
          ),
          StatEntry(
            l10n.statsCitationBonus,
            text.factor(engine.prestigeMultiplier(game)),
            icon: Icons.trending_up_rounded,
            accent: AppColors.neonPink,
          ),
        ],
      ),
    ];

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
        onTransitionPeak: _onTransitionPeak,
        theme: _vizTheme,
        semanticLabel: l10n.networkSemanticLabel(text.of(architecture.name)),
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
      anchorKey: _trainKey,
    );

    return GameLoop(
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppSpacing.wideBreakpoint;
              final topBar = _TopBar(
                wide: wide,
                onOpenSettings: _openSettings,
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
                  store: StoreTabs(
                    hardware: hardware,
                    research: research,
                    researchBadge: affordableResearch,
                    researchTabKey: _researchTabKey,
                    stats: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                      children: progressPanels,
                    ),
                  ),
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
                  researchBadge: affordableResearch,
                  researchTabKey: _researchTabKey,
                  stats: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      resources(),
                      const SizedBox(height: 12),
                      ...progressPanels,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The buy-amount selector, then unlocked hardware plus a mystery card
  /// for the next tier. The selector scrolls with the list: pinned above
  /// it, it would leave short phone screens almost no list.
  Widget _hardwareList(GameEngine engine, GameState game, GameText text) {
    final generators = [
      for (final generator in engine.content.generators)
        if (engine.generatorVisibility(game, generator.id) !=
            GeneratorVisibility.hidden)
          generator,
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: generators.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, item) {
        if (item == 0) {
          return Center(
            child: BuyAmountSelector(
              value: _buyAmount,
              onChanged: (amount) => setState(() => _buyAmount = amount),
            ),
          );
        }
        final index = item - 1;
        final generator = generators[index];
        final locked =
            engine.generatorVisibility(game, generator.id) ==
            GeneratorVisibility.teased;
        // MAX shows what the tokens buy now (at least one, to show a price).
        final quantity = switch (_buyAmount) {
          BuyAmount.one => 1,
          BuyAmount.ten => 10,
          BuyAmount.max => math.max(
            1,
            engine.maxAffordable(game, generator.id),
          ),
        };
        final cost = engine.generatorCost(
          game,
          generator.id,
          quantity: quantity,
        );
        final card = GeneratorCard(
          key: ValueKey('hardware-${generator.id}'),
          icon: generatorIcon(generator.id),
          name: text.of(generator.name),
          description: text.of(generator.description),
          owned: game.owned(generator.id),
          cost: text.amount(cost),
          production: text.rate(engine.unitProduction(game, generator.id)),
          canAfford: !locked && game.tokens >= cost,
          locked: locked,
          quantityLabel: _buyAmount == BuyAmount.one
              ? null
              : '×${text.amount(quantity.toDouble())}',
          onBuy: locked
              ? null
              : switch (_buyAmount) {
                  BuyAmount.one => () => _controller.buyGenerator(generator.id),
                  BuyAmount.ten => () => _controller.buyGenerator(
                    generator.id,
                    quantity: 10,
                  ),
                  BuyAmount.max => () => _controller.buyMax(generator.id),
                },
        );
        return index == 0
            ? KeyedSubtree(key: _firstHardwareKey, child: card)
            : card;
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
  const _TopBar({
    required this.wide,
    required this.onOpenSettings,
    required this.onDebugAway,
  });

  final bool wide;
  final VoidCallback onOpenSettings;
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
            onPressed: onOpenSettings,
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

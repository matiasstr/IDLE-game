import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/layout/narrow_layout.dart';
import 'package:neural_idle/ui/layout/wide_layout.dart';
import 'package:neural_idle/ui/mock/mock_game_data.dart';
import 'package:neural_idle/ui/widgets/ai_speech_bubble.dart';
import 'package:neural_idle/ui/widgets/generator_card.dart';
import 'package:neural_idle/ui/widgets/language_toggle.dart';
import 'package:neural_idle/ui/widgets/model_status_panel.dart';
import 'package:neural_idle/ui/widgets/neural_viz_placeholder.dart';
import 'package:neural_idle/ui/widgets/offline_progress_dialog.dart';
import 'package:neural_idle/ui/widgets/resource_tile.dart';
import 'package:neural_idle/ui/widgets/settings_sheet.dart';
import 'package:neural_idle/ui/widgets/store_tabs.dart';
import 'package:neural_idle/ui/widgets/train_button.dart';
import 'package:neural_idle/ui/widgets/upgrade_card.dart';

/// The sole mock-data reader and future integration point for game providers.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spanish = Localizations.localeOf(context).languageCode == 'es';
    final hardware = ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      itemCount: MockGameData.hardware.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = MockGameData.hardware[index];
        return GeneratorCard(
          key: ValueKey('hardware-$index'),
          icon: item.icon,
          name: item.name,
          description: spanish ? item.descriptionEs : item.descriptionEn,
          owned: item.owned,
          cost: item.cost,
          production: item.production,
          canAfford: item.canAfford,
          locked: item.locked,
          onBuy: () {},
        );
      },
    );
    final research = ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      itemCount: MockGameData.research.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = MockGameData.research[index];
        return UpgradeCard(
          name: item.name,
          description: spanish ? item.descriptionEs : item.descriptionEn,
          effect: item.effect,
          cost: item.cost,
          canAfford: item.canAfford,
          purchased: item.purchased,
          onBuy: () {},
        );
      },
    );
    Widget resources() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.resourceOverview.toUpperCase(), style: AppTextStyles.eyebrow),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.token_outlined,
          label: l10n.tokens,
          value: MockGameData.tokens,
          accent: AppColors.neonCyan,
        ),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.bolt_rounded,
          label: l10n.tokensPerSecond,
          value: MockGameData.production,
        ),
        const SizedBox(height: 12),
        ResourceTile(
          icon: Icons.track_changes_rounded,
          label: l10n.accuracy,
          value: MockGameData.accuracyLabel,
          accent: AppColors.neonViolet,
        ),
        const SizedBox(height: 24),
        const ModelStatusPanel(
          architecture: MockGameData.architecture,
          stage: MockGameData.stage,
          totalStages: MockGameData.totalStages,
          accuracy: MockGameData.accuracy,
          loss: MockGameData.loss,
          nextArchitecture: MockGameData.nextArchitecture,
          progressToNext: MockGameData.progressToNext,
        ),
      ],
    );
    Widget trainButton() => TrainButton(
      label: l10n.train,
      gainLabel: MockGameData.trainingGain,
      onTap: () {},
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppSpacing.wideBreakpoint;
            final topBar = SizedBox(
              height: 56,
              child: Row(
                children: [
                  const Icon(
                    Icons.hub_outlined,
                    color: AppColors.neonCyan,
                    size: 24,
                  ),
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
                        if (wide)
                          Text(l10n.trainingLab, style: AppTextStyles.eyebrow),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    const LanguageToggle(),
                    const SizedBox(width: 12),
                  ],
                  if (kDebugMode)
                    IconButton(
                      key: const ValueKey('debug-offline'),
                      tooltip: l10n.debugOffline,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const OfflineProgressDialog(
                          duration: MockGameData.offlineDuration,
                          tokensGained: MockGameData.offlineTokens,
                        ),
                      ),
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
            if (wide) {
              return WideLayout(
                topBar: topBar,
                resources: resources(),
                training: LayoutBuilder(
                  builder: (context, trainingConstraints) {
                    final content = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(child: NeuralVizPlaceholder()),
                        const SizedBox(height: 16),
                        const AiSpeechBubble(text: MockGameData.speech),
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
                        value: MockGameData.tokens,
                        color: AppColors.neonCyan,
                      ),
                    ),
                    Expanded(
                      child: _CompactMetric(
                        label: l10n.tokensPerSecond,
                        value: MockGameData.production,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: _CompactMetric(
                        label: l10n.accuracy,
                        value: MockGameData.accuracyLabel,
                        color: AppColors.neonViolet,
                      ),
                    ),
                  ],
                ),
              ),
              visualization: const NeuralVizPlaceholder(),
              speech: const AiSpeechBubble(text: MockGameData.speech),
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

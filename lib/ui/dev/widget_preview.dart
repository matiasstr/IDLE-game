import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/ui/widgets/buy_amount_selector.dart';
import 'package:neural_idle/ui/widgets/coach_mark.dart';
import 'package:neural_idle/ui/widgets/evolution_banner.dart';
import 'package:neural_idle/ui/widgets/generator_card.dart';
import 'package:neural_idle/ui/widgets/publish_paper_card.dart';
import 'package:neural_idle/ui/widgets/settings_sheet.dart';
import 'package:neural_idle/ui/widgets/stats_panel.dart';
import 'package:neural_idle/ui/widgets/store_tabs.dart';

class WidgetPreview extends StatefulWidget {
  const WidgetPreview({super.key});

  @override
  State<WidgetPreview> createState() => _WidgetPreviewState();
}

class _WidgetPreviewState extends State<WidgetPreview> {
  BuyAmount _buyAmount = BuyAmount.one;
  final _coachTarget = GlobalKey();
  VoidCallback? _closeCoach;

  @override
  void dispose() {
    _closeCoach?.call();
    super.dispose();
  }

  /// The hint doesn't follow a scrolling target, and must not sit on top
  /// of the sheets and dialogs this page opens.
  void _hideHint() {
    _closeCoach?.call();
    _closeCoach = null;
  }

  void _showTrainingHint() {
    _closeCoach?.call();
    _closeCoach = showCoachMark(
      context,
      target: _coachTarget,
      message: AppLocalizations.of(context).hintTrain,
      onDismiss: () => _closeCoach = null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stats = StatsPanel(
      entries: [
        StatEntry(
          l10n.statsLifetimeTokens,
          '2.48M',
          icon: Icons.token_outlined,
          accent: AppColors.neonCyan,
        ),
        StatEntry(l10n.statsPlayTime, '3h 42m'),
        StatEntry(l10n.statsManualTrainings, '1.2K'),
        StatEntry(l10n.statsPapers, '3'),
        StatEntry(l10n.statsCitations, '128', accent: AppColors.neonPink),
        StatEntry(l10n.statsCitationBonus, '×1.64'),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.previewTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              _hideHint();
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.previewDescription),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: _coachTarget,
                  onPressed: _showTrainingHint,
                  icon: const Icon(Icons.touch_app_outlined),
                  label: Text(l10n.train),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BuyAmountSelector(
                    value: _buyAmount,
                    onChanged: (value) => setState(() => _buyAmount = value),
                  ),
                ),
                const SizedBox(height: 16),
                GeneratorCard(
                  icon: Icons.memory_rounded,
                  name: 'Gaming GPU',
                  description: '+4/s',
                  owned: 6,
                  cost: '254',
                  production: '+4/s',
                  quantityLabel: switch (_buyAmount) {
                    BuyAmount.one => '×1',
                    BuyAmount.ten => '×10',
                    BuyAmount.max => 'MAX',
                  },
                  canAfford: true,
                  onBuy: () {},
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: StoreTabs(
                    hardware: const Center(child: Text('Gaming GPU · 254')),
                    research: const Center(child: Text('Mini-batches · 2.5K')),
                    stats: SingleChildScrollView(child: stats),
                    researchBadge: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const EvolutionBanner(
                  architecture: 'CNN',
                  description: 'Convolutional Neural Network',
                  stage: 3,
                  totalStages: 8,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => showEvolutionBanner(
                    context,
                    architecture: 'CNN',
                    description: 'Convolutional Neural Network',
                    stage: 3,
                    totalStages: 8,
                  ),
                  child: Text(l10n.previewEvolution),
                ),
                const SizedBox(height: 24),
                stats,
                const SizedBox(height: 24),
                PublishPaperCard(
                  citationsGain: '42',
                  currentCitations: '128',
                  bonusAfter: '×1.85',
                  enabled: true,
                  onPublish: () {
                    _hideHint();
                    showPublishPaperDialog(
                      context,
                      citationsGain: '42',
                      bonusAfter: '×1.85',
                    );
                  },
                ),
                const SizedBox(height: 16),
                const PublishPaperCard(
                  citationsGain: '0',
                  currentCitations: '0',
                  bonusAfter: '×1.00',
                  enabled: false,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(l10n.settings),
                  onPressed: () {
                    _hideHint();
                    showSettingsSheet(
                      context,
                      onResetProgress: () {},
                      exportSave: () => '{"demo":true}',
                      importSave: (raw) => raw.trim() == '{"demo":true}',
                      version: '0.1.0-preview',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

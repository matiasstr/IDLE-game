import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class PublishPaperCard extends StatelessWidget {
  const PublishPaperCard({
    super.key,
    required this.citationsGain,
    required this.currentCitations,
    required this.bonusAfter,
    required this.enabled,
    this.onPublish,
    this.lockedHint,
  });

  final String citationsGain;
  final String currentCitations;
  final String bonusAfter;
  final bool enabled;
  final VoidCallback? onPublish;
  final String? lockedHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return NeonPanel(
      accent: enabled && onPublish != null ? AppColors.neonPink : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.publishPaper,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _CitationMetric(
            label: l10n.currentCitations,
            value: currentCitations,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.citationsGain(citationsGain),
            style: AppTextStyles.number(size: 20, color: AppColors.neonPink),
          ),
          const SizedBox(height: 12),
          _CitationMetric(label: l10n.bonusAfter, value: bonusAfter),
          if (!enabled) ...[
            const SizedBox(height: 12),
            Text(
              lockedHint ?? l10n.publishLocked,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enabled ? onPublish : null,
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.background,
                backgroundColor: AppColors.neonPink,
              ),
              icon: const Icon(Icons.article_outlined),
              label: Text(l10n.publishPaper, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitationMetric extends StatelessWidget {
  const _CitationMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: AppTextStyles.number(size: 14, color: AppColors.neonPink),
        ),
      ),
    ],
  );
}

Future<bool> showPublishPaperDialog(
  BuildContext context, {
  required String citationsGain,
  required String bonusAfter,
}) async {
  final l10n = AppLocalizations.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(l10n.publishPaper),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.publishPaperBody),
              const SizedBox(height: 16),
              Text(
                l10n.citationsGain(citationsGain),
                style: AppTextStyles.number(
                  size: 18,
                  color: AppColors.neonPink,
                ),
              ),
              const SizedBox(height: 12),
              Text('${l10n.bonusAfter}: $bonusAfter'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neonPink,
              ),
              child: Text(l10n.publishConfirm),
            ),
          ],
        ),
      ) ??
      false;
}

import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';

class OfflineProgressDialog extends StatelessWidget {
  const OfflineProgressDialog({
    super.key,
    required this.duration,
    required this.tokensGained,
    this.evolutions = 0,
  });
  final String duration;
  final String tokensGained;

  /// Architectures gained while away.
  final int evolutions;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.bolt_rounded, color: AppColors.neonCyan, size: 32),
      title: Text(l10n.offlineTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$tokensGained',
            style: AppTextStyles.number(size: 32, color: AppColors.neonCyan),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.offlineBody(duration, tokensGained),
            textAlign: TextAlign.center,
          ),
          if (evolutions > 0) ...[
            const SizedBox(height: 12),
            Text(
              l10n.offlineEvolved(evolutions),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.neonViolet),
            ),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.collect),
        ),
      ],
    );
  }
}

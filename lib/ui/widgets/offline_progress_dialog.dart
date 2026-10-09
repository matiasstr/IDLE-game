import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';

class OfflineProgressDialog extends StatelessWidget {
  const OfflineProgressDialog({
    super.key,
    required this.duration,
    required this.tokensGained,
  });
  final String duration;
  final String tokensGained;
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

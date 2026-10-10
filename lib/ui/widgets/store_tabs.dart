import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';

class StoreTabs extends StatelessWidget {
  const StoreTabs({
    super.key,
    required this.hardware,
    required this.research,
    this.stats,
    this.researchBadge = 0,
    this.researchTabKey,
  });
  final Widget hardware;
  final Widget research;
  final Widget? stats;
  final int researchBadge;

  /// Lets hints point at the Research tab.
  final Key? researchTabKey;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: stats == null ? 2 : 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.hardware, height: 48),
              Tab(
                key: researchTabKey,
                height: 48,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.research,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (researchBadge > 0) ...[
                      const SizedBox(width: 4),
                      Semantics(
                        label: l10n.researchAvailable(researchBadge),
                        child: ExcludeSemantics(
                          child: Badge(
                            key: const ValueKey('research-badge'),
                            backgroundColor: AppColors.neonLime,
                            textColor: AppColors.background,
                            label: Text('$researchBadge'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (stats != null) Tab(text: l10n.stats, height: 48),
            ],
          ),
          Expanded(child: TabBarView(children: [hardware, research, ?stats])),
        ],
      ),
    );
  }
}

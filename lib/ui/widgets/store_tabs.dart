import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';

class StoreTabs extends StatelessWidget {
  const StoreTabs({
    super.key,
    required this.hardware,
    required this.research,
    this.stats,
  });
  final Widget hardware;
  final Widget research;
  final Widget? stats;
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
              Tab(text: l10n.research, height: 48),
              if (stats != null) Tab(text: l10n.stats, height: 48),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [hardware, research, ?stats],
            ),
          ),
        ],
      ),
    );
  }
}

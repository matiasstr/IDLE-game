import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_spacing.dart';

class WideLayout extends StatelessWidget {
  const WideLayout({
    super.key,
    required this.topBar,
    required this.resources,
    required this.training,
    required this.store,
  });
  final Widget topBar;
  final Widget resources;
  final Widget training;
  final Widget store;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppSpacing.maximumContentWidth,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            topBar,
            const SizedBox(height: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final spacious = constraints.maxWidth >= 1160;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        key: const ValueKey('wide-resources-column'),
                        width: spacious ? 260 : 208,
                        child: SingleChildScrollView(child: resources),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        key: const ValueKey('wide-training-column'),
                        child: training,
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        key: const ValueKey('wide-store-column'),
                        width: spacious ? 340 : 280,
                        child: store,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

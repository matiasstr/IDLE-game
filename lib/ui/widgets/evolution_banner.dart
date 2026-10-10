import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_text_styles.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class EvolutionBanner extends StatelessWidget {
  const EvolutionBanner({
    super.key,
    required this.architecture,
    required this.description,
    required this.stage,
    required this.totalStages,
  });

  final String architecture;
  final String description;
  final int stage;
  final int totalStages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.94 + value * 0.06, child: child),
        ),
        child: NeonPanel(
          accent: AppColors.neonViolet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.neonViolet,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.evolvedTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              // One line, shrunk if needed: "Transformer" must not break
              // mid-word at large text sizes.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  architecture,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.number(
                    size: 24,
                    color: AppColors.neonViolet,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                l10n.stageLabel(stage, totalStages),
                style: AppTextStyles.number(size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows [EvolutionBanner] over the app for a few seconds (or until tapped).
/// Returns a callback that closes it early, e.g. when a newer one replaces it.
VoidCallback showEvolutionBanner(
  BuildContext context, {
  required String architecture,
  required String description,
  required int stage,
  required int totalStages,
}) {
  // Capture inherited themes/localizations before inserting into the overlay.
  final themes = InheritedTheme.capture(
    from: context,
    to: Overlay.of(context).context,
  );
  final locale = Localizations.localeOf(context);
  late final OverlayEntry entry;
  var removed = false;
  void close() {
    if (removed) return;
    removed = true;
    entry.remove();
    entry.dispose();
  }

  // Positioned must be the overlay entry's root: the overlay is a Stack.
  final content = Positioned.fill(
    child: Localizations.override(
      context: context,
      locale: locale,
      child: themes.wrap(
        _EvolutionOverlay(
          onClose: close,
          child: EvolutionBanner(
            architecture: architecture,
            description: description,
            stage: stage,
            totalStages: totalStages,
          ),
        ),
      ),
    ),
  );
  entry = OverlayEntry(builder: (_) => content);
  Overlay.of(context).insert(entry);
  return close;
}

class _EvolutionOverlay extends StatefulWidget {
  const _EvolutionOverlay({required this.child, required this.onClose});
  final Widget child;
  final VoidCallback onClose;

  @override
  State<_EvolutionOverlay> createState() => _EvolutionOverlayState();
}

class _EvolutionOverlayState extends State<_EvolutionOverlay> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3500), widget.onClose);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: const Alignment(0, -0.25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(child: widget.child),
            ),
          ),
        ),
      ),
    ),
  );
}

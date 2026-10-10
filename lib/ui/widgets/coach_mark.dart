import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/ui/widgets/neon_panel.dart';

class CoachMark extends StatelessWidget {
  const CoachMark({
    super.key,
    required this.message,
    required this.onDismiss,
    this.pointing = AxisDirection.down,
  });

  final String message;
  final VoidCallback onDismiss;
  final AxisDirection pointing;

  @override
  Widget build(BuildContext context) {
    final arrow = ExcludeSemantics(
      child: Icon(
        switch (pointing) {
          AxisDirection.up => Icons.arrow_drop_up_rounded,
          AxisDirection.down => Icons.arrow_drop_down_rounded,
          AxisDirection.left => Icons.arrow_left_rounded,
          AxisDirection.right => Icons.arrow_right_rounded,
        },
        size: 24,
        color: AppColors.neonViolet,
      ),
    );
    final panel = NeonPanel(
      accent: AppColors.neonViolet,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
    final vertical =
        pointing == AxisDirection.up || pointing == AxisDirection.down;
    final leading =
        pointing == AxisDirection.up || pointing == AxisDirection.left;
    return Semantics(
      liveRegion: true,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
          maxWidth: 320,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(16),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.97 + value * 0.03,
                  child: child,
                ),
              ),
              child: vertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (leading) arrow,
                        panel,
                        if (!leading) arrow,
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading) arrow,
                        Flexible(child: panel),
                        if (!leading) arrow,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anchors a hint to a laid-out target and returns a reusable close callback.
/// Missing targets are ignored; call after the target's first frame.
VoidCallback showCoachMark(
  BuildContext context, {
  required GlobalKey target,
  required String message,
  required VoidCallback onDismiss,
}) {
  final overlay = Overlay.maybeOf(context);
  final targetContext = target.currentContext;
  final targetBox = targetContext?.findRenderObject();
  final overlayBox = overlay?.context.findRenderObject();
  if (overlay == null ||
      targetBox is! RenderBox ||
      !targetBox.attached ||
      !targetBox.hasSize ||
      overlayBox is! RenderBox ||
      !overlayBox.hasSize) {
    return () {};
  }
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  final routeAnimation = ModalRoute.of(targetContext!)?.animation;
  late final OverlayEntry entry;
  late final AnimationStatusListener routeListener;
  var closed = false;

  void close({bool notify = true}) {
    if (closed) return;
    closed = true;
    routeAnimation?.removeStatusListener(routeListener);
    entry.remove();
    entry.dispose();
    if (notify) onDismiss();
  }

  // Leave as soon as the target's route starts popping: by the time its
  // animation is dismissed the route may already be disposed, which drops
  // its status listeners.
  routeListener = (status) {
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      close(notify: false);
    }
  };
  final content = Localizations.override(
    context: context,
    child: themes.wrap(
      _CoachOverlay(
        target: targetBox,
        overlay: overlayBox,
        message: message,
        onDismiss: () => close(),
        onUnmount: () {
          // Let the overlay finish unmounting before releasing its entry.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            close(notify: false);
          });
        },
      ),
    ),
  );
  // Positioned must remain the entry's root, outside inherited wrappers.
  entry = OverlayEntry(builder: (_) => Positioned.fill(child: content));
  overlay.insert(entry);
  routeAnimation?.addStatusListener(routeListener);
  return () => close();
}

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.target,
    required this.overlay,
    required this.message,
    required this.onDismiss,
    required this.onUnmount,
  });

  final RenderBox target;
  final RenderBox overlay;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onUnmount;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.onUnmount();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!widget.target.attached || !widget.target.hasSize) {
        widget.onUnmount();
        return const SizedBox.shrink();
      }
      final media = MediaQuery.of(context);
      final insets = EdgeInsets.fromLTRB(
        math.max(media.padding.left, media.viewInsets.left),
        math.max(media.padding.top, media.viewInsets.top),
        math.max(media.padding.right, media.viewInsets.right),
        math.max(media.padding.bottom, media.viewInsets.bottom),
      );
      final bounds = Rect.fromLTRB(
        insets.left + 12,
        insets.top + 12,
        constraints.maxWidth - insets.right - 12,
        constraints.maxHeight - insets.bottom - 12,
      );
      if (bounds.width < 48 || bounds.height < 48) {
        return const SizedBox.shrink();
      }
      final target = MatrixUtils.transformRect(
        widget.target.getTransformTo(widget.overlay),
        Offset.zero & widget.target.size,
      );
      final width = math.min(320.0, bounds.width);
      final painter = TextPainter(
        text: TextSpan(
          text: widget.message,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
      )..layout(maxWidth: width - 26);
      final height = math.min(
        math.max(24.0, painter.height) + 50,
        bounds.height,
      );
      painter.dispose();
      final above = target.top - bounds.top - 8;
      final below = bounds.bottom - target.bottom - 8;
      final placeAbove = below < height && above > below;
      final left = (target.center.dx - width / 2)
          .clamp(bounds.left, bounds.right - width)
          .toDouble();
      final top = (placeAbove ? target.top - height - 8 : target.bottom + 8)
          .clamp(bounds.top, bounds.bottom - height)
          .toDouble();
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: SizedBox(
              key: const ValueKey('coach-mark-overlay'),
              child: SingleChildScrollView(
                child: CoachMark(
                  message: widget.message,
                  onDismiss: widget.onDismiss,
                  pointing: placeAbove ? AxisDirection.down : AxisDirection.up,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

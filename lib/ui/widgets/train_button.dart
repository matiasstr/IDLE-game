import 'package:flutter/material.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/theme/app_spacing.dart';
import 'package:neural_idle/theme/app_text_styles.dart';

class TrainButton extends StatefulWidget {
  const TrainButton({
    super.key,
    required this.label,
    required this.gainLabel,
    required this.onTap,
    this.anchorKey,
  });
  final String label;
  final String gainLabel;
  final VoidCallback onTap;

  /// Key on the button itself (without the room above it for the floating
  /// gains), so hints can point at it.
  final GlobalKey? anchorKey;
  @override
  State<TrainButton> createState() => _TrainButtonState();
}

class _TrainButtonState extends State<TrainButton>
    with TickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final _press = AnimationController(
    vsync: this,
    duration: AppSpacing.motionDuration,
  );
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.97,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.97,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 60,
    ),
  ]).animate(_press);
  final _gains = <int>[];
  var _nextGain = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  void _train() {
    widget.onTap();
    if (!MediaQuery.disableAnimationsOf(context)) _press.forward(from: 0);
    setState(() => _gains.add(_nextGain++));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 100,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 72,
          child: KeyedSubtree(
            key: widget.anchorKey,
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(
                          alpha: 0.12 + _pulse.value * 0.08,
                        ),
                        blurRadius: 16 + _pulse.value * 8,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: FilledButton(
                  key: const ValueKey('train-button'),
                  onPressed: _train,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neonCyan,
                    foregroundColor: AppColors.background,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 24),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.background),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        widget.gainLabel,
                        style: AppTextStyles.number(
                          size: 14,
                          color: AppColors.background,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        for (final id in _gains)
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _FloatingGain(
                  key: ValueKey('training-gain-$id'),
                  text: widget.gainLabel,
                  horizontalOffset: ((id % 5) - 2) * 24.0,
                  onComplete: () {
                    if (mounted) setState(() => _gains.remove(id));
                  },
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _FloatingGain extends StatefulWidget {
  const _FloatingGain({
    super.key,
    required this.text,
    required this.horizontalOffset,
    required this.onComplete,
  });
  final String text;
  final double horizontalOffset;
  final VoidCallback onComplete;
  @override
  State<_FloatingGain> createState() => _FloatingGainState();
}

class _FloatingGainState extends State<_FloatingGain>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete();
        })
        ..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Opacity(
      opacity: 1 - Curves.easeIn.transform(_controller.value),
      child: Transform.translate(
        offset: Offset(
          widget.horizontalOffset,
          -56 * Curves.easeOutCubic.transform(_controller.value),
        ),
        child: child,
      ),
    ),
    child: Center(
      child: Text(
        widget.text,
        style: AppTextStyles.number(
          size: 18,
          color: AppColors.neonCyan,
          weight: FontWeight.w700,
        ),
      ),
    ),
  );
}

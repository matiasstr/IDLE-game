import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:neural_viz/neural_viz.dart';

import '../design.dart';
import '../stages.dart';
import '../widgets/controls.dart';
import 'playground_model.dart';
import 'scene_clock.dart';

/// The framed view with its header, status line, loss chart and readouts.
class StageArea extends StatelessWidget {
  const StageArea({
    super.key,
    required this.model,
    required this.frame,
    required this.clock,
    required this.notice,
    required this.peak,
    required this.viewKey,
    required this.onTransitionPeak,
    required this.onCopyUrl,
    this.showInsights = true,
  });

  final PlaygroundModel model;

  /// Size of the view itself (the border is drawn outside it).
  final Size frame;
  final SceneClock clock;
  final ValueListenable<String?> notice;
  final ValueListenable<VizTransition?> peak;
  final GlobalKey viewKey;
  final ValueChanged<VizTransition> onTransitionPeak;
  final VoidCallback onCopyUrl;

  /// The loss chart and readouts under the status line. The one-column
  /// layout places [PlaygroundInsights] after the controls instead.
  final bool showInsights;

  @override
  Widget build(BuildContext context) {
    final width = frame.width + 2;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(model: model, wide: width >= 520),
            const SizedBox(height: 14),
            _framedView(context),
            const SizedBox(height: 10),
            _StatusLine(
              model: model,
              frame: frame,
              clock: clock,
              notice: notice,
              onCopyUrl: onCopyUrl,
            ),
            if (showInsights) ...[
              const SizedBox(height: 28),
              PlaygroundInsights(model: model, wide: width >= 620),
            ],
          ],
        ),
      ),
    );
  }

  Widget _framedView(BuildContext context) {
    final view = NeuralNetworkView(
      topology: model.topology,
      stage: model.stage,
      nextTopology: model.nextTopology,
      productionPerSecond: model.production,
      trainingCount: model.trainingCount,
      progress: model.progress,
      accuracy: model.accuracy,
      onTrain: model.train,
      onTransitionPeak: onTransitionPeak,
      clock: clock.isFrozen ? clock.frozenClock : null,
      quality: model.quality,
      showCaptions: model.showCaptions,
      semanticLabel: 'Neural network: ${model.def.name}. Tap to train.',
    );
    return Container(
      width: frame.width + 2,
      height: frame.height + 2,
      decoration: BoxDecoration(
        color: Palette.background,
        border: Border.all(
          color: clock.isFrozen
              ? Palette.violet.withValues(alpha: 0.45)
              : Palette.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: model.reducedMotion,
            highContrast: model.highContrast,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              KeyedSubtree(key: viewKey, child: view),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: IgnorePointer(child: _PeakToast(peak: peak)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.model, required this.wide});

  final PlaygroundModel model;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final def = model.def;
    String two(int i) => '${i + 1}'.padLeft(2, '0');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAGE ${two(model.stage)} / ${two(lastStage)}',
                style: Styles.label,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(def.name, style: Styles.title),
                  if (wide) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        def.blurb,
                        style: Styles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('LAYERS', style: Styles.label),
            const SizedBox(height: 6),
            Text(
              def.shape,
              style: Styles.value.copyWith(color: Palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.model,
    required this.frame,
    required this.clock,
    required this.notice,
    required this.onCopyUrl,
  });

  final PlaygroundModel model;
  final Size frame;
  final SceneClock clock;
  final ValueListenable<String?> notice;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final muted = Styles.value.copyWith(fontSize: 11, color: Palette.textMuted);
    // `auto` resolves like the view does: high from 560 px wide.
    final quality = model.quality == VizQuality.auto
        ? 'auto → ${frame.width >= 560 ? 'high' : 'medium'}'
        : model.quality.name;
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<ClockStatus>(
            valueListenable: clock.status,
            builder: (context, status, _) => _ClockText(
              prefix:
                  '${frame.width.round()}×${frame.height.round()}'
                  '$_sep$quality$_sep',
              status: status,
              style: muted,
            ),
          ),
        ),
        if (frame.width >= 480)
          ValueListenableBuilder<String?>(
            valueListenable: notice,
            builder: (context, text, _) => text != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      text,
                      style: muted.copyWith(color: Palette.lime),
                    ),
                  )
                : ChromeButton(
                    label: 'Capture URL',
                    icon: Icons.link_rounded,
                    tone: ButtonTone.quiet,
                    keyHint: 'S',
                    tooltip: 'Copy a capture-mode URL for this still',
                    onPressed: onCopyUrl,
                  ),
          ),
      ],
    );
  }
}

const _sep = ' · ';

/// The status line: frame, quality, then scene time and clock mode.
class _ClockText extends StatelessWidget {
  const _ClockText({
    required this.prefix,
    required this.status,
    required this.style,
  });

  final String prefix;
  final ClockStatus status;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = status.mode == ClockMode.frozen
        ? status.seconds.toStringAsFixed(3)
        : status.seconds.toStringAsFixed(2);
    final (label, color) = switch (status.mode) {
      ClockMode.running => (
        status.fps > 0 ? '${status.fps.round()} fps' : '— fps',
        Palette.textMuted,
      ),
      ClockMode.frozen => ('frozen', Palette.violet),
      ClockMode.still => ('still', Palette.textSecondary),
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${prefix}t $t s$_sep'),
          TextSpan(
            text: label,
            style: TextStyle(color: color),
          ),
        ],
      ),
      style: style,
      maxLines: 2,
    );
  }
}

/// The app would show its stage card at the transition peak; the playground
/// shows a small tag instead.
class _PeakToast extends StatefulWidget {
  const _PeakToast({required this.peak});

  final ValueListenable<VizTransition?> peak;

  @override
  State<_PeakToast> createState() => _PeakToastState();
}

class _PeakToastState extends State<_PeakToast> {
  VizTransition? _last;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VizTransition?>(
      valueListenable: widget.peak,
      builder: (context, transition, _) {
        _last = transition ?? _last;
        final shown = _last;
        return AnimatedOpacity(
          opacity: transition == null ? 0 : 1,
          duration: chromeDuration(context, 240),
          child: shown == null ? const SizedBox.shrink() : _tag(shown),
        );
      },
    );
  }

  Widget _tag(VizTransition t) {
    final to = stages[t.toStage.clamp(0, lastStage)].name;
    final (kind, color) = switch (t.kind) {
      VizTransitionKind.evolve => (
        t.steps > 1 ? 'EVOLVE ×${t.steps}' : 'EVOLVE',
        Palette.violet,
      ),
      VizTransitionKind.reset => ('PUBLISHED', Palette.lime),
      VizTransitionKind.crossfade => ('CROSSFADE', Palette.textSecondary),
      VizTransitionKind.intro => ('INTRO', Palette.textSecondary),
    };
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Palette.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(kind, style: Styles.label.copyWith(color: color)),
            const SizedBox(width: 8),
            Text(to, style: Styles.value.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// Training loss and the numbers behind the view's inputs.
class PlaygroundInsights extends StatelessWidget {
  const PlaygroundInsights({
    super.key,
    required this.model,
    required this.wide,
  });

  final PlaygroundModel model;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final chart = LossChart(
      history: model.loss,
      semanticLabel: 'Training loss',
    );
    final loss = Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel(
            'Training loss',
            trailing: Text('−ln(acc) · 1/s', style: Styles.hint),
          ),
          if (wide)
            Expanded(child: chart)
          else
            SizedBox(height: 104, child: chart),
        ],
      ),
    );
    final readouts = Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(model.follow ? 'Engine' : 'Inputs'),
          _ReadoutGrid(model: model),
        ],
      ),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [loss, const SizedBox(height: 12), readouts],
      );
    }
    return SizedBox(
      height: 188,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: loss),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: readouts),
        ],
      ),
    );
  }
}

class _ReadoutGrid extends StatelessWidget {
  const _ReadoutGrid({required this.model});

  final PlaygroundModel model;

  @override
  Widget build(BuildContext context) {
    final accuracy = model.accuracy;
    final next = model.isLastStage ? null : stages[model.stage + 1];
    final cells = <Widget>[
      Readout(
        label: 'Run tokens',
        value: model.follow ? formatCount(model.runTokens) : '—',
      ),
      Readout(
        label: 'Accuracy',
        value: '${(accuracy * 100).toStringAsFixed(1)}%',
      ),
      Readout(
        label: 'Loss',
        value: lossOf(accuracy).toStringAsFixed(3),
        color: Palette.cyan,
      ),
      Readout(
        label: 'Energy',
        value: productionEnergy(model.production).toStringAsFixed(3),
      ),
      Readout(label: 'Trainings', value: '${model.trainingCount}'),
      Readout(
        label: 'Next stage at',
        value: next == null ? 'final' : formatCount(next.threshold),
        color: next == null ? Palette.textSecondary : Palette.textPrimary,
      ),
    ];
    Widget column(int first) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = first; i < cells.length; i += 2) ...[
            if (i > first) const SizedBox(height: 12),
            cells[i],
          ],
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [column(0), const SizedBox(width: 12), column(1)],
    );
  }
}

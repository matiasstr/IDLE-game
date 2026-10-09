import 'package:flutter/material.dart';
import 'package:neural_viz/neural_viz.dart';

import '../design.dart';
import '../stages.dart';
import '../widgets/controls.dart';
import 'playground_model.dart';

/// Every input of the view, grouped: stage, signals, training, display and
/// time.
class ControlsPanel extends StatelessWidget {
  const ControlsPanel({
    super.key,
    required this.model,
    required this.frozen,
    required this.onToggleFreeze,
    required this.onStep,
    required this.onCopyUrl,
    required this.onReducedMotion,
    required this.showShortcuts,
  });

  final PlaygroundModel model;
  final bool frozen;
  final VoidCallback onToggleFreeze;
  final ValueChanged<int> onStep;
  final VoidCallback onCopyUrl;
  final ValueChanged<bool> onReducedMotion;

  /// Lists the keyboard shortcuts (when the top bar has no room for them).
  final bool showShortcuts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Stage'),
        _StageStepper(model: model),
        const SizedBox(height: 28),
        const SectionLabel('Signals'),
        ..._signals(),
        const SizedBox(height: 24),
        const SectionLabel('Training'),
        ..._training(),
        const SizedBox(height: 28),
        const SectionLabel('Display'),
        ..._display(),
        const SizedBox(height: 24),
        const SectionLabel('Time'),
        ..._time(),
        if (showShortcuts) ...[
          const SizedBox(height: 28),
          const SectionLabel('Keyboard'),
          const Wrap(spacing: 16, runSpacing: 10, children: _shortcuts),
        ],
      ],
    );
  }

  List<Widget> _signals() {
    final production = model.production;
    final accuracy = model.accuracy;
    final next = model.isLastStage ? null : stages[model.stage + 1];
    return [
      LabeledSlider(
        label: 'Production',
        valueText: '${formatCount(production)} tok/s',
        detail: 'E ${productionEnergy(production).toStringAsFixed(2)}',
        value: positionOf(production),
        onChanged: (p) => model.setProduction(roundProduction(productionAt(p))),
      ),
      const SizedBox(height: 6),
      LabeledSlider(
        label: 'Accuracy',
        valueText: '${(accuracy * 100).toStringAsFixed(1)}%',
        detail: model.follow ? 'engine' : null,
        value: accuracy,
        onChanged: model.follow ? null : model.setAccuracy,
      ),
      const SizedBox(height: 6),
      LabeledSlider(
        label: next == null ? 'Progress' : 'Progress to ${next.name}',
        valueText: next == null
            ? 'final stage'
            : '${(model.progress * 100).toStringAsFixed(0)}%',
        value: model.progress,
        onChanged: next == null ? null : model.setProgress,
      ),
      const SizedBox(height: 4),
      ToggleRow(
        label: 'Follow engine curve',
        hint: model.follow
            ? 'Run tokens accrue from production and set stage, '
                  'progress and accuracy.'
            : 'Accuracy and progress are free sliders.',
        value: model.follow,
        onChanged: model.setFollow,
      ),
      if (model.follow)
        Padding(
          padding: const EdgeInsets.only(left: 2, top: 4),
          child: Text(
            'acc = 1 − 0.9·exp(−log10(tokens) / 3)',
            style: Styles.label.copyWith(
              letterSpacing: 0,
              color: Palette.textSecondary,
            ),
          ),
        ),
    ];
  }

  List<Widget> _training() {
    return [
      ChromeButton(
        label: 'Train',
        icon: Icons.bolt_rounded,
        tone: ButtonTone.primary,
        keyHint: 'Space',
        expand: true,
        tooltip: 'One forward and backward pass (trainingCount + 1)',
        onPressed: model.train,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          const Expanded(child: Text('Auto-tapper', style: Styles.body)),
          SizedBox(
            width: 188,
            child: Segmented<AutoTap>(
              options: [for (final a in AutoTap.values) (a, a.label)],
              selected: model.autoTap,
              onSelected: model.setAutoTap,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _display() {
    String label(Size s) => '${s.width.round()}×${s.height.round()}';
    return [
      const Text('Frame', style: Styles.body),
      const SizedBox(height: 8),
      ChipChoices<Size>(
        options: [for (final s in framePresets) (s, label(s))],
        selected: model.frame,
        onSelected: model.setFrame,
      ),
      const SizedBox(height: 16),
      const Text('Quality', style: Styles.body),
      const SizedBox(height: 8),
      Segmented<VizQuality>(
        options: [for (final q in VizQuality.values) (q, q.name)],
        selected: model.quality,
        onSelected: model.setQuality,
      ),
      const SizedBox(height: 12),
      ToggleRow(
        label: 'Reduced motion',
        hint: 'MediaQuery.disableAnimations',
        value: model.reducedMotion,
        onChanged: onReducedMotion,
      ),
      ToggleRow(
        label: 'High contrast',
        hint: 'MediaQuery.highContrast',
        value: model.highContrast,
        onChanged: model.setHighContrast,
      ),
      ToggleRow(
        label: 'Captions',
        hint: 'Layer captions, shown from 380 px wide',
        value: model.showCaptions,
        onChanged: model.setShowCaptions,
      ),
    ];
  }

  List<Widget> _time() {
    return [
      Row(
        children: [
          Expanded(
            child: ChromeButton(
              label: frozen ? 'Resume' : 'Freeze',
              icon: frozen ? Icons.play_arrow_rounded : Icons.pause_rounded,
              keyHint: 'P',
              expand: true,
              onPressed: onToggleFreeze,
            ),
          ),
          const SizedBox(width: 8),
          ChromeButton(
            label: '−1f',
            keyHint: ',',
            tooltip: 'Back 1/60 s',
            onPressed: frozen ? () => onStep(-1) : null,
          ),
          const SizedBox(width: 8),
          ChromeButton(
            label: '+1f',
            keyHint: '.',
            tooltip: 'Forward 1/60 s',
            onPressed: frozen ? () => onStep(1) : null,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        frozen
            ? 'The view paints a ValueNotifier<Duration> clock. '
                  'Taps and stage changes land on the frozen frame.'
            : 'Freezing swaps the view onto an external clock.',
        style: Styles.hint,
      ),
    ];
  }
}

const _shortcuts = <Widget>[
  ShortcutHint(keys: ['Space'], label: 'train'),
  ShortcutHint(keys: ['←', '→'], label: 'stage'),
  ShortcutHint(keys: ['P'], label: 'freeze'),
  ShortcutHint(keys: [',', '.'], label: 'step'),
  ShortcutHint(keys: ['S'], label: 'capture URL'),
];

/// The shortcuts in one line, for the top bar.
class ShortcutHintsRow extends StatelessWidget {
  const ShortcutHintsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _shortcuts.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          _shortcuts[i],
        ],
      ],
    );
  }
}

/// Eight pips (tap one to jump there), prev/next, +3 and reset (publish).
class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.model});

  final PlaygroundModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                child: _Pip(
                  index: i,
                  current: model.stage,
                  onTap: () => model.goTo(i),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(stages.first.name, style: Styles.hint),
            const Spacer(),
            Text(stages.last.name, style: Styles.hint),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChromeButton(
                label: 'Prev',
                keyHint: '←',
                expand: true,
                onPressed: model.stage > 0 ? model.previous : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChromeButton(
                label: 'Next',
                keyHint: '→',
                expand: true,
                onPressed: model.isLastStage ? null : model.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChromeButton(
                label: '+3 stages',
                icon: Icons.keyboard_double_arrow_right_rounded,
                expand: true,
                tooltip: 'Offline progress: one evolution across three stages',
                onPressed: model.isLastStage ? null : () => model.jump(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChromeButton(
                label: 'Reset',
                icon: Icons.restart_alt_rounded,
                expand: true,
                tooltip: 'Publish a paper: back to stage 1 with a new loss run',
                onPressed: model.publish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.index, required this.current, required this.onTap});

  final int index;
  final int current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = index == current
        ? Palette.cyan
        : (index < current
              ? Palette.violet.withValues(alpha: 0.5)
              : Palette.border);
    return Tooltip(
      message: '${index + 1} · ${stages[index].name}',
      child: Semantics(
        button: true,
        selected: index == current,
        label: 'Stage ${index + 1}, ${stages[index].name}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 22,
            child: Center(
              child: AnimatedContainer(
                duration: chromeDuration(context, 160),
                height: index == current ? 4 : 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

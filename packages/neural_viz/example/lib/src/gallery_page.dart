import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:neural_viz/neural_viz.dart';

import 'design.dart';
import 'stages.dart';
import 'widgets/controls.dart';
import 'widgets/shell.dart';

/// `?gallery=1`: all eight stages frozen at their hero frame, plus one live
/// view of the selected stage.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.onNavigate});

  final ValueChanged<ExampleRoute> onNavigate;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

/// Mid-stage inputs: a typical production rate and the engine's accuracy
/// halfway through the stage.
({double production, double accuracy, double progress}) _inputsFor(
  int stage, {
  double progress = 0.5,
}) {
  const production = [3.0, 80.0, 3e3, 2e5, 1e7, 5e8, 3e10, 1e12];
  return (
    production: production[stage],
    accuracy: engineAccuracy(tokensAt(stage, progress)),
    progress: stage == lastStage ? 1.0 : progress,
  );
}

class _GalleryPageState extends State<GalleryPage> {
  static final List<FixedVizClock> _heroClocks = [
    for (final s in stages) FixedVizClock(s.kind.heroTime),
  ];

  int _selected = 4;
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return ExampleShell(
      route: ExampleRoute.gallery,
      onNavigate: widget.onNavigate,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth >= 760 ? 32.0 : 16.0;
          final content = math.min(constraints.maxWidth - 2 * pad, 1280.0);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 28, pad, 48),
            child: Center(
              child: SizedBox(
                width: content,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(content),
                    const SizedBox(height: 36),
                    SectionLabel(
                      'Hero frames',
                      trailing: content >= 600 ? const _ClockNote() : null,
                    ),
                    if (content < 600) const _ClockNote(),
                    const SizedBox(height: 6),
                    _grid(content),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hero(double content) {
    final side = content >= 1100;
    final width = side ? math.min(content - 280 - 28, 900.0) : content;
    final height = (width * 520 / 900).clamp(220.0, 560.0).floorToDouble();
    final stage = stages[_selected];
    final inputs = _inputsFor(_selected, progress: 0.6);
    final view = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: NeuralNetworkView(
          topology: stage.topology,
          stage: _selected,
          nextTopology: nextTopologyOf(_selected),
          productionPerSecond: inputs.production,
          trainingCount: _taps,
          progress: inputs.progress,
          accuracy: inputs.accuracy,
          onTrain: () => setState(() => _taps++),
          semanticLabel: 'Neural network: ${stage.name}. Tap to train.',
        ),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE · ${_two(_selected + 1)} / ${_two(stages.length)}',
          style: Styles.label.copyWith(color: Palette.cyan),
        ),
        const SizedBox(height: 8),
        Text(stage.name, style: Styles.title),
        const SizedBox(height: 6),
        Text(stage.blurb, style: Styles.body),
        const SizedBox(height: 18),
        Wrap(
          spacing: 24,
          runSpacing: 14,
          children: [
            Readout(label: 'Layers', value: stage.shape),
            Readout(
              label: 'Production',
              value: '${formatCount(inputs.production)}/s',
            ),
            Readout(
              label: 'Accuracy',
              value: '${(inputs.accuracy * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Tap or press Space on the view to train. '
          'Pick a frame below to evolve or reset to it.',
          style: Styles.hint,
        ),
      ],
    );
    if (side) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          view,
          const SizedBox(width: 28),
          Expanded(
            child: Padding(padding: const EdgeInsets.only(top: 4), child: info),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [view, const SizedBox(height: 16), info],
    );
  }

  Widget _grid(double content) {
    // Four across from about 290 px each; the view is designed for 360+.
    final columns = content >= 1180 ? 4 : (content >= 600 ? 2 : 1);
    const gap = 16.0;
    final width = ((content - gap * (columns - 1)) / columns).floorToDouble();
    final height = (width * 0.62).floorToDouble();
    return Wrap(
      spacing: gap,
      runSpacing: 20,
      children: [
        for (var i = 0; i < stages.length; i++)
          _Thumbnail(
            index: i,
            size: Size(width, height),
            clock: _heroClocks[i],
            selected: i == _selected,
            onTap: () => setState(() => _selected = i),
          ),
      ],
    );
  }
}

class _ClockNote extends StatelessWidget {
  const _ClockNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FixedVizClock(kind.heroTime) · quality high',
      style: Styles.hint.copyWith(fontFamily: kMono),
    );
  }
}

String _two(int n) => '$n'.padLeft(2, '0');

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.index,
    required this.size,
    required this.clock,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Size size;
  final FixedVizClock clock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stage = stages[index];
    final inputs = _inputsFor(index);
    return Semantics(
      button: true,
      selected: selected,
      label: '${stage.name}, stage ${index + 1}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: chromeDuration(context, 160),
                  height: size.height + 2,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? Palette.cyan.withValues(alpha: 0.6)
                          : Palette.border,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: ExcludeSemantics(
                      child: NeuralNetworkView(
                        topology: stage.topology,
                        stage: index,
                        nextTopology: nextTopologyOf(index),
                        productionPerSecond: inputs.production,
                        progress: inputs.progress,
                        accuracy: inputs.accuracy,
                        clock: clock,
                        quality: VizQuality.high,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _two(index + 1),
                      style: Styles.label.copyWith(
                        color: selected ? Palette.cyan : Palette.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage.name,
                        style: Styles.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      stage.shape,
                      style: Styles.value.copyWith(
                        fontSize: 10.5,
                        color: Palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

# neural_viz

The animated neural network and the training-loss chart of Neural Idle,
drawn with `CustomPainter`. It depends only on Flutter and knows nothing
about the game engine: the app maps engine state to a few plain inputs.

- **Eight architectures, each with its own motif**: perceptron (Σ | step
  glyph and bias node), MLP (ReLU units and sparsity), CNN (a kernel
  scanning a tiny image), RNN (self-loops and echoes of past steps),
  Transformer (attention fans and residual arcs), LLM (causal attention, an
  autoregressive loop and a token stream), Multimodal (text, image and audio
  lanes fused) and AGI (counter-rotating rings that rewire themselves).
- **Driven by the game**: production sets signal count, speed and glow; each
  manual training plays a forward and a backward pass; accuracy sets weight
  contrast; progress shows ghosts of the next stage.
- **Transitions**: evolution (one sequence even for multi-stage jumps), a
  collapse when a paper is published, and a crossfade for same-stage changes.
- **Deterministic**: a frame is a pure function of the input history and
  scene time, so it looks the same at 30, 60 or 120 Hz, in tests and in
  screenshots.
- **Cheap**: the static network is cached as a picture (re-recorded only
  when its look changes), glows come from a sprite atlas, and widgets never
  rebuild per frame. `LossChart` has no
  ticker and `LossHistory` uses fixed memory.

## Public API

Everything comes from `package:neural_viz/neural_viz.dart`.

| Symbol | What it is |
| --- | --- |
| `NeuralNetworkView` | The animated network. Declarative: pass the current values on every rebuild. |
| `NetworkTopology` | Kind plus neurons per layer (2–8 layers of 1–16) and a seed. Value equality. |
| `NetworkKind` | The eight architectures. `fromId` takes `ArchitectureDef.id` (unknown ids fall back to `mlp`). `heroTime` is the scene time that makes the best still. |
| `NeuralVizTheme` | Colors and mono font. A `ThemeExtension`; the defaults are the Neural Idle tokens. |
| `VizQuality` | `auto` (high from 560 px wide, otherwise medium), `high`, `medium`, `low`. |
| `FixedVizClock` | A clock that never advances, for tests, thumbnails and screenshots. |
| `VizTransition`, `VizTransitionKind` | Passed to `onTransitionPeak` and `onTransitionEnd`. |
| `productionEnergy` | Tokens per second to 0–1 on a log scale (1e3/s → 0.28, 1e12/s → 1). |
| `LossHistory`, `LossMarker` | Loss samples of the current run, with stage markers and JSON save/restore. |
| `LossChart` | TensorBoard-style curve: jittered trace, debiased EMA, log axis, markers, readout. |

`NeuralNetworkView` inputs: `topology`, `stage`, `nextTopology`,
`productionPerSecond`, `trainingCount`, `progress`, `accuracy`, `onTrain`,
`onTransitionPeak`, `onTransitionEnd`, `clock`, `theme`, `quality`,
`showCaptions`, `paintBackground`, `playIntro` and `semanticLabel`.

## Wiring it to the engine

The app in this repository already does this: the view in
`lib/ui/screens/home_screen.dart`, the loss history in
`lib/state/game_controller.dart`. If the view moves between layouts (one
column and two, say), give it a `GlobalKey` so its state survives.

```dart
final arch = engine.architecture(s), next = engine.nextArchitecture(s);
NeuralNetworkView(
  topology: NetworkTopology.fromId(arch.id, arch.layers),
  nextTopology: next == null ? null : NetworkTopology.fromId(next.id, next.layers),
  stage: engine.stageIndex(s),
  productionPerSecond: engine.productionPerSecond(s),
  trainingCount: s.manualTrainings,
  progress: engine.stageProgress(s),
  accuracy: engine.accuracy(s),
  onTrain: controller.train,
  onTransitionPeak: (t) { HapticFeedback.mediumImpact(); showStageCard(t.toStage); },
  semanticLabel: l10n.networkLabel(arch.name.resolve(lang)),
);
// Once per second of play: lossHistory.add(engine.loss(s)).
// On a stage increase: lossHistory.mark(arch.name.resolve(lang)).
// On publishPaper: lossHistory.startRun().
```

`trainingCount` must be monotonic: the first value seen and any decrease only
reset the baseline, so loading a save never fires a burst of passes. A higher
`stage` plays an evolution, a lower one a reset, the same one a crossfade.

```dart
LossChart(history: lossHistory, semanticLabel: 'Training loss')
```

Persist the chart with `lossHistory.toJson()` and `LossHistory.fromJson`
(the core save codec does not include it).

## Sizing

- `NeuralNetworkView` fills its bounded constraints. Recommended sizes:
  desktop 560–900 × 380–520, mobile 360–430 × 240–320. Below 380 px wide it
  drops the layer captions and corner marks.
- `LossChart` is designed for 240–360 × 72–120 and switches to a compact
  sparkline below 64 px of height. Along an unbounded axis it takes 320 × 96.
- With `paintBackground: false` the view is transparent. Keep the surface
  behind it dark, because glows are additive.

## Fonts

The package bundles no fonts. Captions and numbers use
`NeuralVizTheme.monoFontFamily` (default `'JetBrains Mono'`) and fall back
silently to the platform font if the app has not registered it. Register
the font in the app, or pass the family you have:

```dart
ThemeData(extensions: const [NeuralVizTheme(monoFontFamily: 'JetBrains Mono')])
```

The example bundles JetBrains Mono and Space Grotesk (SIL OFL 1.1, licenses
in `example/assets/fonts/`).

## Reduced motion and accessibility

- **Reduced motion** (`MediaQuery.disableAnimationsOf`, re-read on every
  dependency change): no ticker runs. The view shows the still of its
  kind's `heroTime` at the current inputs. Taps give a short brightening of
  the inputs, and every transition becomes a 300 ms crossfade.
- **Photosensitivity**: at most 3 training waves start per second (one
  every 0.34 s, however fast the taps), and the evolution bloom is local and
  at most 0.35 alpha, once per transition.
- **Semantics**: one node. Decorative unless `semanticLabel` is given; with
  `onTrain` it is a button. `LossChart` reports the latest loss as its value.
- **Keyboard**: with `onTrain` the view is focusable, Space and Enter train,
  and the cursor is a click cursor.
- **High contrast** (`MediaQuery.highContrastOf`): stronger edges, thicker
  rims, brighter captions and grid.
- **Not color alone**: modalities differ by shape (circle, square, diamond)
  and a correct prediction adds a ring.
- `LossChart` text follows the text scale, clamped at 1.3.

## Example app

`example/` is web first and depends only on `neural_viz`.

```sh
cd example
flutter run -d chrome
# or: flutter build web --release --no-web-resources-cdn, then serve build/web
```

The route comes from the query string:

- **`/`, the playground**: one live view in a framed area with size presets,
  a stage stepper (prev, next, +3, reset), a log-scale production slider,
  accuracy and progress sliders with a "follow engine curve" mode, Train and
  an auto-tapper, reduced motion, high contrast, captions and quality
  toggles, and a `LossChart` fed once per second. Keyboard: Space trains,
  ←/→ change stage, P freezes time (the view switches to a
  `ValueNotifier<Duration>` clock), `,`/`.` step a frozen clock by 1/60 s and
  S copies (and prints) a capture URL for the current still.
- **`/?gallery=1`**: the eight stages frozen at `FixedVizClock(kind.heroTime)`
  with quality high, plus one live hero.
- **Capture mode, any `t=`**: a fixed-size frame at the top left with no
  chrome. `window.__vizReady` becomes `true` once the frame at `t` is on
  screen.

  ```
  ?stage=4&t=3.4&w=720&h=440&prod=1e7&acc=0.93&progress=0.9&quality=high
  ```

  | Parameter | Meaning (default) |
  | --- | --- |
  | `stage` | Stage index 0–7 (0) |
  | `t` | Scene time in seconds (3) |
  | `w`, `h` | Frame size in logical pixels (720 × 440) |
  | `prod`, `acc`, `progress` | Production per second (100), accuracy (0.5), progress (0.3) |
  | `taps` | Comma-separated tap times, e.g. `3.15,3.2` |
  | `from`, `switchAt` | Start at stage `from` and switch to `stage` at `switchAt` s (0.5), to capture a transition |
  | `quality` | `auto`, `high` (default), `medium` or `low` |
  | `motion=reduced` | Reduced motion |
  | `contrast=high` | High contrast |
  | `loss=1` | A 320 × 96 `LossChart` with a synthetic run under the frame |

## Tests

```sh
flutter test                  # in packages/neural_viz
flutter analyze               # here and in example/
LOSS_CHART_SHOTS=/tmp/loss flutter test test/loss/loss_chart_screenshots_test.dart
```

The last command writes `LossChart` PNGs for visual review and is skipped
without the variable.

# neural_viz_example

Playground, gallery and screenshot harness for
[`neural_viz`](../README.md#example-app). Web first; depends only on
`neural_viz`.

```sh
flutter run -d chrome
```

- `/`: the playground (every input of `NeuralNetworkView`, a `LossChart`
  and keyboard shortcuts).
- `/?gallery=1`: all eight stages at their hero frame, plus a live hero.
- `/?stage=4&t=3.4&w=720&h=440`: capture mode for screenshots; sets
  `window.__vizReady = true` once the frame is on screen.

Fonts: JetBrains Mono and Space Grotesk, SIL OFL 1.1 (`assets/fonts/`).

# neural_idle_core

The game engine behind **Neural Idle**: content, economy, progression,
offline progress and the save format. Pure Dart with no Flutter dependency,
so every rule is unit-tested and the economy can be simulated headlessly.

## Design

- **Immutable state, stateless rules.** `GameState` is a plain value and
  `GameEngine` methods take a state and return a new one. The Flutter app
  wraps this in a Riverpod notifier; nothing here knows about it.
- **Exact time integration.** Production is constant between architecture
  stages, so `advance` splits a time span at each stage threshold instead of
  stepping through it. A one-hour jump gives the same result as 3,600
  one-second ticks, which makes offline progress exact.
- **Content as data.** Hardware, research, architectures and the AI's lines
  are `const` definitions with English and Spanish text, injected through
  `GameContent` so tests can run the rules on small hand-made content.
- **Defensive saves.** `SaveCodec` writes versioned JSON and drops anything
  it doesn't recognise, so a stale or edited save never crashes the game.

## Pacing

`GreedyPlayer` plays the game headlessly: 4 taps per second, always buying
whatever pays for itself the soonest. `test/balance_test.dart` keeps the
first half hour, which is what a visitor from a portfolio link sees, within
bounds.

| Stage       | Reached at |
| ----------- | ---------- |
| MLP         | 40 s       |
| CNN         | 2 m 45 s   |
| RNN         | 8 m        |
| Transformer | 20 m       |
| LLM         | 55 m       |
| Multimodal  | 2 h 50 m   |
| AGI         | 7 h 30 m   |

## Usage

```dart
const engine = GameEngine();
var state = GameState.initial;

state = engine.train(state); // one tap on the train button
state = engine.buyGenerator(state, 'laptop') ?? state;
state = engine.advance(state, 0.1); // game loop tick, in seconds

final tokens = formatAmount(state.tokens, languageCode: 'es'); // "1,23K"
final model = engine.architecture(state).name.resolve('es');
```

## Commands

```sh
dart test
dart run tool/simulate.dart 12 4   # hours to simulate, taps per second
```

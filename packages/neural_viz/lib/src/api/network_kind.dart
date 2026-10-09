/// Architecture family: picks the layout, neuron shapes and signature motif.
///
/// Value names match `ArchitectureDef.id` in neural_idle_core on purpose, so
/// the app can map engine stages with [NetworkKind.fromId].
enum NetworkKind {
  perceptron(Duration(milliseconds: 2200)),
  mlp(Duration(milliseconds: 2600)),
  cnn(Duration(milliseconds: 3100)),
  rnn(Duration(milliseconds: 2900)),
  transformer(Duration(milliseconds: 3400)),
  llm(Duration(milliseconds: 3700)),
  multimodal(Duration(milliseconds: 3300)),
  agi(Duration(seconds: 41));

  const NetworkKind(this.heroTime);

  /// Scene time whose frame composes best as a still (signals mid-edge,
  /// motif visible). Used for reduced motion, thumbnails and screenshots.
  final Duration heroTime;

  /// The kind for an architecture id. Unknown ids fall back to [mlp], a
  /// plain dense network, so new engine content still renders.
  static NetworkKind fromId(String id) => _byId[id] ?? mlp;

  static final Map<String, NetworkKind> _byId = values.asNameMap();
}

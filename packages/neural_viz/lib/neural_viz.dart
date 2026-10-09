/// Animated neural network visualization and training-loss chart for
/// Neural Idle.
///
/// Knows nothing about the game engine: the app maps engine state to these
/// inputs (see README).
library;

export 'src/api/network_kind.dart' show NetworkKind;
export 'src/api/network_topology.dart' show NetworkTopology;
export 'src/api/viz_theme.dart' show NeuralVizTheme;
export 'src/api/viz_types.dart'
    show
        FixedVizClock,
        VizQuality,
        VizTransition,
        VizTransitionKind,
        productionEnergy;
export 'src/loss/loss_chart.dart' show LossChart;
export 'src/loss/loss_history.dart' show LossHistory, LossMarker;
export 'src/widget/neural_network_view.dart' show NeuralNetworkView;

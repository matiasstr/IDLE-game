import '../api/network_kind.dart';
import '../scene/motif.dart';
import 'agi_motif.dart';
import 'cnn_motif.dart';
import 'llm_motif.dart';
import 'mlp_motif.dart';
import 'multimodal_motif.dart';
import 'perceptron_motif.dart';
import 'rnn_motif.dart';
import 'transformer_motif.dart';

/// The motif drawn for each architecture kind.
Motif motifFor(NetworkKind kind) => switch (kind) {
  NetworkKind.perceptron => const PerceptronMotif(),
  NetworkKind.mlp => const MlpMotif(),
  NetworkKind.cnn => const CnnMotif(),
  NetworkKind.rnn => const RnnMotif(),
  NetworkKind.transformer => const TransformerMotif(),
  NetworkKind.llm => const LlmMotif(),
  NetworkKind.multimodal => const MultimodalMotif(),
  NetworkKind.agi => const AgiMotif(),
};

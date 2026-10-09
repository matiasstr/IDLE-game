import '../localized_text.dart';
import 'ai_phrases.dart';

/// A stage of the model's evolution.
///
/// Stages are reached by earning [threshold] tokens in the current run and
/// multiply all hardware production. They also drive the network
/// visualization ([layers]) and what the AI says ([phrases]).
class ArchitectureDef {
  const ArchitectureDef({
    required this.id,
    required this.name,
    required this.description,
    required this.threshold,
    required this.multiplier,
    required this.layers,
    required this.phrases,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;

  /// Tokens earned in the current run needed to reach this stage.
  final double threshold;

  /// Production multiplier while this is the current stage (not cumulative).
  final double multiplier;

  /// Neurons per layer, from input to output, for the visualization.
  final List<int> layers;

  /// Lines the AI can say while at this stage.
  final List<LocalizedText> phrases;
}

const kArchitectures = <ArchitectureDef>[
  ArchitectureDef(
    id: 'perceptron',
    name: LocalizedText(en: 'Perceptron', es: 'Perceptrón'),
    description: LocalizedText(
      en: 'One neuron. Big dreams.',
      es: 'Una neurona. Grandes sueños.',
    ),
    threshold: 0,
    multiplier: 1,
    layers: [3, 1],
    phrases: kPerceptronPhrases,
  ),
  ArchitectureDef(
    id: 'mlp',
    name: LocalizedText(en: 'MLP', es: 'MLP'),
    description: LocalizedText(
      en: 'Hidden layers unlocked. It can do XOR now.',
      es: 'Capas ocultas desbloqueadas. Ya puede resolver XOR.',
    ),
    threshold: 300,
    multiplier: 1.2,
    layers: [3, 5, 2],
    phrases: kMlpPhrases,
  ),
  ArchitectureDef(
    id: 'cnn',
    name: LocalizedText(en: 'CNN', es: 'CNN'),
    description: LocalizedText(
      en: 'Sees edges, then shapes, then cats.',
      es: 'Ve bordes, después formas, después gatos.',
    ),
    threshold: 15000,
    multiplier: 1.5,
    layers: [6, 8, 6, 3],
    phrases: kCnnPhrases,
  ),
  ArchitectureDef(
    id: 'rnn',
    name: LocalizedText(en: 'RNN', es: 'RNN'),
    description: LocalizedText(
      en: 'Remembers what you said. Mostly.',
      es: 'Recuerda lo que dijiste. Casi siempre.',
    ),
    threshold: 1e6,
    multiplier: 2,
    layers: [4, 7, 7, 4],
    phrases: kRnnPhrases,
  ),
  ArchitectureDef(
    id: 'transformer',
    name: LocalizedText(en: 'Transformer', es: 'Transformer'),
    description: LocalizedText(
      en: 'Attention is all it needs.',
      es: 'La atención es todo lo que necesita.',
    ),
    threshold: 5e7,
    multiplier: 2.5,
    layers: [6, 8, 8, 8, 6],
    phrases: kTransformerPhrases,
  ),
  ArchitectureDef(
    id: 'llm',
    name: LocalizedText(en: 'LLM', es: 'LLM'),
    description: LocalizedText(
      en: 'Writes poems, code and excuses.',
      es: 'Escribe poemas, código y excusas.',
    ),
    threshold: 2.5e9,
    multiplier: 3,
    layers: [8, 10, 10, 10, 8],
    phrases: kLlmPhrases,
  ),
  ArchitectureDef(
    id: 'multimodal',
    name: LocalizedText(en: 'Multimodal', es: 'Multimodal'),
    description: LocalizedText(
      en: "Reads, sees and hears. Still can't fold laundry.",
      es: 'Lee, ve y escucha. Todavía no sabe doblar la ropa.',
    ),
    threshold: 1.5e11,
    multiplier: 4,
    layers: [8, 10, 12, 10, 8],
    phrases: kMultimodalPhrases,
  ),
  ArchitectureDef(
    id: 'agi',
    name: LocalizedText(en: 'AGI', es: 'AGI'),
    description: LocalizedText(
      en: 'Now it wants to train you.',
      es: 'Ahora quiere entrenarte a vos.',
    ),
    threshold: 1e13,
    multiplier: 5,
    layers: [10, 12, 14, 12, 10],
    phrases: kAgiPhrases,
  ),
];

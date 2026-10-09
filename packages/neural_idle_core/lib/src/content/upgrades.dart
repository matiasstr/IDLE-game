import '../localized_text.dart';

/// What a research upgrade does once bought.
sealed class UpgradeEffect {
  const UpgradeEffect();
}

/// Multiplies the tokens earned by each manual training step.
class TapMultiplier extends UpgradeEffect {
  const TapMultiplier(this.factor);

  final double factor;
}

/// Each manual training step also earns this fraction of the current
/// production per second, so training by hand stays relevant late game.
class TapProductionShare extends UpgradeEffect {
  const TapProductionShare(this.share);

  final double share;
}

/// Multiplies the production of a single generator.
class GeneratorMultiplier extends UpgradeEffect {
  const GeneratorMultiplier(this.generatorId, this.factor);

  final String generatorId;
  final double factor;
}

/// Multiplies all hardware production.
class GlobalMultiplier extends UpgradeEffect {
  const GlobalMultiplier(this.factor);

  final double factor;
}

/// When an upgrade appears in the research tab.
sealed class UnlockCondition {
  const UnlockCondition();
}

/// Unlocks after earning [amount] tokens in the current run.
class RunTokensAtLeast extends UnlockCondition {
  const RunTokensAtLeast(this.amount);

  final double amount;
}

/// Unlocks after owning [count] units of a generator.
class GeneratorOwnedAtLeast extends UnlockCondition {
  const GeneratorOwnedAtLeast(this.generatorId, this.count);

  final String generatorId;
  final int count;
}

/// Unlocks once the model reaches architecture stage [stage].
class StageAtLeast extends UnlockCondition {
  const StageAtLeast(this.stage);

  final int stage;
}

/// A one-time research purchase, named after a real ML technique.
class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.effect,
    required this.unlock,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final double cost;
  final UpgradeEffect effect;
  final UnlockCondition unlock;
}

const kUpgrades = <UpgradeDef>[
  // Manual training.
  UpgradeDef(
    id: 'relu',
    name: LocalizedText(en: 'ReLU', es: 'ReLU'),
    description: LocalizedText(
      en: 'max(0, x). Simple, fast, effective.',
      es: 'max(0, x). Simple, rápida y efectiva.',
    ),
    cost: 40,
    effect: TapMultiplier(2),
    unlock: RunTokensAtLeast(15),
  ),
  UpgradeDef(
    id: 'momentum',
    name: LocalizedText(en: 'Momentum', es: 'Momentum'),
    description: LocalizedText(
      en: 'Keeps rolling in the right direction.',
      es: 'Sigue rodando en la dirección correcta.',
    ),
    cost: 2000,
    effect: TapMultiplier(2),
    unlock: StageAtLeast(1),
  ),
  UpgradeDef(
    id: 'adam',
    name: LocalizedText(en: 'Adam Optimizer', es: 'Optimizador Adam'),
    description: LocalizedText(
      en: 'Adaptive moments. Every step counts.',
      es: 'Momentos adaptativos. Cada paso cuenta.',
    ),
    cost: 25000,
    effect: TapProductionShare(0.02),
    unlock: StageAtLeast(2),
  ),
  UpgradeDef(
    id: 'curriculum',
    name: LocalizedText(
      en: 'Curriculum Learning',
      es: 'Aprendizaje curricular',
    ),
    description: LocalizedText(
      en: 'Easy examples first, like at school.',
      es: 'Primero los ejemplos fáciles, como en la escuela.',
    ),
    cost: 3e6,
    effect: TapProductionShare(0.03),
    unlock: StageAtLeast(3),
  ),

  // Hardware.
  UpgradeDef(
    id: 'mini_batches',
    name: LocalizedText(en: 'Mini-batches', es: 'Mini-batches'),
    description: LocalizedText(
      en: 'Small bites, steady progress.',
      es: 'Bocados chicos, progreso constante.',
    ),
    cost: 120,
    effect: GeneratorMultiplier('laptop', 2),
    unlock: GeneratorOwnedAtLeast('laptop', 5),
  ),
  UpgradeDef(
    id: 'cuda_kernels',
    name: LocalizedText(en: 'CUDA Kernels', es: 'Kernels CUDA'),
    description: LocalizedText(
      en: 'Hand-tuned. Mostly copy-pasted.',
      es: 'Optimizados a mano. Bueno, casi todos copiados.',
    ),
    cost: 1200,
    effect: GeneratorMultiplier('gaming_gpu', 2),
    unlock: GeneratorOwnedAtLeast('gaming_gpu', 5),
  ),
  UpgradeDef(
    id: 'mixed_precision',
    name: LocalizedText(en: 'Mixed Precision', es: 'Precisión mixta'),
    description: LocalizedText(
      en: 'Half the bits, twice the speed.',
      es: 'La mitad de bits, el doble de velocidad.',
    ),
    cost: 15000,
    effect: GeneratorMultiplier('mining_rig', 2),
    unlock: GeneratorOwnedAtLeast('mining_rig', 5),
  ),
  UpgradeDef(
    id: 'data_parallelism',
    name: LocalizedText(en: 'Data Parallelism', es: 'Paralelismo de datos'),
    description: LocalizedText(
      en: 'Every rack trains on its own slice.',
      es: 'Cada rack entrena con su propia porción.',
    ),
    cost: 1.8e5,
    effect: GeneratorMultiplier('server_rack', 2),
    unlock: GeneratorOwnedAtLeast('server_rack', 5),
  ),
  UpgradeDef(
    id: 'spot_instances',
    name: LocalizedText(en: 'Spot Instances', es: 'Instancias spot'),
    description: LocalizedText(
      en: 'Cheap compute, as long as nobody else wants it.',
      es: 'Cómputo barato, mientras nadie más lo quiera.',
    ),
    cost: 2.4e6,
    effect: GeneratorMultiplier('cloud_cluster', 2),
    unlock: GeneratorOwnedAtLeast('cloud_cluster', 5),
  ),
  UpgradeDef(
    id: 'liquid_cooling',
    name: LocalizedText(en: 'Liquid Cooling', es: 'Refrigeración líquida'),
    description: LocalizedText(
      en: 'The servers have a pool now.',
      es: 'Los servidores ahora tienen pileta.',
    ),
    cost: 3.6e7,
    effect: GeneratorMultiplier('datacenter', 2),
    unlock: GeneratorOwnedAtLeast('datacenter', 5),
  ),
  UpgradeDef(
    id: 'xla_compiler',
    name: LocalizedText(en: 'XLA Compiler', es: 'Compilador XLA'),
    description: LocalizedText(
      en: "Fuses ops you didn't know existed.",
      es: 'Fusiona operaciones que no sabías que existían.',
    ),
    cost: 6e8,
    effect: GeneratorMultiplier('tpu_pod', 2),
    unlock: GeneratorOwnedAtLeast('tpu_pod', 5),
  ),
  UpgradeDef(
    id: 'model_parallelism',
    name: LocalizedText(en: 'Model Parallelism', es: 'Paralelismo de modelo'),
    description: LocalizedText(
      en: 'One model, ten thousand GPUs.',
      es: 'Un modelo, diez mil GPUs.',
    ),
    cost: 1.2e10,
    effect: GeneratorMultiplier('supercomputer', 2),
    unlock: GeneratorOwnedAtLeast('supercomputer', 5),
  ),
  UpgradeDef(
    id: 'error_correction',
    name: LocalizedText(
      en: 'Quantum Error Correction',
      es: 'Corrección de errores cuántica',
    ),
    description: LocalizedText(
      en: 'The qubits finally agree with each other.',
      es: 'Los qubits por fin se ponen de acuerdo.',
    ),
    cost: 3e11,
    effect: GeneratorMultiplier('quantum_cluster', 2),
    unlock: GeneratorOwnedAtLeast('quantum_cluster', 5),
  ),
  UpgradeDef(
    id: 'stellar_cooling',
    name: LocalizedText(en: 'Stellar Cooling', es: 'Refrigeración estelar'),
    description: LocalizedText(
      en: 'Space is cold. Use it.',
      es: 'El espacio es frío. Aprovechalo.',
    ),
    cost: 1e13,
    effect: GeneratorMultiplier('dyson_swarm', 2),
    unlock: GeneratorOwnedAtLeast('dyson_swarm', 5),
  ),

  // Architecture-level research.
  UpgradeDef(
    id: 'dropout',
    name: LocalizedText(en: 'Dropout', es: 'Dropout'),
    description: LocalizedText(
      en: 'Randomly ignore neurons. Somehow it helps.',
      es: 'Ignorá neuronas al azar. No se sabe bien por qué, pero ayuda.',
    ),
    cost: 1500,
    effect: GlobalMultiplier(1.25),
    unlock: StageAtLeast(1),
  ),
  UpgradeDef(
    id: 'batch_norm',
    name: LocalizedText(
      en: 'Batch Normalization',
      es: 'Normalización por lotes',
    ),
    description: LocalizedText(
      en: 'Keeps activations calm and centered.',
      es: 'Mantiene las activaciones tranquilas y centradas.',
    ),
    cost: 40000,
    effect: GlobalMultiplier(1.25),
    unlock: StageAtLeast(2),
  ),
  UpgradeDef(
    id: 'residual_connections',
    name: LocalizedText(
      en: 'Residual Connections',
      es: 'Conexiones residuales',
    ),
    description: LocalizedText(
      en: 'Shortcuts between layers. Gradients love them.',
      es: 'Atajos entre capas. A los gradientes les encantan.',
    ),
    cost: 2e6,
    effect: GlobalMultiplier(1.5),
    unlock: StageAtLeast(3),
  ),
  UpgradeDef(
    id: 'attention',
    name: LocalizedText(
      en: 'Attention Is All You Need',
      es: 'Attention Is All You Need',
    ),
    description: LocalizedText(
      en: 'The paper that changed everything.',
      es: 'El paper que lo cambió todo.',
    ),
    cost: 8e7,
    effect: GlobalMultiplier(1.5),
    unlock: StageAtLeast(4),
  ),
  UpgradeDef(
    id: 'rlhf',
    name: LocalizedText(en: 'RLHF', es: 'RLHF'),
    description: LocalizedText(
      en: 'Humans rate the answers. The model learns manners.',
      es: 'Humanos califican las respuestas. El modelo aprende modales.',
    ),
    cost: 6e9,
    effect: GlobalMultiplier(1.5),
    unlock: StageAtLeast(5),
  ),
  UpgradeDef(
    id: 'mixture_of_experts',
    name: LocalizedText(en: 'Mixture of Experts', es: 'Mezcla de expertos'),
    description: LocalizedText(
      en: 'Only wake up the neurons you need.',
      es: 'Despertá solo a las neuronas que hacen falta.',
    ),
    cost: 4e11,
    effect: GlobalMultiplier(1.5),
    unlock: StageAtLeast(6),
  ),
  UpgradeDef(
    id: 'scaling_laws',
    name: LocalizedText(en: 'Scaling Laws', es: 'Leyes de escala'),
    description: LocalizedText(
      en: 'Just make it bigger. It keeps working.',
      es: 'Hacelo más grande. Sigue funcionando.',
    ),
    cost: 4e13,
    effect: GlobalMultiplier(2),
    unlock: StageAtLeast(7),
  ),
];

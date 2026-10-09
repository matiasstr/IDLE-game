import '../localized_text.dart';

/// Hardware that trains the model on its own, producing tokens every second.
class GeneratorDef {
  const GeneratorDef({
    required this.id,
    required this.name,
    required this.description,
    required this.baseCost,
    required this.baseProduction,
    this.costGrowth = 1.15,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;

  /// Price of the first unit.
  final double baseCost;

  /// Tokens per second produced by one unit, before multipliers.
  final double baseProduction;

  /// Each unit owned multiplies the price of the next one by this factor.
  final double costGrowth;
}

/// Hardware in shop order. Each tier costs 10–30× the previous one and takes
/// longer to pay for itself (20 s for a laptop, ~2 days for a Dyson swarm
/// before bonuses), which keeps growth from snowballing late game.
const kGenerators = <GeneratorDef>[
  GeneratorDef(
    id: 'laptop',
    name: LocalizedText(en: 'Old Laptop', es: 'Notebook vieja'),
    description: LocalizedText(
      en: 'Trains all night while the fan screams.',
      es: 'Entrena toda la noche mientras el ventilador grita.',
    ),
    baseCost: 10,
    baseProduction: 0.5,
  ),
  GeneratorDef(
    id: 'gaming_gpu',
    name: LocalizedText(en: 'Gaming GPU', es: 'GPU gamer'),
    description: LocalizedText(
      en: 'Borrowed from your gaming rig. Goodbye, FPS.',
      es: 'Prestada de tu PC gamer. Chau, FPS.',
    ),
    baseCost: 100,
    baseProduction: 4,
  ),
  GeneratorDef(
    id: 'mining_rig',
    name: LocalizedText(en: 'Ex-Mining Rig', es: 'Rig de minería reciclado'),
    description: LocalizedText(
      en: 'Finally doing something useful.',
      es: 'Por fin hace algo útil.',
    ),
    baseCost: 1200,
    baseProduction: 20,
  ),
  GeneratorDef(
    id: 'server_rack',
    name: LocalizedText(en: 'Server Rack', es: 'Rack de servidores'),
    description: LocalizedText(
      en: 'Your living room hums now.',
      es: 'Ahora tu living zumba.',
    ),
    baseCost: 15000,
    baseProduction: 85,
  ),
  GeneratorDef(
    id: 'cloud_cluster',
    name: LocalizedText(en: 'Cloud Cluster', es: 'Cluster en la nube'),
    description: LocalizedText(
      en: "Someone else's computers. Your bill.",
      es: 'Las computadoras son de otro. La factura, tuya.',
    ),
    baseCost: 2e5,
    baseProduction: 400,
  ),
  GeneratorDef(
    id: 'datacenter',
    name: LocalizedText(en: 'Data Center', es: 'Data center'),
    description: LocalizedText(
      en: 'Comes with its own power plant.',
      es: 'Viene con su propia central eléctrica.',
    ),
    baseCost: 3e6,
    baseProduction: 1500,
  ),
  GeneratorDef(
    id: 'tpu_pod',
    name: LocalizedText(en: 'TPU Pod', es: 'Pod de TPUs'),
    description: LocalizedText(
      en: 'Matrix multiplication, industrialized.',
      es: 'Multiplicación de matrices a escala industrial.',
    ),
    baseCost: 5e7,
    baseProduction: 7500,
  ),
  GeneratorDef(
    id: 'supercomputer',
    name: LocalizedText(en: 'Supercomputer', es: 'Supercomputadora'),
    description: LocalizedText(
      en: 'Weather forecasts are on hold.',
      es: 'El pronóstico del tiempo queda en pausa.',
    ),
    baseCost: 1e9,
    baseProduction: 50000,
  ),
  GeneratorDef(
    id: 'quantum_cluster',
    name: LocalizedText(en: 'Quantum Cluster', es: 'Cluster cuántico'),
    description: LocalizedText(
      en: 'Trains every possible model at once. Probably.',
      es: 'Entrena todos los modelos posibles a la vez. Probablemente.',
    ),
    baseCost: 2.5e10,
    baseProduction: 4e5,
  ),
  GeneratorDef(
    id: 'dyson_swarm',
    name: LocalizedText(en: 'Dyson Swarm', es: 'Enjambre de Dyson'),
    description: LocalizedText(
      en: 'The sun is your power supply now.',
      es: 'Ahora el sol es tu fuente de alimentación.',
    ),
    baseCost: 8e11,
    baseProduction: 4e6,
  ),
];

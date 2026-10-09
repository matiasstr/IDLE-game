import 'package:flutter/material.dart';

/// Static presentation fixtures. Production, prices, and progression belong to core.
abstract final class MockGameData {
  static const tokens = '12.4K';
  static const production = '+90/s';
  static const accuracy = 0.42;
  static const accuracyLabel = '42%';
  static const loss = '0.868';
  static const architecture = 'MLP';
  static const stage = 2;
  static const totalStages = 8;
  static const nextArchitecture = 'CNN';
  static const progressToNext = 0.35;
  static const trainingGain = '+12';
  static const speech = 'h3llo w0rld... am i learn1ng?';
  static const offlineDuration = '2h 14m';
  static const offlineTokens = '724K';

  static const hardware = [
    MockHardware(
      icon: Icons.laptop_mac_rounded,
      name: 'Old Laptop',
      descriptionEn: 'A humble beginning. Still learning.',
      descriptionEs: 'Un comienzo humilde. Sigue aprendiendo.',
      owned: 12,
      cost: '53',
      production: '+0.5/s',
      canAfford: true,
    ),
    MockHardware(
      icon: Icons.memory_rounded,
      name: 'Gaming GPU',
      descriptionEn: 'More cores. More possibilities.',
      descriptionEs: 'Más núcleos. Más posibilidades.',
      owned: 6,
      cost: '254',
      production: '+4/s',
      canAfford: true,
    ),
    MockHardware(
      icon: Icons.developer_board_rounded,
      name: 'Ex-Mining Rig',
      descriptionEn: 'A second life, a better purpose.',
      descriptionEs: 'Una segunda vida, un nuevo propósito.',
      owned: 2,
      cost: '1.59K',
      production: '+30/s',
      canAfford: true,
    ),
    MockHardware(
      icon: Icons.dns_outlined,
      name: 'Server Rack',
      descriptionEn: 'Your own little data center.',
      descriptionEs: 'Tu propio centro de datos.',
      owned: 0,
      cost: '13K',
      production: '+150/s',
      canAfford: false,
    ),
    MockHardware(
      icon: Icons.cloud_outlined,
      name: 'Cloud Cluster',
      descriptionEn: '',
      descriptionEs: '',
      owned: 0,
      cost: '',
      production: '',
      canAfford: false,
      locked: true,
    ),
  ];

  static const research = [
    MockResearch(
      name: 'ReLU',
      descriptionEn: 'Give your neurons a little activation.',
      descriptionEs: 'Una pequeña activación para tus neuronas.',
      effect: '×2 Old Laptop',
      cost: '100',
      canAfford: false,
      purchased: true,
    ),
    MockResearch(
      name: 'Mini-batches',
      descriptionEn: 'Learn together, train faster.',
      descriptionEs: 'Aprender en grupo, entrenar más rápido.',
      effect: '×2 Gaming GPU',
      cost: '2.5K',
      canAfford: true,
      purchased: false,
    ),
    MockResearch(
      name: 'Dropout',
      descriptionEn: 'A little forgetting makes you smarter.',
      descriptionEs: 'Olvidar un poco te hace más inteligente.',
      effect: '×2 Ex-Mining Rig',
      cost: '18K',
      canAfford: false,
      purchased: false,
    ),
    MockResearch(
      name: 'Adam Optimizer',
      descriptionEn: 'Find a better way down the gradient.',
      descriptionEs: 'Encuentra un mejor camino por el gradiente.',
      effect: '×2 tokens/s',
      cost: '50K',
      canAfford: false,
      purchased: false,
    ),
  ];
}

class MockHardware {
  const MockHardware({
    required this.icon,
    required this.name,
    required this.descriptionEn,
    required this.descriptionEs,
    required this.owned,
    required this.cost,
    required this.production,
    required this.canAfford,
    this.locked = false,
  });
  final IconData icon;
  final String name;
  final String descriptionEn;
  final String descriptionEs;
  final int owned;
  final String cost;
  final String production;
  final bool canAfford;
  final bool locked;
}

class MockResearch {
  const MockResearch({
    required this.name,
    required this.descriptionEn,
    required this.descriptionEs,
    required this.effect,
    required this.cost,
    required this.canAfford,
    required this.purchased,
  });
  final String name;
  final String descriptionEn;
  final String descriptionEs;
  final String effect;
  final String cost;
  final bool canAfford;
  final bool purchased;
}

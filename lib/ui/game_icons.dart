import 'package:flutter/material.dart';

/// Icon for each hardware tier, by engine generator id.
IconData generatorIcon(String generatorId) => switch (generatorId) {
  'laptop' => Icons.laptop_mac_rounded,
  'gaming_gpu' => Icons.memory_rounded,
  'mining_rig' => Icons.developer_board_rounded,
  'server_rack' => Icons.dns_rounded,
  'cloud_cluster' => Icons.cloud_rounded,
  'datacenter' => Icons.apartment_rounded,
  'tpu_pod' => Icons.grid_view_rounded,
  'supercomputer' => Icons.speed_rounded,
  'quantum_cluster' => Icons.blur_on_rounded,
  'dyson_swarm' => Icons.wb_sunny_rounded,
  _ => Icons.memory_rounded,
};

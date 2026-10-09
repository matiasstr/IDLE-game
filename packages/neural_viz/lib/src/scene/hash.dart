// Integer hashing that gives the same results on the Dart VM, dart2js and
// dart2wasm. Every intermediate value stays below 2^53, so JavaScript
// numbers never lose precision. Random, DateTime and Stopwatch are never used
// by the scene: a frame is a pure function of its inputs and time.

/// 32-bit multiplication modulo 2^32, split so no product exceeds 2^53.
int mul32(int a, int b) =>
    (((a & 0xffff) * b) + ((((a >>> 16) * b) & 0xffff) << 16)) & 0xffffffff;

/// Finalizer with good avalanche (lowbias32).
int mix32(int h) {
  h = (h ^ (h >>> 16)) & 0xffffffff;
  h = mul32(h, 0x7feb352d);
  h = (h ^ (h >>> 15)) & 0xffffffff;
  h = mul32(h, 0x846ca68b);
  return (h ^ (h >>> 16)) & 0xffffffff;
}

/// Hashes a seed and up to three integers to 32 bits.
int hash32(int seed, int a, [int b = 0, int c = 0]) {
  var h = mix32((seed + 0x9e3779b9) & 0xffffffff);
  h = mix32((h ^ (a & 0xffffffff)) & 0xffffffff);
  h = mix32((h ^ (b & 0xffffffff)) & 0xffffffff);
  return mix32((h ^ (c & 0xffffffff)) & 0xffffffff);
}

/// [hash32] mapped to [0, 1).
double hash01(int seed, int a, [int b = 0, int c = 0]) =>
    hash32(seed, a, b, c) / 4294967296.0;

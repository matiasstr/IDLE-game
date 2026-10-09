import 'package:flutter_test/flutter_test.dart';
import 'package:neural_viz/src/scene/hash.dart';

/// (seed, a, b, c, hash32). Frozen: every platform must produce exactly
/// these, or seeded scenes would look different on the web.
const _golden = <(int, int, int, int, int)>[
  (0, 0, 0, 0, 1106484830),
  (0, 1, 0, 0, 335112171),
  (1, 0, 0, 0, 3555472974),
  (0, 0, 1, 0, 2968491419),
  (0, 0, 0, 1, 726357435),
  (42, 7, 3, 1, 2087113152),
  (7, 42, 1, 3, 3981829155),
  (123456, 789, 10, 11, 3816673466),
  (-1, 0, 0, 0, 191656671),
  (0, -1, 0, 0, 18245268),
  (0, 0, -1, -1, 2520991607),
  (2147483647, 1, 2, 3, 1037968436),
  (4294967295, 4294967295, 4294967295, 4294967295, 506400190),
  (4294967295, 0, 0, 0, 191656671),
  (3, 0, 0, 7, 2376413517),
  (1, 100, 2, 3, 1881593422),
  (1, 100, 3, 2, 685100542),
  (3, 700, 0, 0, 3965935874),
  (3, 700, 1, 0, 2173393422),
  (3, 800, 1, 0, 2297179422),
  (5, 900, 0, 0, 1082011885),
  (5, 901, 0, 0, 59249466),
  (0, 5000, 0, 0, 2240150326),
  (11, 50000, 3, 2, 1168202747),
  (11, 50001, 3, 2, 567258237),
  (2024, 10, 20, 30, 2171581164),
  (99, 3, 5, 7, 1546034025),
  (99, 3, 7, 5, 4083367987),
  (65535, 65536, 65537, 0, 3611496455),
  (31337, 1, 1, 1, 1560593210),
  (8, 16, 32, 64, 341653410),
  (1000000007, 998244353, 0, 0, 3133194913),
];

/// Reference implementation with arbitrary-precision integers: the same
/// algorithm with no tricks to stay below 2^53.
int _referenceHash(int seed, int a, int b, int c) {
  final mask = BigInt.from(0xffffffff);
  BigInt mul(BigInt x, int k) => (x * BigInt.from(k)) & mask;
  BigInt mix(BigInt h) {
    h = (h ^ (h >> 16)) & mask;
    h = mul(h, 0x7feb352d);
    h = (h ^ (h >> 15)) & mask;
    h = mul(h, 0x846ca68b);
    return (h ^ (h >> 16)) & mask;
  }

  BigInt u32(int v) => BigInt.from(v) & mask;
  var h = mix((BigInt.from(seed) + BigInt.from(0x9e3779b9)) & mask);
  h = mix(h ^ u32(a));
  h = mix(h ^ u32(b));
  return mix(h ^ u32(c)).toInt();
}

void main() {
  group('hash32', () {
    test('matches the frozen golden values', () {
      for (final (seed, a, b, c, expected) in _golden) {
        expect(
          hash32(seed, a, b, c),
          expected,
          reason: 'hash32($seed, $a, $b, $c)',
        );
      }
    });

    test('matches an arbitrary-precision reference', () {
      for (final (seed, a, b, c, _) in _golden) {
        expect(hash32(seed, a, b, c), _referenceHash(seed, a, b, c));
      }
      for (var i = 0; i < 2000; i++) {
        final seed = hash32(17, i), a = hash32(18, i) - 0x7fffffff;
        final b = i * 7919, c = -i;
        expect(
          hash32(seed, a, b, c),
          _referenceHash(seed, a, b, c),
          reason: 'hash32($seed, $a, $b, $c)',
        );
      }
    });

    test('mul32 is multiplication modulo 2^32', () {
      for (var i = 0; i < 2000; i++) {
        final a = hash32(1, i), b = hash32(2, i);
        final expected =
            ((BigInt.from(a) * BigInt.from(b)) & BigInt.from(0xffffffff))
                .toInt();
        expect(mul32(a, b), expected);
      }
    });

    test('is deterministic and stays in 32 bits', () {
      for (var i = 0; i < 1000; i++) {
        final h = hash32(i, i * 3, i * 5, i * 7);
        expect(h, hash32(i, i * 3, i * 5, i * 7));
        expect(h, inInclusiveRange(0, 0xffffffff));
      }
    });

    test('omitted arguments are zero', () {
      expect(hash32(9, 4), hash32(9, 4, 0, 0));
      expect(hash32(9, 4, 2), hash32(9, 4, 2, 0));
    });

    test('argument order matters', () {
      expect(hash32(1, 2, 3, 4), isNot(hash32(1, 3, 2, 4)));
      expect(hash32(1, 2, 3, 4), isNot(hash32(2, 1, 3, 4)));
    });
  });

  group('hash01', () {
    test('is hash32 scaled to [0, 1)', () {
      for (final (seed, a, b, c, expected) in _golden) {
        final v = hash01(seed, a, b, c);
        expect(v, expected / 4294967296.0);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(1));
      }
    });

    test('is roughly uniform', () {
      const n = 20000;
      final bins = List.filled(10, 0);
      var sum = 0.0;
      for (var i = 0; i < n; i++) {
        final v = hash01(7, i, i ~/ 3);
        sum += v;
        bins[(v * 10).floor()]++;
      }
      expect(sum / n, closeTo(0.5, 0.01));
      for (final count in bins) {
        expect(count, closeTo(n / 10, n / 10 * 0.08));
      }
    });
  });
}

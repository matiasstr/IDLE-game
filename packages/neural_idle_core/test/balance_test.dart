import 'package:neural_idle_core/neural_idle_core.dart';
import 'package:neural_idle_core/simulation.dart';
import 'package:test/test.dart';

/// Guards the pacing of the first half hour: that's what someone trying the
/// game from a portfolio link will see, so the AI has to evolve every few
/// minutes, but not so fast that the stages blur together.
void main() {
  final result =
      const GreedyPlayer(tapsPerSecond: 4).play(const Duration(minutes: 30));

  void expectStageBetween(String id, Duration earliest, Duration latest) {
    final index = kArchitectures.indexWhere((a) => a.id == id);
    final seconds = result.stageReachedAt[index];
    expect(seconds, isNotNull, reason: '$id was never reached');
    expect(
      seconds,
      inInclusiveRange(earliest.inSeconds, latest.inSeconds),
      reason:
          '$id reached after ${formatDuration(Duration(seconds: seconds!))}',
    );
  }

  test('MLP arrives within the first minute and a half', () {
    expectStageBetween(
      'mlp',
      const Duration(seconds: 20),
      const Duration(seconds: 90),
    );
  });

  test('CNN arrives within five minutes', () {
    expectStageBetween(
      'cnn',
      const Duration(minutes: 2),
      const Duration(minutes: 5),
    );
  });

  test('RNN arrives within twelve minutes', () {
    expectStageBetween(
      'rnn',
      const Duration(minutes: 5),
      const Duration(minutes: 12),
    );
  });

  test('Transformer arrives within half an hour', () {
    expectStageBetween(
      'transformer',
      const Duration(minutes: 14),
      const Duration(minutes: 30),
    );
  });
}

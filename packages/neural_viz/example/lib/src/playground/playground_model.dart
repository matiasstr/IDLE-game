import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:neural_viz/neural_viz.dart';

import '../stages.dart';

/// Frame sizes worth checking: three phones, a tablet card and two desktop
/// game screens.
const framePresets = <Size>[
  Size(360, 240),
  Size(390, 280),
  Size(430, 320),
  Size(560, 380),
  Size(720, 440),
  Size(900, 520),
];

enum AutoTap {
  off(0, 'off'),
  slow(4, '4/s'),
  fast(10, '10/s');

  const AutoTap(this.rate, this.label);

  /// Trainings per second.
  final int rate;
  final String label;
}

/// Everything the playground controls, and a tiny stand-in for the game
/// engine.
///
/// In "follow engine curve" mode, run tokens accrue from production (and from
/// training) and drive accuracy, progress and stage the way `GameEngine`
/// does. Otherwise accuracy and progress are free sliders.
class PlaygroundModel extends ChangeNotifier {
  PlaygroundModel({
    int stage = 2,
    this.production = 2000,
    bool follow = true,
    double progress = 0.12,
  }) : _stage = stage,
       _follow = follow,
       _manualProgress = progress,
       runTokens = tokensAt(stage, progress) {
    _manualAccuracy = engineAccuracy(runTokens);
    loss = syntheticLossHistory(
      stage: stage,
      progress: progress,
      accuracy: accuracy,
      samples: 90,
    );
  }

  // ---------------------------------------------------------------- state

  int _stage;
  int get stage => _stage;
  StageDef get def => stages[_stage];
  NetworkTopology get topology => _topologies[_stage];
  NetworkTopology? get nextTopology =>
      _stage < lastStage ? _topologies[_stage + 1] : null;
  bool get isLastStage => _stage == lastStage;

  static final List<NetworkTopology> _topologies = [
    for (final s in stages) s.topology,
  ];

  /// Tokens per second (0 to 1e12).
  double production;

  bool _follow;
  bool get follow => _follow;

  /// Tokens earned in this run (engine mode).
  double runTokens;

  late double _manualAccuracy;
  double _manualProgress;

  /// Monotonic, like `GameState.manualTrainings`.
  int trainingCount = 0;

  AutoTap _autoTap = AutoTap.off;
  AutoTap get autoTap => _autoTap;

  bool _reducedMotion = false;
  bool get reducedMotion => _reducedMotion;

  bool _highContrast = false;
  bool get highContrast => _highContrast;

  bool _showCaptions = true;
  bool get showCaptions => _showCaptions;

  VizQuality _quality = VizQuality.auto;
  VizQuality get quality => _quality;

  Size _frame = framePresets[4];
  Size get frame => _frame;

  /// Fed once per second of (unfrozen) time with `-ln(accuracy)`.
  late final LossHistory loss;

  double get accuracy => _follow ? engineAccuracy(runTokens) : _manualAccuracy;

  double get progress {
    if (isLastStage) return 1;
    return _follow ? engineProgress(runTokens, _stage) : _manualProgress;
  }

  double _tapDebt = 0;
  double _lossClock = 0;

  // -------------------------------------------------------------- stages

  /// Moves to [target]. Up marks the loss chart; down is a published paper
  /// and starts a new run.
  void goTo(int target) {
    target = target.clamp(0, lastStage);
    if (target == _stage) return;
    _moveTo(target);
    if (_follow) runTokens = stages[target].threshold;
    notifyListeners();
  }

  void previous() => goTo(_stage - 1);
  void next() => goTo(_stage + 1);
  void jump(int count) => goTo(_stage + count);

  /// `publishPaper`: back to the first stage with a fresh run.
  void publish() {
    if (_stage != 0) {
      _moveTo(0);
    } else {
      loss.startRun();
    }
    runTokens = 0;
    notifyListeners();
  }

  void _moveTo(int target) {
    if (target > _stage) {
      loss.mark(stages[target].name);
    } else {
      loss.startRun();
    }
    _stage = target;
  }

  // ------------------------------------------------------------- signals

  void train() {
    trainingCount++;
    if (_follow) {
      runTokens += 1 + 0.1 * production;
      _climb();
    }
    notifyListeners();
  }

  void setProduction(double value) {
    production = value;
    notifyListeners();
  }

  void setAccuracy(double value) {
    if (_follow) return;
    _manualAccuracy = value;
    notifyListeners();
  }

  /// In engine mode this scrubs run tokens within the stage (stopping just
  /// short of the next threshold, which production then crosses).
  void setProgress(double value) {
    if (isLastStage) return;
    if (_follow) {
      runTokens = tokensAt(_stage, math.min(value, 0.995));
    } else {
      _manualProgress = value;
    }
    notifyListeners();
  }

  void setFollow(bool value) {
    if (value == _follow) return;
    if (value) {
      runTokens = tokensAt(_stage, isLastStage ? 0 : _manualProgress);
    } else {
      _manualAccuracy = engineAccuracy(runTokens);
      _manualProgress = engineProgress(runTokens, _stage);
    }
    _follow = value;
    notifyListeners();
  }

  void _climb() {
    final reached = engineStage(runTokens);
    if (reached > _stage) _moveTo(reached);
  }

  // ------------------------------------------------------------- display

  void setAutoTap(AutoTap value) {
    _autoTap = value;
    _tapDebt = 0;
    notifyListeners();
  }

  void setReducedMotion(bool value) {
    _reducedMotion = value;
    notifyListeners();
  }

  void setHighContrast(bool value) {
    _highContrast = value;
    notifyListeners();
  }

  void setShowCaptions(bool value) {
    _showCaptions = value;
    notifyListeners();
  }

  void setQuality(VizQuality value) {
    _quality = value;
    notifyListeners();
  }

  void setFrame(Size value) {
    _frame = value;
    notifyListeners();
  }

  // ---------------------------------------------------------- simulation

  /// Advances the engine stand-in by [dt] seconds: the auto-tapper, run
  /// tokens and the once-per-second loss sample.
  void advance(double dt) {
    var changed = false;
    if (_autoTap.rate > 0) {
      _tapDebt += dt * _autoTap.rate;
      while (_tapDebt >= 1) {
        _tapDebt -= 1;
        trainingCount++;
        if (_follow) runTokens += 1 + 0.1 * production;
        changed = true;
      }
    }
    if (_follow && production > 0) {
      runTokens += production * dt;
      changed = true;
    }
    if (_follow) _climb();
    _lossClock += dt;
    while (_lossClock >= 1) {
      _lossClock -= 1;
      loss.add(lossOf(accuracy));
    }
    if (changed) notifyListeners();
  }

  /// Query parameters that reproduce the current still in capture mode.
  Map<String, String> captureParams(double t, Size frame) {
    final resolved = _quality != VizQuality.auto
        ? _quality
        : (frame.width >= 560 ? VizQuality.high : VizQuality.medium);
    return {
      'stage': '$_stage',
      't': t.toStringAsFixed(3),
      'w': '${frame.width.round()}',
      'h': '${frame.height.round()}',
      'prod': formatParam(production),
      'acc': accuracy.toStringAsFixed(3),
      'progress': progress.toStringAsFixed(3),
      'quality': resolved.name,
      if (_reducedMotion) 'motion': 'reduced',
      if (_highContrast) 'contrast': 'high',
    };
  }

  @override
  void dispose() {
    loss.dispose();
    super.dispose();
  }
}

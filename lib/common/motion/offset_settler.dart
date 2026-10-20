import 'package:PiliPlus/common/motion/springs.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:get/get.dart';

/// Springs a scroll-linked offset (e.g. the "sync" bar hide offset) to one of
/// its ends after the finger lifts, so the bars never rest half shown.
///
/// The value is clamped to `0..max`: it drives layout (the top bar height),
/// so an overshoot would push the whole list back and forth.
class OffsetSettler {
  OffsetSettler(this.offset, {required this.max});

  final RxDouble offset;
  final double max;

  Ticker? _ticker;

  bool get isSettling => _ticker != null;

  /// [show] settles to 0 (bars fully shown), otherwise to [max].
  void settle({required bool show}) {
    stop();
    final start = offset.value;
    final end = show ? 0.0 : max;
    if (start == end) return;
    final simulation = SpringSimulation(Springs.smooth, start, end, 0);
    _ticker = Ticker((elapsed) {
      final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      if (simulation.isDone(t)) {
        offset.value = end;
        stop();
      } else {
        offset.value = clampDouble(simulation.x(t), 0.0, max);
      }
    })..start();
  }

  void stop() {
    _ticker?.dispose();
    _ticker = null;
  }
}

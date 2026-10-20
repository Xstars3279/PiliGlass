import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Shared spring tokens.
///
/// `bounce` > 0 makes the spring underdamped (dampingRatio = 1 - bounce),
/// so it overshoots the target and settles back, which is what feels "Q弹".
/// `duration` is the perceived duration, not a hard stop.
abstract final class Springs {
  /// quick and without overshoot, e.g. pressing down
  static final snappy = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 220),
  );

  /// smooth, without overshoot, e.g. hiding things
  static final smooth = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
  );

  /// noticeable overshoot, e.g. showing things
  static final bouncy = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 460),
    bounce: 0.35,
  );

  /// strong overshoot for releasing a press: dampingRatio 0.3, so it swings
  /// past the target by about 37% of the press depth
  static final jelly = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 520),
    bounce: 0.7,
  );

  /// short and springy, for the dip of a quick tap: it has to be visible
  /// within the short delay before navigating
  static final tap = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.6,
  );
}

extension SpringAnimationController on AnimationController {
  /// Animates towards [target] with [spring], keeping the current velocity,
  /// so an interrupted animation changes direction smoothly instead of
  /// restarting from rest.
  ///
  /// Use an [AnimationController.unbounded] controller, otherwise the
  /// overshoot is clamped to [lowerBound]..[upperBound] and the bounce is lost.
  TickerFuture springTo(double target, SpringDescription spring) {
    return animateWith(SpringSimulation(spring, value, target, velocity));
  }
}

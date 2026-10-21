import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart' show Ticker;
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

/// A value that follows a target with a spring, stepping the spring once per
/// frame from the current position and velocity.
///
/// Unlike [SpringAnimationController.springTo], changing the target does not
/// restart a simulation at t = 0. Pointer events arrive faster than frames,
/// so restarting on every drag event would keep the simulation at its start
/// and the value would barely move until the finger lifts.
class SpringFollower extends ChangeNotifier {
  SpringFollower({
    required TickerProvider vsync,
    required double value,
    required this.spring,
  }) : _value = value,
       _target = value {
    _ticker = vsync.createTicker(_tick);
  }

  late final Ticker _ticker;
  SpringDescription spring;

  double _value;
  double _target;
  double _velocity = 0;
  Duration _lastElapsed = Duration.zero;

  double get value => _value;
  double get target => _target;

  /// units per second
  double get velocity => _velocity;

  void animateTo(double target, {SpringDescription? spring}) {
    _target = target;
    if (spring != null) this.spring = spring;
    if (!_ticker.isActive && _value != target) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    }
  }

  /// Sets the value directly, e.g. while it follows a finger.
  void jumpTo(double value) {
    _ticker.stop();
    _value = _target = value;
    _velocity = 0;
    notifyListeners();
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    if (dt <= 0) return;
    final simulation = SpringSimulation(spring, _value, _target, _velocity);
    if (simulation.isDone(dt)) {
      _value = _target;
      _velocity = 0;
      _ticker.stop();
    } else {
      _value = simulation.x(dt);
      _velocity = simulation.dx(dt);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
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

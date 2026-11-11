// Adapted from prism_ui's lib/navigation_dock.dart (FloatingNavigationBar),
// the dock of FlClash, by chen08209 (GPL-3.0):
// https://github.com/chen08209/prism_ui
// Its springs, constants, rubber band and saturation curves and the way it
// derives the lens's stretch, carried over to PiliGlass's SpringFollower.
// See NOTICE.

import 'dart:math' as math;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:flutter/physics.dart';

/// How the lens of the glass dock and rail moves, after prism_ui's
/// NavigationDock (FlClash): it lands on a tab with a little bounce, follows
/// a dragging finger tightly, and on a loose spring of its own stretches
/// with its speed and squashes as it brakes, like water carried in a bottle.
/// Dragged past either end it pulls back like rubber; let go mid-flick it
/// goes on to the next tab.
abstract final class LensMotion {
  static final travel = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 400),
    bounce: 0.15,
  );
  static final drag = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1024,
    ratio: 0.9,
  );
  static final jelly = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 100,
    ratio: 0.4,
  );

  /// the lens keeps about its area: it thins as much again as it stretches,
  /// and a little more
  static const jellyAspect = 1.4;

  // tabs a second at which the stretch is nearly all there
  static const _jellySpeed = 3.0;
  static const _jellyStretch = 0.2;
  // tabs a second squared of braking at which the squash is nearly all there
  static const _jellyBrake = 25.0;
  static const _jellySquash = 0.15;

  /// how far past the end tabs the lens goes, in tabs, at most
  static const overdrag = 0.35;

  /// a flick carries the lens as far as it would go in this time, in seconds
  static const _flingProjection = 0.1;

  static double rubberBand(double overshoot, double limit) {
    final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
    return limit * pull * overshoot.sign;
  }

  /// 0 at 0, nearly 1 from about 2 on
  static double _saturate(double value) => 1 - 2 / (math.exp(2 * value) + 1);

  /// How stretched the lens at [position], in tabs, wants to be: by its
  /// speed, less as it brakes, which squashes it. [jelly] springs after it.
  static double jellyTarget(SpringFollower position) {
    final velocity = position.velocity;
    final spring = position.spring;
    final acceleration =
        (spring.stiffness * (position.target - position.value) -
            spring.damping * velocity) /
        spring.mass;
    final braking = math.max(0.0, -acceleration * velocity.sign);
    return _jellyStretch * _saturate(velocity.abs() / _jellySpeed) -
        _jellySquash * _saturate(braking / _jellyBrake);
  }

  /// [position] in tabs, past the end tabs pulled back like rubber
  static double banded(double position, int lastIndex) {
    if (position < 0) return rubberBand(position, overdrag);
    if (position > lastIndex) {
      return lastIndex + rubberBand(position - lastIndex, overdrag);
    }
    return position;
  }

  /// The tab a drag let go at [velocity], in tabs a second, lands on: the
  /// one it would reach soon, one past [pressed] at most.
  static int flung({
    required double target,
    required double velocity,
    required int pressed,
    required int lastIndex,
  }) => (target + velocity * _flingProjection)
      .round()
      .clamp(pressed - 1, pressed + 1)
      .clamp(0, lastIndex);
}

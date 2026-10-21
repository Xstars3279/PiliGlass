import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Tag for the cover of one list item. The same video can be in several
/// lists at once (recommended, hot...), each with its own item object, so
/// the item's identity keeps the tags apart.
String coverHeroTag(Object item) => 'cover-hero-${identityHashCode(item)}';

/// An underdamped spring as a curve: the cover lands with a slight bounce
/// (about 3%) instead of stopping dead.
class _SpringCurve extends Curve {
  const _SpringCurve();

  static const _zeta = 0.75;
  static const _omega = 10.0;

  @override
  double transformInternal(double t) {
    const wd = _omega * 0.6614378277661477; // _omega * sqrt(1 - zeta^2)
    final decay = math.exp(-_zeta * _omega * t);
    return 1 -
        decay * (math.cos(wd * t) + (_zeta * _omega / wd) * math.sin(wd * t));
  }
}

/// A video cover that flies between a list card and the player.
///
/// The corner radius morphs from the card's to the player's during the
/// flight, so [child] must not round its own corners: this widget clips it
/// with [borderRadius]. With [tag] null it only clips.
class CoverHero extends StatelessWidget {
  const CoverHero({
    super.key,
    required this.tag,
    required this.borderRadius,
    required this.child,
  });

  final Object? tag;

  /// the radius at this end of the flight
  final BorderRadius borderRadius;
  final Widget child;

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // the animation is the upper route's: 0 = card, 1 = player
    final push = direction == HeroFlightDirection.push;
    final card = (push ? fromHeroContext : toHeroContext)
        .findAncestorWidgetOfExactType<CoverHero>()!;
    final player = (push ? toHeroContext : fromHeroContext)
        .findAncestorWidgetOfExactType<CoverHero>()!;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => ClipRRect(
        borderRadius: BorderRadius.lerp(
          card.borderRadius,
          player.borderRadius,
          animation.value.clamp(0.0, 1.0),
        )!,
        child: child,
      ),
      // the card's image is already decoded at the right size
      child: card.child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipped = borderRadius == BorderRadius.zero
        ? child
        : ClipRRect(borderRadius: borderRadius, child: child);
    if (tag == null) return clipped;
    return Hero(
      tag: tag!,
      curve: const _SpringCurve(),
      transitionOnUserGestures: true,
      flightShuttleBuilder: _shuttle,
      child: clipped,
    );
  }
}

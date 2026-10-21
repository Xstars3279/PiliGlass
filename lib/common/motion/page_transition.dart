import 'dart:math' as math;

import 'package:flutter/gestures.dart';
// GetPageRouteTransitionMixin is not exported by package:get
// ignore: implementation_imports
import 'package:get/get_navigation/src/routes/get_transition_mixin.dart';
import 'package:material_ui/material_ui.dart';

/// iOS-like push with parallax, and a full-screen swipe to go back.
///
/// Installed through `tool/patches/getx_custom_transition.patch`, which lets
/// every GetX route build its transition here.
abstract final class PiliPageTransition {
  static const duration = Duration(milliseconds: 450);

  static void install() {
    GetPageRouteTransitionMixin.customTransitionBuilder = build;
    GetPageRouteTransitionMixin.customTransitionDuration = duration;
  }

  static Widget build(
    PageRoute<dynamic> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PageTransition(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: _BackGestureDetector(route: route, child: child),
    );
  }
}

/// A critically damped spring that starts with some velocity: it leaves
/// quickly and lands softly, without overshooting.
class _SpringCurve extends Curve {
  const _SpringCurve();

  // natural frequency per unit of the animation; settles by t = 1
  static const _w = 8.0;
  // initial velocity, as a fraction of _w
  static const _v = 0.6;

  @override
  double transformInternal(double t) =>
      1 - (1 + _w * (1 - _v) * t) * math.exp(-_w * t);
}

const _curve = _SpringCurve();

double _curved(Animation<double> animation, bool linear) {
  if (linear) return animation.value;
  // popping runs the same spring backwards: it starts fast as well
  return animation.status == AnimationStatus.reverse
      ? _curve.flipped.transform(animation.value)
      : _curve.transform(animation.value);
}

class _PageTransition extends StatelessWidget {
  const _PageTransition({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  /// how far the covered page moves left, as a fraction of the width
  static const _parallax = 0.28;
  static const _maxDim = 0.18;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (context, child) {
        // follow the finger 1:1 while it drags the page back
        final linear = route.popGestureInProgress;
        final enter = _curved(animation, linear);
        final cover = _curved(secondaryAnimation, linear);
        final width = MediaQuery.sizeOf(context).width;

        // Keep the same widgets whether the page moves or not: adding or
        // removing a wrapper would remount the page, and with it the back
        // gesture detector in the middle of its drag.
        final dx = (1 - enter) * width - cover * width * _parallax;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: enter < 1
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.2 * math.min(1, (1 - enter) * 5),
                        ),
                        blurRadius: 24,
                      ),
                    ]
                  : null,
            ),
            child: DecoratedBox(
              position: .foreground,
              decoration: BoxDecoration(
                color: cover > 0
                    ? Colors.black.withValues(alpha: _maxDim * cover)
                    : null,
              ),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Drag right anywhere on the page to go back.
///
/// Nested horizontal gestures (tab views, carousels, the player's seek bar)
/// are deeper in the tree, so they see the pointer first and win the gesture
/// arena; the back gesture only starts where nothing else wants the drag.
class _BackGestureDetector extends StatefulWidget {
  const _BackGestureDetector({required this.route, required this.child});

  final PageRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackGestureDetector> createState() => _BackGestureDetectorState();
}

class _BackGestureDetectorState extends State<_BackGestureDetector> {
  late final HorizontalDragGestureRecognizer _recognizer =
      HorizontalDragGestureRecognizer(debugOwner: this)
        ..onStart = _onStart
        ..onUpdate = _onUpdate
        ..onEnd = _onEnd
        ..onCancel = _onCancel;

  AnimationController? _controller;

  /// minimum fling speed, in page widths per second
  static const _minFling = 1.0;

  @override
  void dispose() {
    // never leave the navigator stuck in a user gesture
    if (_controller != null) widget.route.navigator?.didStopUserGesture();
    _recognizer.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.route.popGestureEnabled) {
      _recognizer.addPointer(event);
    }
  }

  void _onStart(DragStartDetails details) {
    if (!widget.route.popGestureEnabled) return;
    widget.route.navigator!.didStartUserGesture();
    // ignore: invalid_use_of_protected_member
    _controller = widget.route.controller;
  }

  void _onUpdate(DragUpdateDetails details) {
    final controller = _controller;
    if (controller == null) return;
    controller.value -= details.primaryDelta! / context.size!.width;
  }

  void _onEnd(DragEndDetails details) {
    if (_controller == null) return;
    final velocity = details.velocity.pixelsPerSecond.dx / context.size!.width;
    _finish(
      velocity > _minFling ||
          (velocity > -_minFling && _controller!.value < 0.6),
    );
  }

  void _onCancel() {
    if (_controller != null) _finish(false);
  }

  void _finish(bool pop) {
    final controller = _controller!;
    final navigator = widget.route.navigator!;
    _controller = null;
    if (pop) {
      navigator.pop();
    } else {
      controller.forward();
    }
    if (controller.isAnimating) {
      // keep the transition linear until it settles, like Cupertino does
      late final AnimationStatusListener listener;
      listener = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(listener);
      };
      controller.addStatusListener(listener);
    } else {
      navigator.didStopUserGesture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

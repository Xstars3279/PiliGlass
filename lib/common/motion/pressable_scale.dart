import 'dart:async';

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/widgets.dart';

/// Shrinks [child] slightly while pressed and springs it back on release.
///
/// It listens to raw pointer events through a [Listener], so it never joins
/// the gesture arena: the child's own `InkWell` still receives the tap, and
/// an enclosing scrollable still receives the drag.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.94,
  });

  final Widget child;
  final double pressedScale;

  /// A quick flick on a list also starts with a pointer down, so the press is
  /// delayed a little to avoid every card twitching while scrolling.
  static const _pressDelay = Duration(milliseconds: 70);

  /// The quick tap dip bottoms out at ~65ms and is back at full size at
  /// ~175ms; navigating right away hides it under the new page.
  static const tapDelay = Duration(milliseconds: 150);

  /// Wraps a tap callback that navigates away, so the tap dip can be seen
  /// before the new page covers the card.
  static VoidCallback delayTap(FutureOr<void> Function() onTap) =>
      () => Future.delayed(tapDelay, onTap);

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  Timer? _pressTimer;
  Offset? _downPosition;
  bool _pressed = false;

  void _press() {
    _pressed = true;
    _controller.springTo(widget.pressedScale, Springs.snappy);
  }

  void _release() {
    _pressTimer?.cancel();
    _pressTimer = null;
    _downPosition = null;
    if (_pressed) {
      _pressed = false;
      _controller.springTo(1.0, Springs.jelly);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_downPosition != null) return; // ignore extra fingers
    _downPosition = event.position;
    _pressTimer = Timer(PressableScale._pressDelay, _press);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pressTimer?.isActive ?? false) {
      // A quick tap released before the delay. Pressing and releasing at the
      // same instant would show nothing, so kick the spring with a downward
      // velocity instead: it dips by about (1 - pressedScale) and bounces back.
      _release();
      _controller.animateWith(
        SpringSimulation(
          Springs.tap,
          _controller.value,
          1.0,
          -(1.0 - widget.pressedScale) * 30,
        ),
      );
      return;
    }
    _release();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_downPosition case final down?) {
      if ((event.position - down).distance > kTouchSlop) {
        _release(); // turned into a scroll
      }
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

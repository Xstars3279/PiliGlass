import 'package:PiliPlus/common/motion/springs.dart';
import 'package:flutter/widgets.dart';

/// Spring driven replacement of [AnimatedSlide] for a vertical slide.
///
/// [offset] is a fraction of the child's height, like [AnimatedSlide].
/// Moving towards 0 (showing) uses [showSpring], moving away uses
/// [hideSpring], so the child pops in with a small overshoot but leaves
/// without one.
class SpringSlide extends StatefulWidget {
  const SpringSlide({
    super.key,
    required this.offset,
    this.child,
    this.showSpring,
    this.hideSpring,
    this.overshootColor,
  });

  final double offset;
  final Widget? child;
  final SpringDescription? showSpring;
  final SpringDescription? hideSpring;

  /// For a bar docked at the screen bottom: overshooting upwards would open a
  /// gap below it, so a strip of this color is painted under the child.
  final Color? overshootColor;

  /// Taller than any overshoot of [Springs.bouncy] on a bar.
  static const _overshootFill = 48.0;

  @override
  State<SpringSlide> createState() => _SpringSlideState();
}

class _SpringSlideState extends State<SpringSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.offset,
  );

  @override
  void didUpdateWidget(SpringSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offset != oldWidget.offset) {
      final showing = widget.offset.abs() < oldWidget.offset.abs();
      _controller.springTo(
        widget.offset,
        showing
            ? widget.showSpring ?? Springs.bouncy
            : widget.hideSpring ?? Springs.smooth,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget? child = widget.child;
    if (widget.overshootColor case final color?) {
      child = Stack(
        clipBehavior: .none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -SpringSlide._overshootFill,
            child: ColoredBox(color: color),
          ),
          ?child,
        ],
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, _controller.value),
        child: child,
      ),
      child: child,
    );
  }
}

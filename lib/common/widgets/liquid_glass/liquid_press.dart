import 'dart:math' as math;

import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/motion/springs.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Swells under a press and stretches after a dragging finger, springing
/// back on release, as prism_ui's ElasticPress does (FlClash's dock).
///
/// The press only paints: layout, hit testing and anything anchored to the
/// child, such as a menu, see it at rest. A tap lets go before the swell has
/// risen; it rises all the way first, as UIKit lifts a tab bar's lens.
///
/// Off with 设置 › PiliGlass 特性 › 按压回弹, like the cards' dip.
/// Drives a [LiquidPress] with a press it does not hear, at global
/// positions, e.g. a finger that went down on the button and then slid into
/// the menu the button opened.
class LiquidPressController {
  _LiquidPressState? _state;

  void press(Offset globalPosition) => _state?._pressGlobal(globalPosition);

  void drag(Offset globalPosition) => _state?._dragGlobal(globalPosition);

  void release() => _state?._release();

  void cancel() => _state?._release();
}

class LiquidPress extends StatefulWidget {
  const LiquidPress({
    super.key,
    required this.child,
    this.enabled = true,
    this.maxGrowth = 16,
    this.pullPastEdges = false,
    this.panelOf,
    this.controller,
  });

  final bool enabled;

  /// The most a full press grows the panel, in dp.
  final double maxGrowth;

  /// A finger outside the panel pulls it past its own edges, instead of
  /// pulling only from where it went down.
  final bool pullPastEdges;

  /// Where the pressed panel lies in this box, when the box is larger.
  final Rect Function(RenderBox box)? panelOf;

  /// Lets a menu the button opened keep the press going after the finger
  /// leaves the button.
  final LiquidPressController? controller;

  final Widget child;

  @override
  State<LiquidPress> createState() => _LiquidPressState();
}

const _pressGrowth = 1 / 8;
const _pullLimit = 7 / 32;
const _pullStretch = 0.5;
const _liftSnap = 0.975;

final _pressSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 311,
  ratio: 0.593,
);
final _followSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 1024,
  ratio: 0.9,
);

double _rubberBand(double overshoot, double limit) {
  final pull = 1 - 1 / (overshoot.abs() * 0.55 / limit + 1);
  return limit * pull * overshoot.sign;
}

class _LiquidPressState extends State<LiquidPress>
    with TickerProviderStateMixin {
  late final _lift = SpringFollower(
    vsync: this,
    value: 0,
    spring: _pressSpring,
  );
  late final _pullX = SpringFollower(
    vsync: this,
    value: 0,
    spring: _followSpring,
  );
  late final _pullY = SpringFollower(
    vsync: this,
    value: 0,
    spring: _followSpring,
  );
  late final _motion = Listenable.merge([_lift, _pullX, _pullY]);

  int? _pointer;
  Offset _origin = Offset.zero;
  bool _releasing = false;

  bool get _enabled =>
      widget.enabled &&
      GlassFeatures.press &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _lift.addListener(_settle);
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(LiquidPress old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (old.controller?._state == this) {
        old.controller!._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller!._state = null;
    }
    _lift.dispose();
    _pullX.dispose();
    _pullY.dispose();
    super.dispose();
  }

  void _pressGlobal(Offset globalPosition) {
    if (!mounted || !_enabled) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      _swell(box.globalToLocal(globalPosition));
    }
  }

  void _dragGlobal(Offset globalPosition) {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      _pullToward(box.globalToLocal(globalPosition));
    }
  }

  void _swell(Offset origin) {
    _origin = origin;
    _releasing = false;
    _lift.animateTo(1, spring: _pressSpring);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_enabled ||
        _pointer != null ||
        event.buttons & kPrimaryButton == 0) {
      return;
    }
    _pointer = event.pointer;
    _swell(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!mounted || event.pointer != _pointer) {
      return;
    }
    _pullToward(event.localPosition);
  }

  void _pullToward(Offset position) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return;
    }
    final panel = widget.panelOf?.call(box) ?? Offset.zero & box.size;
    final limit = panel.shortestSide * _pullLimit;
    final pull = widget.pullPastEdges
        ? position -
              Offset(
                position.dx.clamp(panel.left, panel.right),
                position.dy.clamp(panel.top, panel.bottom),
              )
        : position - _origin;
    _pullX.animateTo(
      _rubberBand(pull.dx, limit),
      spring: _followSpring,
    );
    _pullY.animateTo(
      _rubberBand(pull.dy, limit),
      spring: _followSpring,
    );
  }

  void _handlePointerEnd(PointerEvent event) {
    if (!mounted || event.pointer != _pointer) {
      return;
    }
    _release();
  }

  void _release() {
    _pointer = null;
    _pullX.animateTo(0, spring: _pressSpring);
    _pullY.animateTo(0, spring: _pressSpring);
    _releasing = true;
    _settle();
  }

  // A tap lets go before the swell has risen; it rises all the way first.
  void _settle() {
    if (!_releasing || _lift.value < _liftSnap) {
      return;
    }
    _releasing = false;
    _lift.animateTo(0, spring: _pressSpring);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (_, child) => _PressTransform(
        lift: _lift.value,
        pull: Offset(_pullX.value, _pullY.value),
        maxGrowth: widget.maxGrowth,
        panelOf: widget.panelOf,
        child: child,
      ),
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerEnd,
        onPointerCancel: _handlePointerEnd,
        child: widget.child,
      ),
    );
  }
}

class _PressTransform extends SingleChildRenderObjectWidget {
  const _PressTransform({
    required this.lift,
    required this.pull,
    required this.maxGrowth,
    this.panelOf,
    super.child,
  });

  final double lift;
  final Offset pull;
  final double maxGrowth;
  final Rect Function(RenderBox box)? panelOf;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPressTransform()
      ..lift = lift
      ..pull = pull
      ..maxGrowth = maxGrowth
      ..panelOf = panelOf;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPressTransform renderObject,
  ) {
    renderObject
      ..lift = lift
      ..pull = pull
      ..maxGrowth = maxGrowth
      ..panelOf = panelOf;
  }
}

class _RenderPressTransform extends RenderProxyBox {
  double _lift = 0;
  Offset _pull = Offset.zero;
  double maxGrowth = 16;
  Rect Function(RenderBox box)? panelOf;

  set lift(double value) {
    if (value == _lift) {
      return;
    }
    _lift = value;
    markNeedsPaint();
  }

  set pull(Offset value) {
    if (value == _pull) {
      return;
    }
    _pull = value;
    markNeedsPaint();
  }

  Matrix4 get _transform {
    final panel = panelOf?.call(this) ?? Offset.zero & size;
    final swell =
        1 + _lift * math.min(_pressGrowth * 2, maxGrowth / panel.longestSide);
    final scaleX = swell * (1 + _pull.dx.abs() / panel.width * _pullStretch);
    final scaleY = swell * (1 + _pull.dy.abs() / panel.height * _pullStretch);
    final center = panel.center;
    return Matrix4.diagonal3Values(scaleX, scaleY, 1)..setTranslationRaw(
      center.dx * (1 - scaleX) + _pull.dx,
      center.dy * (1 - scaleY) + _pull.dy,
      0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty || (_lift == 0 && _pull == .zero)) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  /// The swell and the stretch are painted, so positions and hit tests that
  /// come in from outside (a finger sliding through the menu) have to be
  /// mapped through them as well.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_lift == 0 && _pull == .zero) {
      return;
    }
    transform.multiply(_transform);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_lift == 0 && _pull == .zero) {
      return super.hitTest(result, position: position);
    }
    final inverse = Matrix4.tryInvert(_transform);
    if (inverse == null) {
      return false;
    }
    return super.hitTest(
      result,
      position: MatrixUtils.transformPoint(inverse, position),
    );
  }
}

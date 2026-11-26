import 'dart:math' as math;

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_box.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Shows a bottom sheet that grows out of [from] (when [Revamp.enabled] and
/// [from] is non-null), falling back to [showModalBottomSheet] otherwise.
Future<T?> showGrowingSheet<T>({
  required BuildContext context,
  Rect? from,
  Alignment anchor = Alignment.topRight,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  double? heightFactor,
  bool useSafeArea = true,
  bool glass = false,
  bool press = false,
  bool pullPastEdges = false,
  bool useRootNavigator = false,
}) {
  if (!Revamp.enabled || from == null) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: true,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      builder: builder,
    );
  }
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final barrierColor =
      theme.bottomSheetTheme.modalBarrierColor ??
      Colors.black.withValues(alpha: isDark ? 0.5 : 0.32);

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (routeContext, animation, _) {
        final media = MediaQuery.of(routeContext);
        final sheetConstraints =
            constraints ??
            BoxConstraints(
              maxWidth: math.min(640, media.size.shortestSide),
            );
        Widget content = Builder(builder: builder);
        if (heightFactor != null) {
          content = FractionallySizedBox(
            heightFactor: heightFactor,
            widthFactor: 1,
            alignment: Alignment.bottomCenter,
            child: content,
          );
        }
        if (glass) {
          content = Material(
            type: MaterialType.transparency,
            child: GlassBox(
              radius: Revamp.sheetRadius,
              child: content,
            ),
          );
        } else {
          content = Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: Revamp.shape(
              const BorderRadius.vertical(
                top: Radius.circular(Revamp.sheetRadius),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          );
        }
        if (press) {
          content = LiquidPress(
            pullPastEdges: pullPastEdges,
            maxGrowth: 6,
            child: content,
          );
        }
        if (useSafeArea) {
          content = SafeArea(
            bottom: false,
            child: content,
          );
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: sheetConstraints,
            child: GrowFromRect(
              from: from,
              animation: curved,
              radius: Revamp.sheetRadius,
              anchor: anchor,
              child: content,
            ),
          ),
        );
      },
    ),
  );
}

/// Shows a dialog card that grows out of [from] (when [Revamp.enabled] and
/// [from] is non-null), falling back to [showDialog] otherwise.
Future<T?> showGrowingDialog<T>({
  required BuildContext context,
  Rect? from,
  Alignment anchor = Alignment.center,
  required WidgetBuilder builder,
  bool glass = false,
  bool barrierDismissible = true,
  bool useSafeArea = true,
  bool useRootNavigator = true,
}) {
  if (!Revamp.enabled || from == null) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final barrierColor =
      theme.dialogTheme.barrierColor ??
      Colors.black.withValues(alpha: isDark ? 0.54 : 0.4);

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (routeContext, animation, _) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final card = ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
          child: glass
              ? Material(
                  type: MaterialType.transparency,
                  child: GlassBox(
                    radius: Revamp.sheetRadius,
                    child: Builder(builder: builder),
                  ),
                )
              : Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  elevation: theme.dialogTheme.elevation ?? 6,
                  shape: Revamp.shape(
                    const BorderRadius.all(
                      Radius.circular(Revamp.sheetRadius),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Builder(builder: builder),
                ),
        );
        Widget dialog = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Center(
            child: GrowFromRect(
              from: from,
              animation: curved,
              radius: Revamp.sheetRadius,
              anchor: anchor,
              child: card,
            ),
          ),
        );
        if (useSafeArea) {
          dialog = SafeArea(child: dialog);
        }
        return dialog;
      },
    ),
  );
}

/// The global rect of [context]'s render box, for a panel to grow out of;
/// null while it has no size yet.
Rect? morphRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return null;
}

/// Grows its child up out of [from], a rect on the screen, as a route opens:
/// the child starts as tall as [from] and where [from] is, then grows
/// upwards into its own place, with a little overshoot. Closing runs it back
/// into [from]. For a panel that stands over a bar near the bottom, e.g. the
/// reply panel over the input bar.
class GrowFromBottom extends SingleChildRenderObjectWidget {
  const GrowFromBottom({
    super.key,
    required this.from,
    required this.animation,
    required this.radius,
    super.child,
  });

  final Rect from;
  final Animation<double> animation;
  final double radius;

  @override
  RenderGrowFromBottom createRenderObject(BuildContext context) =>
      RenderGrowFromBottom(from, animation, radius);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGrowFromBottom renderObject,
  ) {
    renderObject
      ..from = from
      ..animation = animation
      ..radius = radius;
  }
}

class RenderGrowFromBottom extends RenderProxyBox {
  RenderGrowFromBottom(this._from, this._animation, this._radius);

  Rect _from;
  set from(Rect value) {
    if (value == _from) return;
    _from = value;
    markNeedsPaint();
  }

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(markNeedsPaint);
    _animation = value;
    if (attached) _animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  final _clipHandle = LayerHandle<ClipRRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    super.dispose();
  }

  /// 0 at [_from] .. 1 in place; springy on the way out, quick back in
  double get _t {
    final value = _animation.value;
    return _animation.status == .reverse
        ? Curves.easeInCubic.transform(value)
        : Curves.easeOutBack.transform(value);
  }

  /// how far below its place the child is drawn
  double get _shift {
    if (!hasSize) return 0;
    final t = _t;
    if (t == 1) return 0;
    final bottom = localToGlobal(Offset(0, size.height)).dy;
    return (_from.bottom - bottom) * (1 - t);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final t = _t;
    if (t >= 1) {
      _clipHandle.layer = null;
      context.paintChild(child, offset);
      return;
    }
    final shift = _shift;
    final full = size.height;
    final start = _from.height.clamp(0.0, full);
    final height = start + (full - start) * t.clamp(0.0, 1.0);
    final clip = Rect.fromLTWH(0, full - height + shift, size.width, height);
    _clipHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      clip,
      RRect.fromRectAndRadius(clip, Radius.circular(_radius)),
      (context, offset) => context.paintChild(child, offset + Offset(0, shift)),
      oldLayer: _clipHandle.layer,
    );
  }

  // so the lens of the glass inside samples where the child is drawn
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _shift, 0, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(0, _shift),
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}

/// Grows its child out of [from], a rect on the screen, as a route opens: a
/// small copy of the panel appears where [from] is and travels, growing, to
/// its own place. Closing runs it back into [from].
///
/// For a large panel whose button is far from where the panel ends up, e.g.
/// the video page's ⋯ and its settings sheet.
class GrowFromRect extends SingleChildRenderObjectWidget {
  const GrowFromRect({
    super.key,
    required this.from,
    required this.animation,
    this.radius = 12,
    this.anchor = Alignment.topRight,
    super.child,
  });

  final Rect from;
  final Animation<double> animation;
  final double radius;

  /// Which corner of [from] the small copy starts on: the panel grows away
  /// from it. A trailing top-bar ⋯ uses [Alignment.topRight], a bottom bar
  /// [Alignment.bottomRight].
  final Alignment anchor;

  @override
  RenderGrowFromRect createRenderObject(BuildContext context) =>
      RenderGrowFromRect(from, animation, radius, anchor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGrowFromRect renderObject,
  ) {
    renderObject
      ..from = from
      ..animation = animation
      ..radius = radius
      ..anchor = anchor;
  }
}

class RenderGrowFromRect extends RenderProxyBox {
  RenderGrowFromRect(this._from, this._animation, this._radius, this._anchor);

  Rect _from;

  Alignment _anchor;
  set anchor(Alignment value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsPaint();
  }
  set from(Rect value) {
    if (value == _from) return;
    _from = value;
    markNeedsPaint();
  }

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) _animation.removeListener(markNeedsPaint);
    _animation = value;
    if (attached) _animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  double get _t => _animation.status == .reverse
      ? Curves.easeInCubic.transform(_animation.value)
      : Curves.easeOutCubic.transform(_animation.value);

  /// where the child is drawn, in its own coordinates, at the current frame
  Rect? _rect() {
    if (!hasSize || size.isEmpty) return null;
    final t = _t.clamp(0.0, 1.0);
    if (t >= 1) return Offset.zero & size;
    final origin = localToGlobal(Offset.zero);
    final from = _from.shift(-origin);
    // a panel keeps a visible body on screen even from a 42 dp button, on
    // the corner it grows away from
    final width = from.width.clamp(size.width * 0.2, size.width);
    final height = from.height.clamp(size.height * 0.2, size.height);
    final start = Rect.fromLTWH(
      _anchor.x > 0 ? from.right - width : from.left,
      _anchor.y > 0 ? from.bottom - height : from.top,
      width,
      height,
    );
    return Rect.lerp(start, Offset.zero & size, t);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final rect = _rect();
    if (rect == null || rect == Offset.zero & size) {
      context.paintChild(child, offset);
      return;
    }
    final sx = rect.width / size.width;
    final sy = rect.height / size.height;
    final matrix = Matrix4.identity()
      ..translateByDouble(rect.left, rect.top, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1);
    context.pushClipRRect(
      needsCompositing,
      offset,
      rect,
      RRect.fromRectAndRadius(rect, Radius.circular(_radius)),
      (context, offset) => context.pushTransform(
        needsCompositing,
        offset,
        matrix,
        (context, offset) => context.paintChild(child, offset),
      ),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final rect = _rect();
    if (rect == null || size.isEmpty) return;
    transform
      ..translateByDouble(rect.left, rect.top, 0, 1)
      ..scaleByDouble(rect.width / size.width, rect.height / size.height, 1, 1);
  }
}

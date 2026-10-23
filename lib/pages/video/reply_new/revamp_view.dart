part of 'view.dart';

/// The reply panel's look in the redesign: a capsule of glass floating over
/// the keyboard, with the text and the tools inside. Opened from the glass
/// input bar, it grows out of the bar. Kept apart from view.dart so that
/// file stays close to upstream.
extension _ReplyRevamp on _ReplyPageState {
  static const _radius = 24.0;

  Widget _revampBody() {
    final colorScheme = theme.colorScheme;
    Widget box = GlassBox(
      radius: _radius,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [...buildInputView(), buildImagePreview()],
      ),
    );
    final route = ModalRoute.of(context);
    if (route is PublishRoute && route.morphFrom != null) {
      box = _GrowFrom(
        from: route.morphFrom!,
        animation: route.animation!,
        radius: _radius,
        child: box,
      );
    }
    return ViewSafeArea(
      child: Align(
        alignment: .bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Padding(padding: const .fromLTRB(12, 0, 12, 8), child: box),
              // the keyboard's place, or the emotes when they replace it
              Flexible(
                child: buildPanelContainer(colorScheme.surfaceContainerLow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// the text right on the glass, above the tools
  Widget _revampField(Widget field) =>
      Padding(padding: const .fromLTRB(16, 12, 16, 0), child: field);

  Widget get _revampSend => Obx(
    () => PressableScale(
      pressedScale: 0.9,
      // as wide as the tonal button it replaces: the toolbar has no room
      child: FilledButton(
        onPressed: enablePublish.value ? onPublishThrottle : null,
        style: FilledButton.styleFrom(
          tapTargetSize: .shrinkWrap,
          visualDensity: .compact,
          padding: const .symmetric(horizontal: 20, vertical: 10),
        ),
        child: const Text('发送'),
      ),
    ),
  );
}

/// Grows its child out of [from], a rect on the screen, as the route opens:
/// the child starts as tall as [from] and where [from] is, then grows
/// upwards and moves into its own place, with a little overshoot. Closing
/// runs it back into [from].
class _GrowFrom extends SingleChildRenderObjectWidget {
  const _GrowFrom({
    required this.from,
    required this.animation,
    required this.radius,
    super.child,
  });

  final Rect from;
  final Animation<double> animation;
  final double radius;

  @override
  _RenderGrowFrom createRenderObject(BuildContext context) =>
      _RenderGrowFrom(from, animation, radius);

  @override
  void updateRenderObject(BuildContext context, _RenderGrowFrom renderObject) {
    renderObject
      ..from = from
      ..animation = animation
      ..radius = radius;
  }
}

class _RenderGrowFrom extends RenderProxyBox {
  _RenderGrowFrom(this._from, this._animation, this._radius);

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

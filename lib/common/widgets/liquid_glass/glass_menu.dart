import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

typedef GlassMenuOpen = void Function();

/// A control that opens a menu out of itself: the menu starts as a small
/// glass drop on the control, grows over it, and a finger that pressed the
/// control can keep sliding into the menu and pick a row.
///
/// [targetBuilder] receives the callback that opens it, so a bare icon, a
/// glass coin or a whole pill can be the anchor.
class GlassPopupAnchor<T> extends StatefulWidget {
  const GlassPopupAnchor({
    super.key,
    required this.targetBuilder,
    required this.itemBuilder,
    this.minWidth = 180,
    this.maxWidth = 280,
    this.alignEnd = true,
    this.gap = 6,
  });

  final Widget Function(GlassMenuOpen open) targetBuilder;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;
  final double minWidth;
  final double maxWidth;

  /// Whether the menu's trailing edge sits on the control's trailing edge,
  /// as a trailing ⋯ does.
  final bool alignEnd;

  final double gap;

  @override
  State<GlassPopupAnchor<T>> createState() => _GlassPopupAnchorState<T>();
}

class _GlassPopupAnchorState<T> extends State<GlassPopupAnchor<T>> {
  final _key = GlobalKey();
  final _hidden = ValueNotifier<bool>(false);
  final _snapshot = ValueNotifier<ui.Image?>(null);
  final _menuKey = GlobalKey<_AnchoredGlassMenuState<T>>();

  Timer? _timer;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _moved = false;
  bool _open = false;

  @override
  void dispose() {
    _timer?.cancel();
    _snapshot.value?.dispose();
    _snapshot.dispose();
    _hidden.dispose();
    super.dispose();
  }

  Rect? _anchorRect() {
    final box = _key.currentContext?.findRenderObject();
    final overlay = Overlay.of(
      context,
      rootOverlay: true,
    ).context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    return origin & box.size;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_open || _pointer != null) {
      return;
    }
    _pointer = event.pointer;
    _origin = event.position;
    _moved = false;
    // In a scrollable give a scroll the first chance; elsewhere the menu
    // opens on the down frame, as the reference's overflow menu does.
    if (Scrollable.maybeOf(context) == null) {
      _openMenu();
    } else {
      _timer = Timer(kPressTimeout, () {
        if (mounted && _pointer == event.pointer && !_moved) {
          _openMenu();
        }
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    final slop = computeHitSlop(
      event.kind,
      MediaQuery.maybeGestureSettingsOf(context),
    );
    if ((event.position - _origin).distance > slop) {
      _moved = true;
      _timer?.cancel();
    }
    if (_open) {
      _menuKey.currentState?.drag(event.position);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _timer?.cancel();
    if (_open) {
      _menuKey.currentState?.release(event.position);
    } else if (!_moved) {
      // A quick tap in a scrollable: the timer has not fired yet.
      _openMenu();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    _timer?.cancel();
    if (_open) {
      _menuKey.currentState?.cancel();
    }
  }

  Future<void> _openMenu() async {
    if (_open) {
      return;
    }
    final anchor = _anchorRect();
    final overlay = Overlay.of(
      context,
      rootOverlay: true,
    ).context.findRenderObject();
    if (anchor == null || overlay is! RenderBox) {
      return;
    }
    final items = widget.itemBuilder(context);
    if (items.isEmpty) {
      return;
    }
    _open = true;
    _snapshot.value?.dispose();
    _snapshot.value = null;
    _hidden.value = false;

    final future = showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      // the glass grows from the control; no dialog fade on top of it
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          child,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _AnchoredGlassMenu<T>(
            key: _menuKey,
            items: items,
            anchor: anchor,
            overlaySize: overlay.size,
            minWidth: widget.minWidth,
            maxWidth: widget.maxWidth,
            alignEnd: widget.alignEnd,
            animation: animation,
            snapshot: _snapshot,
          ),
    );

    // The control repaints its ink as it is pressed; capture it after the
    // frame the route was pushed into, then let the menu's drop carry it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) {
        return;
      }
      final boundary = _key.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary) {
        _snapshot.value = boundary.toImageSync(
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        _hidden.value = true;
      }
    });

    await future;
    if (!mounted) {
      return;
    }
    _hidden.value = false;
    _snapshot.value?.dispose();
    _snapshot.value = null;
    _open = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: ValueListenableBuilder<bool>(
        valueListenable: _hidden,
        builder: (context, hidden, child) =>
            Opacity(opacity: hidden ? 0 : 1, child: child),
        child: RepaintBoundary(
          key: _key,
          child: widget.targetBuilder(_openMenu),
        ),
      ),
    );
  }
}

class _AnchoredGlassMenu<T> extends StatefulWidget {
  const _AnchoredGlassMenu({
    super.key,
    required this.items,
    required this.anchor,
    required this.overlaySize,
    required this.minWidth,
    required this.maxWidth,
    required this.alignEnd,
    required this.animation,
    required this.snapshot,
  });

  final List<PopupMenuEntry<T>> items;
  final Rect anchor;
  final Size overlaySize;
  final double minWidth;
  final double maxWidth;
  final bool alignEnd;
  final Animation<double> animation;
  final ValueNotifier<ui.Image?> snapshot;

  @override
  State<_AnchoredGlassMenu<T>> createState() => _AnchoredGlassMenuState<T>();
}

class _AnchoredGlassMenuState<T> extends State<_AnchoredGlassMenu<T>> {
  final _press = LiquidPressController();
  late List<GlobalKey> _rowKeys;
  int? _pressedRow;

  @override
  void initState() {
    super.initState();
    _rowKeys = List.generate(widget.items.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(_AnchoredGlassMenu<T> old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      _rowKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
  }

  int? _rowAt(Offset global) {
    for (var i = 0; i < _rowKeys.length; i++) {
      final box = _rowKeys[i].currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final local = box.globalToLocal(global);
        if ((Offset.zero & box.size).contains(local)) {
          return i;
        }
      }
    }
    return null;
  }

  void drag(Offset global) {
    _press.drag(global);
    final row = _rowAt(global);
    if (row != _pressedRow) {
      setState(() => _pressedRow = row);
      if (row != null) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void release(Offset global) {
    _press.release();
    final row = _rowAt(global);
    setState(() => _pressedRow = null);
    if (row != null) {
      _choose(row);
    }
  }

  void cancel() {
    _press.cancel();
    setState(() => _pressedRow = null);
  }

  void _choose(int index) {
    final entry = widget.items[index];
    if (entry is PopupMenuItem<T> && entry.enabled) {
      // as PopupMenuItem.handleTap: pop first, then run the item's action
      Navigator.pop<T>(context, entry.value);
      entry.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const radius = Radius.circular(16);

    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: widget.anchor,
        alignEnd: widget.alignEnd,
        padding: MediaQuery.paddingOf(context),
        textDirection: Directionality.of(context),
      ),
      child: _GlassMenuMorph(
        anchor: widget.anchor,
        animation: widget.animation,
        snapshot: widget.snapshot,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: widget.minWidth,
            maxWidth: widget.maxWidth,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: math.max(
                120,
                widget.overlaySize.height -
                    MediaQuery.paddingOf(context).vertical -
                    32,
              ),
            ),
            child: CustomPaint(
              painter: GlassShadowPainter.of(
                radius: radius,
                shadow: UiGlass.shadowIn(colorScheme, UiGlass.panelShadow),
              ),
              foregroundPainter: GlassRimPainter(
                radius: radius,
                // menus are panels; a light rim at the glass levels
                opacity: UiGlass.rim * 0.4,
                isDark: isDark,
                edge: UiGlass.edge(colorScheme),
              ),
              child: LiquidGlass(
                radius: 16,
                blurSigma: UiGlass.panelBlur,
                refractionHeight: UiGlass.panelRefractionHeight,
                refractionAmount: UiGlass.panelRefractionAmount,
                saturation: UiGlass.saturation,
                color: UiGlass.panel(colorScheme),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    type: MaterialType.transparency,
                    child: LiquidPress(
                      controller: _press,
                      maxGrowth: 8,
                      pullPastEdges: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              _row(i, colorScheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(int index, ColorScheme colorScheme) {
    return KeyedSubtree(
      key: _rowKeys[index],
      child: Stack(
        children: [
          widget.items[index],
          if (_pressedRow == index)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The opening morph: a small drop on the anchor grows into the menu card,
/// the card is clipped to it with its corners squaring off, and the content
/// is seen through the drop rather than as a scaled screenshot.
class _GlassMenuMorph extends SingleChildRenderObjectWidget {
  const _GlassMenuMorph({
    required this.anchor,
    required this.animation,
    required this.snapshot,
    super.child,
  });

  final Rect anchor;
  final Animation<double> animation;
  final ValueListenable<ui.Image?> snapshot;

  @override
  RenderGlassMenuMorph createRenderObject(BuildContext context) =>
      RenderGlassMenuMorph(anchor, animation, snapshot);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMenuMorph renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..animation = animation
      ..snapshot = snapshot;
  }
}

class RenderGlassMenuMorph extends RenderProxyBox {
  RenderGlassMenuMorph(this._anchor, this._animation, this._snapshot);

  static final _open = SpringSimulation(
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 400,
      ratio: 0.754,
    ),
    0,
    1,
    0,
  );
  static final _corners = SpringSimulation(
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: 324,
      ratio: 0.75,
    ),
    1,
    0,
    0,
  );

  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
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

  ValueListenable<ui.Image?> _snapshot;
  set snapshot(ValueListenable<ui.Image?> value) {
    if (identical(value, _snapshot)) return;
    if (attached) _snapshot.removeListener(markNeedsPaint);
    _snapshot = value;
    if (attached) _snapshot.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  final _clipHandle = LayerHandle<ClipRRectLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _snapshot.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _snapshot.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    super.dispose();
  }

  double get _value => _animation.value.clamp(0.0, 1.0);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.isEmpty) {
      return;
    }
    final value = _value;
    if (value >= 0.999) {
      _clipHandle.layer = null;
      context.paintChild(child, offset);
      return;
    }
    final time = value * 0.45;
    final p = _open.x(time).clamp(0.0, 1.0);
    final card = Offset.zero & size;
    final origin = localToGlobal(Offset.zero);
    final anchor = _anchor.shift(-origin);
    final start = math.max(12.0, _anchor.shortestSide * 0.41);
    final platter = Rect.fromCenter(
      center: Offset.lerp(anchor.center, card.center, p)!,
      width: ui.lerpDouble(start, size.width, p)!,
      height: ui.lerpDouble(start, size.height, p)!,
    );
    final corners =
        16.0 +
        size.width *
            0.48 *
            _corners.x(math.max(0.0, time - 0.07));
    final radius = math.max(
      0.0,
      math.min(platter.height / 2, corners),
    );
    final rrect = RRect.fromRectAndRadius(
      platter,
      Radius.circular(radius),
    );

    _clipHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      platter,
      rrect,
      (context, offset) {
        // The button's snapshot is the seed the menu grows out of; it fades
        // as the card's own glass arrives.
        final image = _snapshot.value;
        if (image != null && p < 0.999) {
          final dst = Rect.fromCenter(
            center: platter.center,
            width: start,
            height: start,
          );
          context.canvas.drawImageRect(
            image,
            Offset.zero &
                Size(image.width.toDouble(), image.height.toDouble()),
            dst,
            Paint()
              ..color = Color.fromRGBO(0, 0, 0, 1 - p)
              ..filterQuality = FilterQuality.medium,
          );
        }

        final scale = platter.width / size.width;
        final matrix = Matrix4.translationValues(
          platter.center.dx,
          platter.center.dy,
          0,
        )
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
        void paintContent(PaintingContext context, Offset offset) =>
            context.pushTransform(
              needsCompositing,
              offset,
              matrix,
              (context, offset) => context.paintChild(child, offset),
            );
        final blur = 4 * (1 - p);
        if (blur > 0.1) {
          context.pushLayer(
            ImageFilterLayer(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            ),
            paintContent,
            offset,
          );
        } else {
          paintContent(context, offset);
        }
      },
      oldLayer: _clipHandle.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final value = _value;
    if (value >= 0.999 || size.isEmpty) {
      return;
    }
    final time = value * 0.45;
    final p = _open.x(time).clamp(0.0, 1.0);
    final card = Offset.zero & size;
    final origin = localToGlobal(Offset.zero);
    final anchor = _anchor.shift(-origin);
    final start = math.max(12.0, _anchor.shortestSide * 0.41);
    final platter = Rect.fromCenter(
      center: Offset.lerp(anchor.center, card.center, p)!,
      width: ui.lerpDouble(start, size.width, p)!,
      height: ui.lerpDouble(start, size.height, p)!,
    );
    final scale = platter.width / size.width;
    transform
      ..translateByDouble(platter.center.dx, platter.center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({
    required this.anchor,
    required this.alignEnd,
    required this.padding,
    required this.textDirection,
  });

  final Rect anchor;
  final bool alignEnd;
  final EdgeInsets padding;
  final TextDirection textDirection;

  static const _margin = 8.0;
  // the menu covers the button, its top edge a little above the button's
  static const _overlap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(
          0,
          constraints.maxWidth - padding.horizontal - 2 * _margin,
        ),
        maxHeight: math.max(
          0,
          constraints.maxHeight - padding.vertical - 2 * _margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minX = padding.left + _margin;
    final maxX = size.width - padding.right - _margin - childSize.width;
    var x = alignEnd ? anchor.right - childSize.width : anchor.left;
    x = x.clamp(minX, math.max(minX, maxX));

    final minY = padding.top + _margin;
    final maxY = size.height - padding.bottom - _margin - childSize.height;
    var y = anchor.top - _overlap;
    y = y.clamp(minY, math.max(minY, maxY));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.alignEnd != alignEnd ||
      old.padding != padding ||
      old.textDirection != textDirection;
}

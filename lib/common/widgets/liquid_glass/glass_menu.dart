import 'dart:math' as math;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:material_ui/material_ui.dart';

typedef GlassMenuOpen = void Function();

/// A control that opens a menu out of itself: the menu grows from the
/// control's edge, and a press inside it swells it like the dock.
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
  /// as a trailing ⋯ does, instead of its leading edge.
  final bool alignEnd;

  /// The room kept between the control and the menu.
  final double gap;

  @override
  State<GlassPopupAnchor<T>> createState() => _GlassPopupAnchorState<T>();
}

class _GlassPopupAnchorState<T> extends State<GlassPopupAnchor<T>> {
  final _key = GlobalKey();
  bool _open = false;

  Rect? _anchorRect() {
    final box = _key.currentContext?.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true).context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
      return null;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    return origin & box.size;
  }

  Future<void> _openMenu() async {
    if (_open) {
      return;
    }
    final anchor = _anchorRect();
    final overlay = Overlay.of(context, rootOverlay: true).context.findRenderObject();
    if (anchor == null || overlay is! RenderBox) {
      return;
    }
    _open = true;
    final items = widget.itemBuilder(context);
    if (items.isEmpty) {
      _open = false;
      return;
    }
    await showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, _, _) => _AnchoredGlassMenu<T>(
        items: items,
        anchor: anchor,
        overlaySize: overlay.size,
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
        alignEnd: widget.alignEnd,
        gap: widget.gap,
      ),
    );
    _open = false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.targetBuilder(_openMenu),
    );
  }
}

class _AnchoredGlassMenu<T> extends StatelessWidget {
  const _AnchoredGlassMenu({
    required this.items,
    required this.anchor,
    required this.overlaySize,
    required this.minWidth,
    required this.maxWidth,
    required this.alignEnd,
    required this.gap,
  });

  final List<PopupMenuEntry<T>> items;
  final Rect anchor;
  final Size overlaySize;
  final double minWidth;
  final double maxWidth;
  final bool alignEnd;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const radius = Radius.circular(16);
    final animation = ModalRoute.of(context)!.animation!;
    final below = anchor.bottom + gap + 160 < overlaySize.height;
    final alignment = below
        ? (alignEnd ? Alignment.topRight : Alignment.topLeft)
        : (alignEnd ? Alignment.bottomRight : Alignment.bottomLeft);

    return Stack(
      children: [
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _MenuLayout(
              anchor: anchor,
              gap: gap,
              alignEnd: alignEnd,
              padding: MediaQuery.paddingOf(context),
              textDirection: Directionality.of(context),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final t = SpringCurve(
                  Springs.bouncy,
                  const Duration(milliseconds: 360),
                ).transform(animation.value);
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, (below ? 1 : -1) * (1 - t) * 6),
                    child: Transform.scale(
                      scale: 0.78 + 0.22 * t,
                      alignment: alignment,
                      child: child,
                    ),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minWidth,
                  maxWidth: maxWidth,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      120,
                      overlaySize.height -
                          MediaQuery.paddingOf(context).vertical -
                          32,
                    ),
                  ),
                  child: CustomPaint(
                    painter: GlassShadowPainter.of(
                      radius: radius,
                      shadow: UiGlass.shadowIn(
                        colorScheme,
                        UiGlass.panelShadow,
                      ),
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
                            maxGrowth: 8,
                            pullPastEdges: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: items,
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
          ),
        ),
      ],
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout({
    required this.anchor,
    required this.gap,
    required this.alignEnd,
    required this.padding,
    required this.textDirection,
  });

  final Rect anchor;
  final double gap;
  final bool alignEnd;
  final EdgeInsets padding;
  final TextDirection textDirection;

  static const _margin = 8.0;

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
    var y = anchor.bottom + gap;
    if (y > maxY) {
      // no room below: open above the control
      y = anchor.top - gap - childSize.height;
    }
    y = y.clamp(minY, math.max(minY, maxY));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor ||
      old.gap != gap ||
      old.alignEnd != alignEnd ||
      old.padding != padding ||
      old.textDirection != textDirection;
}

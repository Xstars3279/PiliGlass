import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show VerticalDragGestureRecognizer;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:material_ui/material_ui.dart' hide Springs;

const double _kGlassSheetDragHeight = 60.0;

/// Fast sheet surface matching [CommentSheet]'s visual tokens:
/// [Revamp.sheetRadius] corners, [GlassRimPainter] highlight, and either a
/// pre-blurred frozen backdrop or a fast blended tint (no live BackdropFilter
/// during animations or over playing video).
class GlassSheetSurface extends StatelessWidget {
  const GlassSheetSurface({
    super.key,
    required this.child,
    this.radius = Revamp.sheetRadius,
    this.allCorners = false,
    this.overflowBottom = false,
    this.backdrop,
    this.leftOffset = 0,
    this.topOffset = 0,
  });

  final Widget child;
  final double radius;
  final bool allCorners;

  /// Extends the backdrop below the sheet bounds so a bouncy spring overshoot
  /// never exposes a gap at the bottom edge of the screen.
  final bool overflowBottom;
  final ValueListenable<ui.Image?>? backdrop;
  final double leftOffset;
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final corner = Radius.circular(radius);
    final borderRadius = allCorners
        ? BorderRadius.all(corner)
        : BorderRadius.vertical(top: corner);
    final panelTint = UiGlass.sheetPanel(colorScheme);
    final baseColor = Color.alphaBlend(panelTint, colorScheme.surface);

    final Widget backdropLayer;
    if (backdrop case final b?) {
      backdropLayer = CustomPaint(
        painter: _FrozenSheetBackdropPainter(
          backdrop: b,
          base: baseColor,
          color: panelTint,
          leftOffset: leftOffset,
          topOffset: topOffset,
        ),
        child: const SizedBox.expand(),
      );
    } else {
      backdropLayer = ColoredBox(color: baseColor);
    }

    final glass = CustomPaint(
      painter: allCorners
          ? GlassShadowPainter.of(
              radius: corner,
              shadow: UiGlass.shadowIn(colorScheme, UiGlass.panelShadow),
            )
          : null,
      foregroundPainter: GlassRimPainter(
        radius: corner,
        opacity: UiGlass.panelRim,
        isDark: isDark,
        edge: UiGlass.edge(colorScheme),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: backdropLayer,
      ),
    );

    if (overflowBottom && !allCorners) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -48,
            child: glass,
          ),
          ClipRRect(
            borderRadius: borderRadius,
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: glass),
        ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Top pill drag handle matching [CommentSheet]'s handle.
class GlassSheetHandle extends StatelessWidget {
  const GlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return SizedBox(
      height: 18,
      child: Center(
        child: Container(
          width: 32,
          height: 4,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    );
  }
}

/// Unified header bar for glass sheets & player panels.
class GlassSheetHeader extends StatelessWidget {
  const GlassSheetHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.onClose,
    this.showDivider = true,
  });

  final String title;
  final Widget? leading;
  final List<Widget>? trailing;
  final VoidCallback? onClose;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.only(
              left: leading != null ? 8 : 20,
              right: 8,
            ),
            child: Row(
              children: [
                ?leading,
                Expanded(
                  child: Text(
                    title,
                    style: UiType.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...?trailing,
                if (onClose != null)
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

/// Opens a bottom-rising glass sheet matching [CommentSheet]'s frozen glass
/// surface, top drag handle (pull up to expand / pull down to shrink or close),
/// and [Springs.sheet] bounce, falling back to [showModalBottomSheet] when
/// [Revamp.enabled] is false.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? heightFactor,
  BoxConstraints? constraints,
  bool showHandle = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  ThemeData? sheetTheme,
  RouteSettings? settings,
}) {
  if (!Revamp.enabled) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: true,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      builder: builder,
    );
  }
  final theme = sheetTheme ?? Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final barrierColor =
      theme.bottomSheetTheme.modalBarrierColor ??
      Colors.black.withValues(alpha: isDark ? 0.5 : 0.32);

  final screenSize = MediaQuery.sizeOf(context);
  final routeBoundary = _findRouteBoundary(context, screenSize);
  final backdrop = ValueNotifier<ui.Image?>(null);
  var disposed = false;
  if (UiGlass.clear && routeBoundary != null) {
    _captureFrozenBackdrop(
      routeBoundary,
      isDisposed: () => disposed,
      onReady: (img) {
        if (disposed) {
          img.dispose();
        } else {
          backdrop.value?.dispose();
          backdrop.value = img;
        }
      },
    );
  }

  return Navigator.of(context, rootNavigator: useRootNavigator)
      .push<T>(
        PageRouteBuilder<T>(
          settings: settings,
          opaque: false,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: barrierColor,
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (routeContext, animation, _) {
            final media = MediaQuery.of(routeContext);
            final sheetConstraints =
                constraints ??
                BoxConstraints(
                  maxWidth: math.min(640, media.size.shortestSide),
                );
            Widget inner = MediaQuery.removePadding(
              context: routeContext,
              removeTop: true,
              child: Builder(builder: builder),
            );
            Widget frame = _GlassSheetFrame(
              animation: animation,
              constraints: sheetConstraints,
              initialFactor: heightFactor,
              showHandle: showHandle,
              useSafeArea: useSafeArea,
              backdrop: backdrop,
              onClose: () => Navigator.of(routeContext).maybePop(),
              child: inner,
            );
            if (sheetTheme != null) {
              frame = Theme(data: sheetTheme, child: frame);
            }
            return frame;
          },
        ),
      )
      .whenComplete(() {
        disposed = true;
        backdrop.value?.dispose();
        backdrop.dispose();
      });
}

RenderRepaintBoundary? _findRouteBoundary(
  BuildContext context,
  Size screenSize,
) {
  RenderRepaintBoundary? best;
  context.visitAncestorElements((element) {
    final ro = element.renderObject;
    if (ro is RenderRepaintBoundary && ro.hasSize) {
      if ((ro.size.width - screenSize.width).abs() < 2 &&
          (ro.size.height - screenSize.height).abs() < 2) {
        best = ro;
        return false;
      }
    }
    return true;
  });
  return best;
}

Future<void> _captureFrozenBackdrop(
  RenderRepaintBoundary boundary, {
  required bool Function() isDisposed,
  required ValueChanged<ui.Image> onReady,
}) async {
  try {
    const scale = 1.0;
    final page = await boundary.toImage(pixelRatio: scale);
    if (isDisposed()) {
      page.dispose();
      return;
    }
    final recorder = ui.PictureRecorder();
    final bounds =
        Offset.zero &
        Size(
          page.width.toDouble(),
          page.height.toDouble(),
        );
    final sigma = (UiGlass.liquid ? UiGlass.sheetBlur : 8) * scale;
    ui.Canvas(recorder)
      ..saveLayer(
        bounds,
        Paint()
          ..imageFilter = sigma > 0
              ? ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: .clamp,
                )
              : null
          ..colorFilter = ColorFilter.matrix(
            _saturationMatrix(UiGlass.liquid ? UiGlass.saturation : 1.7),
          ),
      )
      ..drawImage(page, Offset.zero, Paint())
      ..restore();
    final picture = recorder.endRecording();
    final blurred = await picture.toImage(page.width, page.height);
    picture.dispose();
    page.dispose();
    onReady(blurred);
  } catch (_) {}
}

List<double> _saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final ir = (1 - s) * r, ig = (1 - s) * g, ib = (1 - s) * b;
  return [
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

class _FrozenSheetBackdropPainter extends CustomPainter {
  _FrozenSheetBackdropPainter({
    required this.backdrop,
    required this.base,
    required this.color,
    required this.leftOffset,
    required this.topOffset,
  }) : super(repaint: backdrop);

  final ValueListenable<ui.Image?> backdrop;
  final Color base;
  final Color color;
  final double leftOffset;
  final double topOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final image = backdrop.value;
    if (image == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = base);
      return;
    }
    canvas
      ..save()
      ..translate(-leftOffset, -topOffset)
      ..drawImage(image, Offset.zero, Paint()..filterQuality = .low)
      ..restore()
      ..drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FrozenSheetBackdropPainter old) =>
      old.backdrop != backdrop ||
      old.base != base ||
      old.color != color ||
      old.leftOffset != leftOffset ||
      old.topOffset != topOffset;
}

class _GlassSheetFrame extends StatefulWidget {
  const _GlassSheetFrame({
    required this.animation,
    required this.constraints,
    required this.initialFactor,
    required this.showHandle,
    required this.useSafeArea,
    required this.backdrop,
    required this.onClose,
    required this.child,
  });

  final Animation<double> animation;
  final BoxConstraints constraints;
  final double? initialFactor;
  final bool showHandle;
  final bool useSafeArea;
  final ValueListenable<ui.Image?> backdrop;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_GlassSheetFrame> createState() => _GlassSheetFrameState();
}

class _GlassSheetFrameState extends State<_GlassSheetFrame>
    with TickerProviderStateMixin {
  static final _enterCurve = SpringCurve(
    Springs.sheet,
    const Duration(milliseconds: 520),
  );
  static const _exitCurve = Curves.easeInCubic;

  late final SpringFollower _extentCtr = SpringFollower(
    vsync: this,
    value: widget.initialFactor ?? 1.0,
    spring: Springs.sheet,
  );
  late final SpringFollower _dragOffsetCtr = SpringFollower(
    vsync: this,
    value: 0,
    spring: Springs.sheet,
  );
  _HeaderDragRecognizer? _dragRecognizer;
  double _availableHeight = 400;
  double _screenHeight = 800;
  bool _dismissing = false;

  bool get _hasExtent => widget.initialFactor != null;

  List<double> get _stops {
    final initial = widget.initialFactor ?? 1.0;
    if (initial < 0.99) {
      return [0.0, initial, 1.0];
    }
    return const [0.0, 1.0];
  }

  @override
  void dispose() {
    _dragRecognizer?.dispose();
    _extentCtr.dispose();
    _dragOffsetCtr.dispose();
    super.dispose();
  }

  _HeaderDragRecognizer get _recognizer => _dragRecognizer ??=
      _HeaderDragRecognizer(debugOwner: this, maxY: _kGlassSheetDragHeight)
        ..onUpdate = (details) {
          if (_hasExtent) {
            final next =
                (_extentCtr.value - details.delta.dy / _availableHeight).clamp(
                  0.0,
                  1.0,
                );
            _extentCtr.jumpTo(next);
          } else {
            final next = (_dragOffsetCtr.value + details.delta.dy).clamp(
              -18.0,
              _screenHeight,
            );
            _dragOffsetCtr.jumpTo(next);
          }
        }
        ..onEnd = (details) {
          final velocity = details.velocity.pixelsPerSecond.dy;
          if (_hasExtent) {
            final size = _extentCtr.value;
            final stops = _stops;
            final double target;
            if (velocity.abs() > 600) {
              target = velocity < 0
                  ? stops.firstWhere((s) => s > size + 0.01, orElse: () => 1.0)
                  : stops.lastWhere((s) => s < size - 0.01, orElse: () => 0.0);
            } else {
              target = stops.reduce(
                (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
              );
            }
            if (target <= 0.01) {
              _dismissing = true;
              widget.onClose();
            } else {
              _extentCtr.animateTo(target);
            }
          } else {
            if (_dragOffsetCtr.value > 90 || velocity > 600) {
              _dismissing = true;
              widget.onClose();
            } else {
              _dragOffsetCtr.animateTo(0);
            }
          }
        }
        ..onCancel = () {
          if (_hasExtent) {
            final size = _extentCtr.value;
            final target = _stops.reduce(
              (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
            );
            _extentCtr.animateTo(target <= 0.01 ? _stops[1] : target);
          } else {
            _dragOffsetCtr.animateTo(0);
          }
        };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeTop = widget.useSafeArea ? media.padding.top : 0.0;
    final screenW = media.size.width;
    _screenHeight = media.size.height;
    _availableHeight = (_screenHeight - safeTop).clamp(1.0, double.infinity);

    final sheetWidth = math.min(
      screenW,
      widget.constraints.maxWidth.isFinite
          ? widget.constraints.maxWidth
          : screenW,
    );
    final leftOffset = (screenW - sheetWidth) / 2;

    final inner = Column(
      mainAxisSize: _hasExtent ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.showHandle) const GlassSheetHandle(),
        if (_hasExtent) Expanded(child: widget.child) else Flexible(child: widget.child),
      ],
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.animation,
          _extentCtr,
          _dragOffsetCtr,
        ]),
        builder: (context, child) {
          final raw = widget.animation.value;
          final progress = widget.animation.status == AnimationStatus.reverse
              ? _exitCurve.transform(raw)
              : _enterCurve.transform(raw);

          final double currentH = _hasExtent
              ? (_availableHeight * _extentCtr.value).clamp(
                  0.0,
                  _availableHeight,
                )
              : _availableHeight;
          final double routeDy =
              (1 - progress) * (_hasExtent ? currentH : _screenHeight * 0.6);
          final double dragDy = _hasExtent ? 0.0 : _dragOffsetCtr.value;
          final double dy = routeDy + dragDy;
          final double topOffset = _hasExtent
              ? _screenHeight - currentH + dy
              : safeTop + dy;

          Widget surface = GlassSheetSurface(
            overflowBottom: true,
            backdrop: widget.backdrop,
            leftOffset: leftOffset,
            topOffset: topOffset,
            child: child!,
          );
          if (_hasExtent) {
            surface = SizedBox(height: currentH, child: surface);
          }

          return Transform.translate(
            offset: Offset(0, dy),
            child: Listener(
              onPointerDown: (event) {
                if (!_dismissing) {
                  _recognizer.addPointer(event);
                }
              },
              child: ConstrainedBox(
                constraints: widget.constraints,
                child: surface,
              ),
            ),
          );
        },
        child: inner,
      ),
    );
  }
}

class _HeaderDragRecognizer extends VerticalDragGestureRecognizer {
  _HeaderDragRecognizer({super.debugOwner, required this.maxY});

  final double maxY;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.localPosition.dy < maxY && super.isPointerAllowed(event);
}

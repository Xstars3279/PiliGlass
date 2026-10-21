import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Springs of SukiSU-Ultra's DampedDragAnimation, Compose `spring(ratio, k)`.
SpringDescription _spring(double ratio, double stiffness) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: stiffness,
      ratio: ratio,
    );

final _followSpring = _spring(1, 1000);
final _pressSpring = _spring(1, 1000);
// different damping on each axis: the pill wobbles like jelly
final _scaleXSpring = _spring(0.6, 150);
final _scaleYSpring = _spring(0.7, 150);
final _panelSpring = _spring(1, 300);

const _kBarHeight = 64.0;
const _kBarPadding = 4.0;
const _kPillHeight = _kBarHeight - 2 * _kBarPadding;
const _kTabWidth = 82.0;
const _kPressedScale = 78 / 56;
const _kRubberBand = 4.0;
const _kBarBlur = 3.0;
const _kBarSaturation = 1.5;

class LiquidGlassNavigationDestination {
  const LiquidGlassNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
}

/// A floating, liquid glass bottom bar, ported from SukiSU-Ultra's
/// FloatingBottomBar (itself adapted from compose-miuix-ui's
/// IosLiquidGlassNavigationBar).
///
/// Press anywhere to lift the indicator into a glass lens, drag to slide it
/// across the tabs, release to select the tab under it.
class LiquidGlassNavigationBar extends StatefulWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    this.onDestinationSelected,
    this.bottomPadding = 8.0,
  }) : assert(destinations.length >= 2);

  final int selectedIndex;
  final List<LiquidGlassNavigationDestination> destinations;
  final ValueChanged<int>? onDestinationSelected;
  final double bottomPadding;

  @override
  State<LiquidGlassNavigationBar> createState() =>
      _LiquidGlassNavigationBarState();
}

class _LiquidGlassNavigationBarState extends State<LiquidGlassNavigationBar>
    with TickerProviderStateMixin {
  SpringFollower _follower(double value, SpringDescription spring) =>
      SpringFollower(vsync: this, value: value, spring: spring);

  /// indicator position, in tabs
  late final _position = _follower(
    widget.selectedIndex.toDouble(),
    _followSpring,
  );

  /// 0 idle .. 1 pressed
  late final _press = _follower(0, _pressSpring);
  late final _scaleX = _follower(1, _scaleXSpring);
  late final _scaleY = _follower(1, _scaleYSpring);

  /// raw horizontal drag distance, mapped to a small rubber band offset
  late final _panel = _follower(0, _panelSpring);

  late final Listenable _animation = Listenable.merge([
    _position,
    _press,
    _scaleX,
    _scaleY,
    _panel,
  ]);

  late int _currentIndex = widget.selectedIndex;
  int? _pointer;

  int get _count => widget.destinations.length;
  double get _width => _count * _kTabWidth + 2 * _kBarPadding;

  @override
  void didUpdateWidget(LiquidGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // selected from outside, e.g. by the back button
    if (widget.selectedIndex != _currentIndex && _pointer == null) {
      _currentIndex = widget.selectedIndex;
      _moveTo(_currentIndex.toDouble());
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    _scaleX.dispose();
    _scaleY.dispose();
    _panel.dispose();
    super.dispose();
  }

  void _moveTo(double target) {
    final clamped = target.clamp(0.0, (_count - 1).toDouble());
    if (clamped.round() != _position.target.round()) {
      HapticFeedback.selectionClick();
    }
    _position.animateTo(clamped);
  }

  double _tabAt(double x) =>
      ((x - _kBarPadding) / _kTabWidth).floorToDouble().clamp(
        0.0,
        (_count - 1).toDouble(),
      );

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _press.animateTo(1);
    _scaleX.animateTo(_kPressedScale);
    _scaleY.animateTo(_kPressedScale);
    _moveTo(_tabAt(event.localPosition.dx));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final dx = event.localDelta.dx;
    if (dx == 0) return;
    _moveTo(_position.target + dx / _kTabWidth);
    _panel.jumpTo(_panel.value + dx);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final index = _position.target.round();
    _moveTo(index.toDouble());
    _press.animateTo(0);
    _scaleX.animateTo(1);
    _scaleY.animateTo(1);
    _panel.animateTo(0);
    if (index != _currentIndex) {
      _currentIndex = index;
      widget.onDestinationSelected?.call(index);
    }
  }

  double get _panelOffset {
    final fraction = (_panel.value / _width).clamp(-1.0, 1.0);
    return _kRubberBand *
        fraction.sign *
        Curves.easeOut.transform(fraction.abs());
  }

  Widget _tabs({required bool selected, double scale = 1}) {
    return Row(
      children: [
        for (final (i, e) in widget.destinations.indexed)
          SizedBox(
            width: _kTabWidth,
            child: Semantics(
              selected: i == _currentIndex,
              button: true,
              label: e.label,
              onTap: () {
                _currentIndex = i;
                _moveTo(i.toDouble());
                widget.onDestinationSelected?.call(i);
              },
              excludeSemantics: true,
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisAlignment: .center,
                  spacing: 1,
                  children: [
                    selected ? e.selectedIcon : e.icon,
                    Text(
                      e.label,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == .dark;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    const barRadius = Radius.circular(_kBarHeight / 2);
    final barTint = colorScheme.surfaceContainer.withValues(alpha: 0.4);
    final selectedFill = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.1,
    );

    final baseTabs = IconTheme.merge(
      data: IconThemeData(size: 24, color: colorScheme.onSurface),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colorScheme.onSurface),
        child: _tabs(selected: false),
      ),
    );

    return Padding(
      padding: .fromLTRB(
        viewPadding.left,
        0,
        viewPadding.right,
        widget.bottomPadding + viewPadding.bottom,
      ),
      child: Listener(
        behavior: .opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: SizedBox(
          width: _width,
          height: _kBarHeight,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final press = _press.value.clamp(0.0, 1.0);
              final panelOffset = _panelOffset;

              // stretch along the motion, squash across it
              final velocity = (_position.velocity / 10).abs();
              final scaleX =
                  _scaleX.value / (1 - (velocity * 0.3).clamp(0.0, 0.06));
              final scaleY =
                  _scaleY.value * (1 - (velocity * 0.15).clamp(0.0, 0.04));

              final pillCenter = Offset(
                _kBarPadding +
                    (_position.value + 0.5) * _kTabWidth +
                    panelOffset,
                _kBarHeight / 2,
              );
              final pillRect = Rect.fromCenter(
                center: pillCenter,
                width: _kTabWidth * scaleX,
                height: _kPillHeight * scaleY,
              );
              final pillRRect = RRect.fromRectAndRadius(
                pillRect,
                Radius.circular(pillRect.height / 2),
              );
              final barScale = lerpDouble(1, 1 + 16 / _width, press)!;

              return Stack(
                clipBehavior: .none,
                children: [
                  // The bar: only the glass grows when pressed, not the tabs.
                  // It has a hole where the pill is, so the pill's own glass
                  // sees the sharp content behind the bar, not the bar's blur.
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _PillClipper(pillRRect, inverse: true),
                      child: Transform.translate(
                        offset: Offset(panelOffset, 0),
                        child: Transform.scale(
                          scale: barScale,
                          child: CustomPaint(
                            painter: _OuterShadowPainter(
                              radius: barRadius,
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.1,
                              ),
                            ),
                            foregroundPainter: _RimPainter(
                              radius: barRadius,
                              opacity: 0.75,
                              isDark: isDark,
                              glow: press,
                              glowCenter: pillCenter.dx - panelOffset,
                            ),
                            child: LiquidGlass(
                              blurSigma: _kBarBlur,
                              refractionHeight: 24,
                              refractionAmount: 24,
                              saturation: _kBarSaturation,
                              color: barTint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The pill's glass, below the accent tabs: at rest it looks
                  // like the bar it replaces, pressed it clears up completely.
                  Positioned.fromRect(
                    rect: pillRect,
                    child: LiquidGlass(
                      blurSigma: _kBarBlur * (1 - press),
                      saturation: lerpDouble(_kBarSaturation, 1.2, press)!,
                      color: Color.lerp(
                        Color.alphaBlend(selectedFill, barTint),
                        Colors.black.withValues(alpha: 0.03),
                        press,
                      ),
                    ),
                  ),
                  // the tabs, only outside the pill: inside it the accent
                  // tabs replace them instead of being drawn on top
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _PillClipper(pillRRect, inverse: true),
                      child: Padding(
                        padding: .only(
                          left: _kBarPadding + panelOffset,
                          top: _kBarPadding,
                          bottom: _kBarPadding,
                        ),
                        child: baseTabs,
                      ),
                    ),
                  ),
                  // the tabs in the accent color, only inside the pill
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _PillClipper(pillRRect),
                      child: Padding(
                        padding: .only(
                          left: _kBarPadding + panelOffset,
                          top: _kBarPadding,
                          bottom: _kBarPadding,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 24,
                            color: colorScheme.primary,
                          ),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(color: colorScheme.primary),
                            child: _tabs(
                              selected: true,
                              scale: lerpDouble(1, 1.2, press)!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The pill's lens, above the accent tabs so they bend too.
                  // Without blur: pressed, the pill is clear glass.
                  if (press > 0.001)
                    Positioned.fromRect(
                      rect: pillRect,
                      child: CustomPaint(
                        foregroundPainter: _RimPainter(
                          radius: Radius.circular(pillRect.height / 2),
                          opacity: press,
                          isDark: isDark,
                          innerShadow: press,
                        ),
                        child: LiquidGlass(
                          refractionHeight: 10 * press,
                          refractionAmount: 14 * press,
                          depthEffect: true,
                          chromaticAberration: 0.5,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PillClipper extends CustomClipper<Path> {
  _PillClipper(this.rrect, {this.inverse = false});

  final RRect rrect;

  /// clip to everything but the pill
  final bool inverse;

  @override
  Path getClip(Size size) {
    if (!inverse) return Path()..addRRect(rrect);
    return Path()
      ..fillType = .evenOdd
      ..addRect((Offset.zero & size).inflate(rrect.height))
      ..addRRect(rrect);
  }

  @override
  bool shouldReclip(_PillClipper oldClipper) =>
      oldClipper.rrect != rrect || oldClipper.inverse != inverse;
}

/// A drop shadow drawn only outside the shape, so it does not darken the
/// translucent glass.
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter({required this.radius, required this.color});

  final Radius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = .evenOdd
          ..addRect((Offset.zero & size).inflate(40))
          ..addRRect(rrect),
      )
      ..drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(.normal, 10),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// The specular rim: light from the top left and, weaker, the bottom right.
/// Optionally a glow under the finger and an inner shadow.
class _RimPainter extends CustomPainter {
  _RimPainter({
    required this.radius,
    required this.opacity,
    required this.isDark,
    this.glow = 0,
    this.glowCenter = 0,
    this.innerShadow = 0,
  });

  final Radius radius;
  final double opacity;
  final bool isDark;
  final double glow;
  final double glowCenter;
  final double innerShadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);

    if (glow > 0) {
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawCircle(
          Offset(glowCenter, size.height / 2),
          size.height,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Colors.white.withValues(
                      alpha: (isDark ? 0.08 : 0.15) * glow,
                    ),
                    Colors.white.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset(glowCenter, size.height / 2),
                    radius: size.height,
                  ),
                ),
        )
        ..restore();
    }

    if (innerShadow > 0) {
      final width = 8 * innerShadow;
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRRect(
          rrect.inflate(width / 2),
          Paint()
            ..style = .stroke
            ..strokeWidth = width
            ..color = Colors.black.withValues(alpha: 0.15 * innerShadow)
            ..maskFilter = MaskFilter.blur(.normal, width / 2),
        )
        ..restore();
    }

    if (opacity <= 0) return;
    final peak = (isDark ? 0.35 : 0.6) * opacity;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = .stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: .topLeft,
          end: .bottomRight,
          colors: [
            Colors.white.withValues(alpha: peak),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: peak * 0.5),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius ||
      old.opacity != opacity ||
      old.isDark != isDark ||
      old.glow != glow ||
      old.glowCenter != glowCenter ||
      old.innerShadow != innerShadow;
}

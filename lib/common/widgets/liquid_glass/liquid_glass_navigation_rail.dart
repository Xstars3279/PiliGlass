import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass_navigation_bar.dart'
    show LiquidGlassDockAction, LiquidGlassNavigationDestination;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Springs of the dock, see liquid_glass_navigation_bar.dart.
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
// the rail swelling overshoots, so the labels pop out
final _openSpring = _spring(0.5, 300);
final _closeSpring = _spring(0.7, 300);

const _kPadding = 4.0;
// closed: icons only
const _kWidth = 60.0;
const _kTabHeight = 60.0;
// open: each label under its icon, the rail a little larger
const _kOpenWidth = 64.0;
const _kOpenTabHeight = 70.0;
// The pill is a capsule standing up, inside its tab at rest. Pressed it
// grows taller than its tab and clearly wider than the rail, standing out
// past both its sides, the way the dock's pill rises out of the dock.
const _kPillWidth = 44.0;
const _kPillInset = 3.0;
const _kPillReach = 10.0;
const _kPressedScaleX = (_kOpenWidth + 2 * _kPillReach) / _kPillWidth;
const _kPressedScaleY = 94 / (_kOpenTabHeight - 2 * _kPillInset);
const _kCorner = Radius.circular(_kWidth / 2);
const _kGap = 12.0;
const _kEdge = 12.0;

/// where the top block sits in the room above the rail, as a fraction of
/// the room it leaves free: the golden section again, from the top
const _kHeaderAt = 0.382;

/// The dock of the redesign as a rail on the left, for wide screens: a
/// capsule with the tabs' icons, a round button below it for the tab's own
/// action, e.g. posting on 动态, and [header], e.g. the avatar and search,
/// on a block of its own above.
///
/// Nothing scrolls under the rail, only the page's plain background, so it
/// is drawn as the glass would look there, without the cost of blurring
/// what is behind; only the pill's lens, while pressed, bends for real.
///
/// At rest only the icons show. The moment a finger comes down, the rail
/// swells with a bounce and each label shows under its icon; the lens
/// follows the finger, and letting go selects the tab under it and shrinks
/// the rail back.
class LiquidGlassNavigationRail extends StatefulWidget {
  const LiquidGlassNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.header = const [],
    this.action,
  });

  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  /// on the glass block at the top left, one under another
  final List<Widget> header;
  final LiquidGlassDockAction? action;

  /// the room the rail takes at the left of the page while closed
  static const double extent = _kWidth + 2 * _kEdge;

  @override
  State<LiquidGlassNavigationRail> createState() =>
      _LiquidGlassNavigationRailState();
}

class _LiquidGlassNavigationRailState extends State<LiquidGlassNavigationRail>
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

  /// 0 icons only .. 1 swollen with the labels
  late final _open = _follower(0, _openSpring);

  late final Listenable _animation = Listenable.merge([
    _position,
    _press,
    _scaleX,
    _scaleY,
    _open,
  ]);

  late int _currentIndex = widget.selectedIndex;
  int? _pointer;
  double _downY = 0;

  int get _count => widget.destinations.length;

  /// the rail's height for a tab height
  double _heightFor(double tabHeight) => _count * tabHeight + 2 * _kPadding;

  double get _tabHeight =>
      lerpDouble(_kTabHeight, _kOpenTabHeight, _open.value)!;

  @override
  void didUpdateWidget(LiquidGlassNavigationRail oldWidget) {
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
    _open.dispose();
    super.dispose();
  }

  void _moveTo(double target) {
    final clamped = target.clamp(0.0, (_count - 1).toDouble());
    if (clamped.round() != _position.target.round()) {
      HapticFeedback.selectionClick();
    }
    _position.animateTo(clamped);
  }

  /// The tab under [y], in the space of the closed rail the finger landed
  /// on. The rail swells from its middle, so a point is mapped onto the
  /// rail as it is drawn now.
  double _tabAt(double y) {
    final tabHeight = _tabHeight;
    final top = (_heightFor(_kTabHeight) - _heightFor(tabHeight)) / 2;
    return ((y - top - _kPadding) / tabHeight).floorToDouble().clamp(
      0.0,
      (_count - 1).toDouble(),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downY = event.position.dy;
    _press.animateTo(1);
    _scaleX.animateTo(_kPressedScaleX);
    _scaleY.animateTo(_kPressedScaleY);
    _open.animateTo(1, spring: _openSpring);
    _moveTo(_tabAt(event.localPosition.dy));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final dy = event.localDelta.dy;
    if (dy == 0) return;
    _moveTo(_position.target + dy / _tabHeight);
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final index = _position.target.round();
    _moveTo(index.toDouble());
    _press.animateTo(0);
    _scaleX.animateTo(1);
    _scaleY.animateTo(1);
    _open.animateTo(0, spring: _closeSpring);
    if (index != _currentIndex) {
      _currentIndex = index;
      widget.onDestinationSelected?.call(index);
    } else if ((event.position.dy - _downY).abs() < kTouchSlop) {
      // a tap on the current tab: the page goes to its top, or refreshes
      widget.onDestinationSelected?.call(index);
    }
  }

  /// The tabs, each its icon with the label under it, showing as the rail
  /// swells.
  Widget _tabs({
    required bool selected,
    required double width,
    required double tabHeight,
    required double open,
  }) {
    final shown = open.clamp(0.0, 1.0);
    return Column(
      children: [
        for (final (i, e) in widget.destinations.indexed)
          SizedBox(
            width: width,
            height: tabHeight,
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
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  selected ? e.selectedIcon : e.icon,
                  ClipRect(
                    child: Align(
                      alignment: .topCenter,
                      heightFactor: shown,
                      child: Opacity(
                        opacity: shown,
                        child: Padding(
                          padding: const .only(top: 3),
                          child: Text(
                            e.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _rail(ColorScheme colorScheme, bool isDark) {
    final press = _press.value.clamp(0.0, 1.0);
    final open = _open.value;
    final width = lerpDouble(_kWidth, _kOpenWidth, open)!;
    final tabHeight = _tabHeight;
    final height = _heightFor(tabHeight);
    final corner = Radius.circular(width / 2);
    final selectedFill = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.1,
    );

    // stretch along the motion, squash across it
    final velocity = (_position.velocity / 10).abs();
    final scaleY = _scaleY.value / (1 - (velocity * 0.3).clamp(0.0, 0.06));
    final scaleX = _scaleX.value * (1 - (velocity * 0.15).clamp(0.0, 0.04));

    final pillCenter = Offset(
      width / 2,
      _kPadding + (_position.value + 0.5) * tabHeight,
    );
    final pillRect = Rect.fromCenter(
      center: pillCenter,
      width: _kPillWidth * scaleX,
      height: (tabHeight - 2 * _kPillInset) * scaleY,
    );
    // a capsule, whatever its size
    final pillRadius = Radius.circular(pillRect.shortestSide / 2);
    final pillRRect = RRect.fromRectAndRadius(pillRect, pillRadius);

    Widget tabs({required bool selected}) => Padding(
      padding: const .only(top: _kPadding),
      child: _tabs(
        selected: selected,
        width: width,
        tabHeight: tabHeight,
        open: open,
      ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: .none,
        children: [
          // the rail: the glass's tint, rim and shadow, nothing blurred
          Positioned.fill(child: _GlassSurface(radius: corner)),
          // selected at rest, almost nothing when pressed
          Positioned.fromRect(
            rect: pillRect,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(pillRadius),
                ),
                color: Color.lerp(
                  selectedFill,
                  Colors.black.withValues(alpha: 0.03),
                  press,
                ),
              ),
            ),
          ),
          // the tabs, only outside the pill
          Positioned.fill(
            child: ClipPath(
              clipper: _PillClipper(pillRRect, inverse: true),
              child: IconTheme.merge(
                data: IconThemeData(size: 24, color: colorScheme.onSurface),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: colorScheme.onSurface),
                  child: tabs(selected: false),
                ),
              ),
            ),
          ),
          // the tabs in the accent color, only inside the pill
          Positioned.fill(
            child: ClipPath(
              clipper: _PillClipper(pillRRect),
              child: IconTheme.merge(
                data: IconThemeData(size: 24, color: colorScheme.primary),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: colorScheme.primary),
                  child: tabs(selected: true),
                ),
              ),
            ),
          ),
          // the pill's lens, above the accent tabs so they bend too
          if (press > 0.001)
            Positioned.fromRect(
              rect: pillRect,
              child: CustomPaint(
                foregroundPainter: GlassRimPainter(
                  radius: pillRadius,
                  opacity: press,
                  isDark: isDark,
                  innerShadow: press,
                ),
                child: LiquidGlass(
                  radius: pillRadius.x,
                  refractionHeight: 10 * press,
                  refractionAmount: 14 * press,
                  depthEffect: true,
                  chromaticAberration: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final action = widget.action;
    final header = widget.header;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kEdge + viewPadding.left,
        // level with the floating tabs at the top of the pages
        viewPadding.top + GlassTabBar.margin.top,
        0,
        viewPadding.bottom + _kEdge,
      ),
      child: SizedBox(
        width: _kWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            // a lone page needs no tabs, as the dock hides then too
            final showTabs = _count > 1;
            final railHeight = showTabs ? _heightFor(_kTabHeight) + _kGap : 0;
            // the rail as low as it goes, by the thumb of a hand holding a
            // tablet, with the action's room kept below it
            final railTop = (height - railHeight - _kWidth).clamp(
              0.0,
              height,
            );
            // what is left above it for the header; a phone on its side
            // leaves less than the header's height, so the header then
            // scrolls in the room it has instead of spilling over the tabs
            final headerRoom = railTop - _kGap;
            return Stack(
              clipBehavior: .none,
              children: [
                // too short to show even one of its buttons, it is left out
                if (header.isNotEmpty && headerRoom >= _kWidth)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: headerRoom,
                    child: Align(
                      alignment: const Alignment(0, 2 * _kHeaderAt - 1),
                      child: _GlassBlock(
                        child: ClipRRect(
                          borderRadius: const .all(_kCorner),
                          child: SingleChildScrollView(
                            padding: const .symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: .min,
                              spacing: 6,
                              children: header,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // the action hangs under the tabs
                Positioned(
                  top: railTop,
                  left: 0,
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: _kGap,
                    children: [
                      // laid out at its closed size: swelling, it grows over the
                      // page from its middle instead of pushing the buttons
                      if (showTabs)
                        Listener(
                          behavior: .opaque,
                          onPointerDown: _onPointerDown,
                          onPointerMove: _onPointerMove,
                          onPointerUp: _onPointerEnd,
                          onPointerCancel: _onPointerEnd,
                          child: SizedBox(
                            width: _kWidth,
                            height: _heightFor(_kTabHeight),
                            child: OverflowBox(
                              alignment: .centerLeft,
                              minWidth: 0,
                              minHeight: 0,
                              maxWidth: double.infinity,
                              maxHeight: double.infinity,
                              child: AnimatedBuilder(
                                animation: _animation,
                                builder: (context, _) =>
                                    _rail(colorScheme, isDark),
                              ),
                            ),
                          ),
                        ),
                      AnimatedSwitcher(
                        // long enough for the spring to settle
                        duration: const Duration(milliseconds: 700),
                        switchInCurve: SpringCurve(
                          Springs.bouncy,
                          const Duration(milliseconds: 700),
                        ),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: action == null
                            ? const SizedBox.square(dimension: _kWidth)
                            : _RoundGlassButton(
                                key: ValueKey(action.label),
                                icon: action.icon,
                                label: action.label,
                                onTap: action.onTap,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The rail's look without blurring anything: the page behind it is plain,
/// so the glass's tint over it is a flat color, with the glass's rim and
/// shadow.
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({this.radius = _kCorner, this.child});

  final Radius radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    return CustomPaint(
      painter: GlassShadowPainter(
        radius: radius,
        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
      ),
      foregroundPainter: GlassRimPainter(
        radius: radius,
        opacity: 0.75,
        isDark: isDark,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.all(radius),
        ),
        child: child,
      ),
    );
  }
}

/// a block of the rail's look, as wide as the rail
class _GlassBlock extends StatelessWidget {
  const _GlassBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _kWidth,
    child: _GlassSurface(child: child),
  );
}

/// a round button of the rail's glass, see the dock's search button
class _RoundGlassButton extends StatefulWidget {
  const _RoundGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_RoundGlassButton> createState() => _RoundGlassButtonState();
}

class _RoundGlassButtonState extends State<_RoundGlassButton>
    with SingleTickerProviderStateMixin {
  late final _scale = SpringFollower(
    vsync: this,
    value: 1,
    spring: Springs.tap,
  );

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: .opaque,
        onTapDown: (_) => _scale.animateTo(0.88),
        onTapCancel: () => _scale.animateTo(1),
        onTapUp: (_) => _scale.animateTo(1),
        onTap: widget.onTap,
        child: ListenableBuilder(
          listenable: _scale,
          builder: (context, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: SizedBox.square(
            dimension: _kWidth,
            child: _GlassBlock(
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
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

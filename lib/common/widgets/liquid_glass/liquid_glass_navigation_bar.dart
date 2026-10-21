import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
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
// dock: the bar and the search button side by side
const _kDockGap = 10.0;
const _kDockEdge = 16.0;
// shape changes of the dock overshoot a little
final _dockSpring = _spring(0.75, 320);
// growing back from a circle overshoots more, so the bar pops out
final _expandSpring = _spring(0.55, 260);

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
    this.onSearch,
    this.searchHint,
    this.minimized = false,
  }) : assert(destinations.length >= 2);

  final int selectedIndex;
  final List<LiquidGlassNavigationDestination> destinations;
  final ValueChanged<int>? onDestinationSelected;
  final double bottomPadding;

  /// Shows a round search button next to the bar. Tapping it turns the bar
  /// into a circle and the button into a search field, then calls this.
  final VoidCallback? onSearch;

  /// shown in the search field while it opens, e.g. today's suggested word
  final String? searchHint;

  /// While scrolling, the bar shrinks to a circle with the current tab's
  /// icon instead of hiding; a tap brings it back. Needs [onSearch].
  final bool minimized;

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

  /// 1: the bar is a circle because of scrolling
  late final _mini = _follower(widget.minimized ? 1 : 0, _dockSpring);

  /// 1: the bar is a circle and the search button a field
  late final _search = _follower(0, _dockSpring);

  late final Listenable _animation = Listenable.merge([
    _position,
    _press,
    _scaleX,
    _scaleY,
    _panel,
    _mini,
    _search,
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
    if (widget.minimized != oldWidget.minimized) {
      _mini.animateTo(
        widget.minimized ? 1 : 0,
        spring: widget.minimized ? _dockSpring : _expandSpring,
      );
    }
  }

  bool _searching = false;

  /// the bar reached full width since it last started shrinking
  bool _expanded = true;

  void _openSearch() {
    if (_searching) return;
    _searching = true;
    _search.animateTo(1);
    // let the field grow first, then open the search page over it; once that
    // page covers the dock, put the dock back for when the user returns
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      widget.onSearch?.call();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _searching = false;
        _search.jumpTo(0);
      });
    });
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    _scaleX.dispose();
    _scaleY.dispose();
    _panel.dispose();
    _mini.dispose();
    _search.dispose();
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
    // shrunk to a circle: a tap brings the bar back
    if (_mini.target > 0.5 || _search.target > 0.5) {
      if (!_searching) _mini.animateTo(0, spring: _expandSpring);
      return;
    }
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

  /// The bar with its indicator, at full width.
  Widget _fullBar({
    required ColorScheme colorScheme,
    required bool isDark,
    required Color barTint,
    required Color selectedFill,
    required Widget baseTabs,
  }) {
    const barRadius = Radius.circular(_kBarHeight / 2);
    final press = _press.value.clamp(0.0, 1.0);
    final panelOffset = _panelOffset;

    // stretch along the motion, squash across it
    final velocity = (_position.velocity / 10).abs();
    final scaleX = _scaleX.value / (1 - (velocity * 0.3).clamp(0.0, 0.06));
    final scaleY = _scaleY.value * (1 - (velocity * 0.15).clamp(0.0, 0.04));

    final pillCenter = Offset(
      _kBarPadding + (_position.value + 0.5) * _kTabWidth + panelOffset,
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
                  painter: GlassShadowPainter(
                    radius: barRadius,
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                  ),
                  foregroundPainter: GlassRimPainter(
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
        // What the pill shows, below the accent tabs: a glass slab
        // inset from the bar (56 instead of 64 high), seen only
        // through the pill. Pressed, the pill grows past the slab,
        // and the parts outside it are clear glass over the
        // content, while the slab keeps the tabs readable. This is
        // SukiSU's invisible `tabsBackdrop` row.
        // Its ends line up with the bar's ends (also while the bar
        // grows), so inside the pill there is no second rounded end
        // a few dp inside the bar's outline.
        Positioned.fill(
          child: ClipPath(
            clipper: _PillClipper(pillRRect),
            child: Stack(
              clipBehavior: .none,
              children: [
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: Offset(
                      _width / 2 + panelOffset,
                      _kBarHeight / 2,
                    ),
                    width: _width * barScale,
                    height: _kPillHeight,
                  ),
                  child: LiquidGlass(
                    blurSigma: _kBarBlur,
                    saturation: _kBarSaturation,
                    color: barTint,
                  ),
                ),
              ],
            ),
          ),
        ),
        // selected at rest, almost nothing when pressed
        Positioned.fromRect(
          rect: pillRect,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: Color.lerp(
                selectedFill,
                Colors.black.withValues(alpha: 0.03),
                press,
              ),
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
              foregroundPainter: GlassRimPainter(
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
  }

  /// The bar shrunk to a circle (or on its way there): plain glass, the tabs
  /// fading out and the current tab's icon fading in. No pill layers here:
  /// fading glass with an Opacity would put it in its own render pass, and
  /// the lens shader would sample the wrong place.
  Widget _collapsedBar({
    required ColorScheme colorScheme,
    required bool isDark,
    required Color barTint,
    required Widget baseTabs,
    required double collapse,
  }) {
    const barRadius = Radius.circular(_kBarHeight / 2);
    final tabsOpacity = (1 - collapse * 4).clamp(0.0, 1.0);
    final iconOpacity = (collapse * 3 - 1.4).clamp(0.0, 1.0);
    return Stack(
      clipBehavior: .none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: GlassShadowPainter(
              radius: barRadius,
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
            ),
            foregroundPainter: GlassRimPainter(
              radius: barRadius,
              opacity: 0.75,
              isDark: isDark,
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
        if (tabsOpacity > 0)
          Positioned(
            left: _kBarPadding,
            top: _kBarPadding,
            bottom: _kBarPadding,
            child: Opacity(
              opacity: tabsOpacity,
              // the tabs grow with the bar, so they pop out with it
              child: Transform.scale(
                scale: 1 - 0.15 * collapse,
                alignment: .centerLeft,
                child: baseTabs,
              ),
            ),
          ),
        if (iconOpacity > 0)
          Positioned.fill(
            child: Opacity(
              opacity: iconOpacity,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(size: 26, color: colorScheme.primary),
                  child: widget.destinations[_currentIndex].selectedIcon,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// A round glass button that grows into a search field.
  Widget _searchButton({
    required ColorScheme colorScheme,
    required bool isDark,
    required Color barTint,
  }) {
    const radius = Radius.circular(_kBarHeight / 2);
    final hintOpacity = (_search.value * 2 - 0.6).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: '搜索',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _openSearch,
        child: CustomPaint(
          painter: GlassShadowPainter(
            radius: radius,
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
          ),
          foregroundPainter: GlassRimPainter(
            radius: radius,
            opacity: 0.75,
            isDark: isDark,
          ),
          child: LiquidGlass(
            blurSigma: _kBarBlur,
            refractionHeight: 20,
            refractionAmount: 20,
            saturation: _kBarSaturation,
            color: barTint,
            child: Padding(
              padding: const .symmetric(horizontal: (_kBarHeight - 24) / 2),
              child: Row(
                spacing: 10,
                children: [
                  Icon(Icons.search, size: 24, color: colorScheme.onSurface),
                  if (hintOpacity > 0)
                    Expanded(
                      child: Opacity(
                        opacity: hintOpacity,
                        child: Text(
                          widget.searchHint?.isNotEmpty == true
                              ? widget.searchHint!
                              : '搜索视频、番剧、UP 主',
                          maxLines: 1,
                          softWrap: false,
                          overflow: .fade,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == .dark;
    final viewPadding = MediaQuery.viewPaddingOf(context);
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
    final hasSearch = widget.onSearch != null;

    return Padding(
      padding: .fromLTRB(
        viewPadding.left,
        0,
        viewPadding.right,
        widget.bottomPadding + viewPadding.bottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            width: hasSearch ? w : _width,
            height: _kBarHeight,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                // dock layout: normal -> minimized (scrolling) -> search open
                final mini = hasSearch ? _mini.value : 0.0;
                final search = hasSearch ? _search.value : 0.0;
                final collapse = mini > search ? mini : search;
                const circle = _kBarHeight;
                const edge = _kDockEdge;
                final groupX = hasSearch
                    ? (w - (_width + _kDockGap + circle)) / 2
                    : 0.0;
                final barX = lerpDouble(groupX, edge, collapse)!;
                final barW = lerpDouble(
                  _width,
                  circle,
                  collapse,
                )!.clamp(circle * 0.8, double.infinity);
                final searchX = lerpDouble(
                  lerpDouble(
                    groupX + _width + _kDockGap,
                    w - edge - circle,
                    mini,
                  ),
                  edge + circle + _kDockGap,
                  search,
                )!;
                final searchW = lerpDouble(
                  circle,
                  w - edge * 2 - circle - _kDockGap,
                  search,
                )!.clamp(circle * 0.8, double.infinity);

                // Once the bar is back to full width, keep drawing the full
                // bar until it shrinks again: the expand spring swings a
                // little past full width and back, and switching on every
                // swing would make the pill flicker.
                final shrinking = _mini.target > 0.5 || _search.target > 0.5;
                if (shrinking) {
                  _expanded = false;
                } else if (collapse <= 0.001) {
                  _expanded = true;
                }
                final bar = collapse > 0.001 && !_expanded
                    ? _collapsedBar(
                        colorScheme: colorScheme,
                        isDark: isDark,
                        barTint: barTint,
                        baseTabs: baseTabs,
                        collapse: collapse.clamp(0.0, 1.0),
                      )
                    : _fullBar(
                        colorScheme: colorScheme,
                        isDark: isDark,
                        barTint: barTint,
                        selectedFill: selectedFill,
                        baseTabs: baseTabs,
                      );

                return Stack(
                  clipBehavior: .none,
                  children: [
                    Positioned(
                      left: barX,
                      top: 0,
                      width: barW,
                      height: _kBarHeight,
                      child: Listener(
                        behavior: .opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerEnd,
                        onPointerCancel: _onPointerEnd,
                        child: bar,
                      ),
                    ),
                    if (hasSearch)
                      Positioned(
                        left: searchX,
                        top: 0,
                        width: searchW,
                        height: _kBarHeight,
                        child: _searchButton(
                          colorScheme: colorScheme,
                          isDark: isDark,
                          barTint: barTint,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
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

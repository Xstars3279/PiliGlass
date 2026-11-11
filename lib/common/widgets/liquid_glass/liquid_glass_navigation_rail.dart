// The lens's motion follows prism_ui's NavigationDock, the dock of FlClash
// (GPL-3.0), see lens_motion.dart.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/lens_motion.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass_navigation_bar.dart'
    show LiquidGlassDockAction, LiquidGlassNavigationDestination;
import 'package:flutter/gestures.dart' show VelocityTracker, kTouchSlop;
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

// the top block: the avatar, then buttons, with its padding
const _kAvatar = 34.0;
const _kButton = 48.0;
const _kHeaderSpacing = 6.0;
const _kHeaderPadding = 10.0;
const _kHeaderTwo = 2 * _kHeaderPadding + _kAvatar + _kHeaderSpacing + _kButton;
const _kHeaderFull = _kHeaderTwo + _kHeaderSpacing + _kButton;

/// the avatar alone, on a round glass of its own, at its smallest
const _kAvatarAlone = 42.0;

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
    this.avatar,
    this.messages,
    this.onSearch,
    this.action,
    this.onMessagesShown,
  });

  final List<LiquidGlassNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  /// On the glass block at the top left, one under another: the avatar,
  /// the messages and search. A short window keeps what fits, see
  /// [_LiquidGlassNavigationRailState._header].
  final Widget? avatar;
  final Widget? messages;
  final VoidCallback? onSearch;

  /// the page's own action under the tabs; where it has none and search
  /// has no room above, search takes its place
  final LiquidGlassDockAction? action;

  /// whether the messages have room on the rail, so the page can show
  /// them where they are left out
  final ValueChanged<bool>? onMessagesShown;

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
    _jelly,
  ]);

  late int _currentIndex = widget.selectedIndex;
  int? _pointer;
  double _downY = 0;

  /// the lens stretched along its motion (> 0) or squashed (< 0), see
  /// [LensMotion]
  late final _jelly = _follower(0, LensMotion.jelly);

  /// the finger has moved past the slop: the lens follows it
  bool _dragging = false;

  /// the tab the lens is over while pressed
  int _pressedIndex = 0;

  VelocityTracker? _tracker;

  @override
  void initState() {
    super.initState();
    _position.addListener(_wobble);
  }

  void _wobble() {
    final target = LensMotion.jellyTarget(_position);
    if ((target - _jelly.target).abs() > 1e-4) _jelly.animateTo(target);
  }

  int get _lastIndex => math.max(0, _count - 1);

  /// to a tab, landing with a little bounce
  void _travelTo(int index) {
    _position.animateTo(index.toDouble(), spring: LensMotion.travel);
  }

  int _indexAt(double position) => position.round().clamp(0, _lastIndex);

  void _select(int index) {
    if (index != _pressedIndex) {
      HapticFeedback.selectionClick();
      _pressedIndex = index;
    }
  }

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
      _travelTo(_currentIndex);
    }
  }

  @override
  void dispose() {
    _jelly.dispose();
    _position.dispose();
    _press.dispose();
    _scaleX.dispose();
    _scaleY.dispose();
    _open.dispose();
    super.dispose();
  }

  /// The tab under [y], in tabs, centered: 0 in the middle of the first; past
  /// the end tabs it pulls back like rubber. [y] is in the space of the
  /// closed rail the finger landed on, and the rail swells from its middle,
  /// so it is mapped onto the rail as it is drawn now.
  double _positionAt(double y) {
    final tabHeight = _tabHeight;
    final top = (_heightFor(_kTabHeight) - _heightFor(tabHeight)) / 2;
    return LensMotion.banded(
      (y - top - _kPadding) / tabHeight - 0.5,
      _lastIndex,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downY = event.position.dy;
    _dragging = false;
    _tracker = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.localPosition);
    _press.animateTo(1);
    _scaleX.animateTo(_kPressedScaleX);
    _scaleY.animateTo(_kPressedScaleY);
    _open.animateTo(1, spring: _openSpring);
    _pressedIndex = _indexAt(_positionAt(event.localPosition.dy));
    _travelTo(_pressedIndex);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _tracker?.addPosition(event.timeStamp, event.localPosition);
    if (!_dragging) {
      if ((event.position.dy - _downY).abs() < kTouchSlop) return;
      _dragging = true;
    }
    final position = _positionAt(event.localPosition.dy);
    _position.animateTo(position, spring: LensMotion.drag);
    _select(_indexAt(position));
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final tracker = _tracker;
    _tracker = null;
    final up = event is PointerUpEvent;
    if (up && tracker != null && _dragging) {
      // let go mid-flick, the lens goes on to the next tab
      _select(
        LensMotion.flung(
          target: _position.target,
          velocity: tracker.getVelocity().pixelsPerSecond.dy / _tabHeight,
          pressed: _pressedIndex,
          lastIndex: _lastIndex,
        ),
      );
    }
    final index = up ? _pressedIndex : _currentIndex;
    _dragging = false;
    _travelTo(index);
    _press.animateTo(0);
    _scaleX.animateTo(1);
    _scaleY.animateTo(1);
    _open.animateTo(0, spring: _closeSpring);
    if (!up) return;
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
                _travelTo(i);
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

    // stretched along the motion and thinner across it, or squashed braking
    final jelly = _jelly.value;
    final scaleY = _scaleY.value * (1 + jelly);
    final scaleX =
        _scaleX.value * (1 - jelly * LensMotion.jellyAspect).clamp(0.5, 1.5);

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

  /// the messages were on the rail when last laid out
  bool? _messagesShown;

  void _reportMessages(bool shown) {
    if (shown == _messagesShown) return;
    _messagesShown = shown;
    // found while laying out: the page hears of it once the frame is done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messagesShown == shown) {
        widget.onMessagesShown?.call(shown);
      }
    });
  }

  /// The top block for the [room] above the rail, and whether search goes
  /// below the tabs instead. A tablet has room for all of it. A phone on
  /// its side, or a window made short, keeps what fits: search moves to
  /// the round button under the tabs, where a page has no action of its
  /// own; then the messages go, the page showing them instead (see
  /// [LiquidGlassNavigationRail.onMessagesShown]); the avatar stays as
  /// long as a small round glass of it fits.
  (Widget?, bool) _header(double room) {
    final avatar = widget.avatar;
    final messages = widget.messages;
    final canSearch = widget.onSearch != null;
    Widget button(Widget child) => SizedBox(
      height: _kButton,
      child: Center(child: child),
    );
    Widget block(List<Widget> children) => _GlassBlock(
      child: Padding(
        padding: const .symmetric(vertical: _kHeaderPadding),
        child: Column(
          mainAxisSize: .min,
          spacing: _kHeaderSpacing,
          children: children,
        ),
      ),
    );

    if (room >= _kHeaderFull || (avatar == null && room >= _kHeaderTwo)) {
      _reportMessages(messages != null);
      return (
        block([
          ?avatar,
          if (messages != null) button(messages),
          if (canSearch)
            button(
              IconButton(
                tooltip: '搜索',
                icon: const Icon(Icons.search_rounded, semanticLabel: '搜索'),
                onPressed: widget.onSearch,
              ),
            ),
        ]),
        false,
      );
    }
    if (room >= _kHeaderTwo && messages != null) {
      _reportMessages(true);
      return (block([?avatar, button(messages)]), canSearch);
    }
    _reportMessages(false);
    if (avatar != null && room >= _kAvatarAlone) {
      final size = room.clamp(_kAvatarAlone, _kWidth);
      return (
        SizedBox.square(
          dimension: size,
          child: _GlassSurface(
            radius: Radius.circular(size / 2),
            child: Center(child: avatar),
          ),
        ),
        canSearch,
      );
    }
    return (null, canSearch);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final viewPadding = MediaQuery.viewPaddingOf(context);
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
            // what is left above it for the header
            final headerRoom = railTop - _kGap;
            final (header, searchBelow) = _header(headerRoom);
            final action =
                widget.action ??
                (searchBelow
                    ? LiquidGlassDockAction(
                        icon: Icons.search_rounded,
                        label: '搜索',
                        onTap: widget.onSearch!,
                      )
                    : null);
            return Stack(
              clipBehavior: .none,
              children: [
                if (header != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: headerRoom,
                    child: Align(
                      alignment: const Alignment(0, 2 * _kHeaderAt - 1),
                      child: header,
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

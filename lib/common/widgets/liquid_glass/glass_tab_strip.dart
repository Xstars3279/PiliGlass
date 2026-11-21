import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:material_ui/material_ui.dart';

/// How the strip answers a finger dragged across its labels.
enum GlassTabDrag {
  /// No horizontal drag of the strip's own: a tap selects, and a strip that
  /// does not fit scrolls with the finger.
  none,

  /// The drag moves the pill and the highlight; the index is committed when
  /// the finger is lifted, so the page does not rebuild on every label.
  scrub,

  /// The index is committed as the finger crosses each label, so the page
  /// follows the finger onto the next tab.
  live,
}

/// One label of a [GlassTabStrip]: its text, and what a page needs beside
/// it, e.g. the menu icon of a follow group.
class GlassTabItem {
  const GlassTabItem(
    this.label, {
    this.trailing,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
  });

  final String label;

  /// A fixed-width widget drawn after the label, 18 wide with 4 before it;
  /// measured as part of the tab, so it never squeezes the text.
  final Widget? trailing;

  /// A long press or a right click on the label, e.g. to edit a group.
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  /// Whether the label answers taps; off, it is drawn dimmed.
  final bool enabled;
}

/// A page's tabs on glass, as the home page's: the labels are measured, a
/// pill follows the chosen one frame by frame, and a row too long for the
/// room scrolls to keep the chosen tab in view, in the middle where the row
/// is [centered].
///
/// The [controller] constructor follows a [TabController], so the pill keeps
/// step with the page as it is swiped; the [GlassTabStrip.indexed]
/// constructor takes a plain index for bars that have no pages of their own,
/// e.g. a sort control.
///
/// With [drag] on, a finger dragged across the labels moves the pill itself:
/// the index is committed on release ([GlassTabDrag.scrub]) or as each label
/// is crossed ([GlassTabDrag.live]). The strip then owns the horizontal
/// gesture, the internal scroll view is driven programmatically, and a
/// finger held near either edge scrolls the row. Vertical drags are left to
/// the page, and the mouse is left out, so a desktop scrolls the row as it
/// did before.
class GlassTabStrip extends StatefulWidget {
  /// Controller mode: the pill follows [controller.animation], so a swipe of
  /// the page moves it as well.
  const GlassTabStrip({
    super.key,
    required this.items,
    // ignore: tighten_type_of_initializing_formals
    required this.controller,
    this.onTap,
    this.onSelected,
    this.drag = GlassTabDrag.scrub,
    this.centered = true,
    this.labelPadding = 14,
    this.height = 44,
    this.capsule = false,
    this.refraction = false,
    this.padding = EdgeInsets.zero,
    this.onDragStateChanged,
  }) : index = null,
       assert(controller != null);

  /// Indexed mode: a bar over no pages, e.g. a sort control; [onSelected]
  /// reports the chosen index.
  const GlassTabStrip.indexed({
    super.key,
    required this.items,
    // ignore: tighten_type_of_initializing_formals
    required this.index,
    this.onSelected,
    this.drag = GlassTabDrag.none,
    this.centered = false,
    this.labelPadding = 14,
    this.height = 44,
    this.capsule = false,
    this.refraction = false,
    this.padding = EdgeInsets.zero,
    this.onDragStateChanged,
  }) : controller = null,
       onTap = null,
       assert(index != null);

  final List<GlassTabItem> items;
  final TabController? controller;
  final int? index;

  /// Called after a tap has started moving to the index, as [TabBar.onTap]
  /// is: a page that checks `indexIsChanging` sees the same value it did on
  /// a [TabBar]. A drag commit does not call it.
  final ValueChanged<int>? onTap;

  /// Called with the index a tap or a drag has chosen, before the controller
  /// starts moving. Pass this instead of [onTap] when the bar itself should
  /// answer a tap, as [CenteredGlassTabs] does.
  final ValueChanged<int>? onSelected;

  final GlassTabDrag drag;

  /// Whether a row shorter than its room keeps to what it holds and sits in
  /// the middle; off, the row takes the whole width and starts at the left.
  final bool centered;

  /// The room each label keeps on either side.
  final double labelPadding;

  final double height;

  /// Whether the strip brings its own capsule and press; off for a bar
  /// nested in a page that already has one.
  final bool capsule;
  final bool refraction;

  /// Room around the strip, e.g. the page's margin; the capsule keeps to it.
  final EdgeInsetsGeometry padding;

  /// Called when a drag starts and ends, so the page can hold its own
  /// scrolling while the finger is on the labels.
  final ValueChanged<bool>? onDragStateChanged;

  @override
  State<GlassTabStrip> createState() => _GlassTabStripState();
}

/// The width a trailing widget adds to a tab: the icon and the room before
/// it, matching what [_GlassTabStripState._tab] draws.
const _trailingExtent = 22.0;

class _GlassTabStripState extends State<GlassTabStrip>
    with TickerProviderStateMixin {
  final _scroll = ScrollController();

  /// the width of each label with its padding, measured once per build
  List<double> _widths = const [];

  /// each tab's middle, for turning a finger's x into a fractional index
  List<double> _centers = const [];

  /// the tab last scrolled into the middle, so the frames of a scroll
  /// animation do not send it there again
  int? _centeredIndex;

  /// the fractional index the pill is drawn at while a drag is under way
  double? _dragPosition;
  int? _dragStartIndex;
  int? _committedIndex;
  int? _lastTickIndex;
  double _lastLocalX = 0;
  double _viewportWidth = 0;

  Ticker? _edgeTicker;
  double _edgeSpeed = 0;

  bool get _dragging => _dragPosition != null;

  /// Whether the strip handles the horizontal drag itself. The mouse is left
  /// out of the recognizer, so it keeps the row's own scroll; a wheel turns
  /// the row here, as the row no longer scrolls by itself.
  bool get _ownsDrag => widget.drag != GlassTabDrag.none;

  int get _selectedIndex {
    final count = widget.items.length;
    if (count == 0) return 0;
    final index = widget.controller?.index ?? widget.index ?? 0;
    return index.clamp(0, count - 1);
  }

  /// The index the pill is at, as a fraction while a page is swiped.
  double get _position {
    if (_dragPosition case final position?) return position;
    if (widget.controller case final controller?) {
      return controller.animation?.value ?? controller.index.toDouble();
    }
    return (widget.index ?? 0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onTabChanged);
    // the first tab may already be a scrolled-into-place one
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerChosen();
    });
  }

  @override
  void didUpdateWidget(covariant GlassTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTabChanged);
      widget.controller?.addListener(_onTabChanged);
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.index != widget.index ||
        oldWidget.centered != widget.centered ||
        _itemsDiffer(oldWidget.items, widget.items)) {
      // the labels were replaced or re-measured: put the chosen one back in
      // the middle, now that the new widths are known
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerChosen();
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTabChanged);
    _stopEdgeScroll();
    _scroll.dispose();
    super.dispose();
  }

  static bool _itemsDiffer(List<GlassTabItem> a, List<GlassTabItem> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return true;
    }
    return false;
  }

  void _onTabChanged() {
    final controller = widget.controller;
    if (controller == null || controller.index == _centeredIndex) return;
    // the label's weight and colour follow the new tab
    setState(() {});
    if (!_dragging) _centerChosen();
  }

  /// Puts the chosen tab back in view: in the middle when the row is
  /// [GlassTabStrip.centered], just far enough in from an edge when it is
  /// not, as a scrollable [TabBar] does.
  void _centerChosen() {
    final index = widget.controller?.index ?? widget.index;
    if (index == null) return;
    _centeredIndex = index;
    if (_dragging || !_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    if (index < 0 || index >= _widths.length) return;
    final start = _start(index);
    final end = start + _widths[index];
    final viewport = position.viewportDimension;
    final double target;
    if (widget.centered) {
      target = start + _widths[index] / 2 - viewport / 2;
    } else if (start < position.pixels + 8) {
      target = start - 8;
    } else if (end > position.pixels + viewport - 8) {
      target = end - viewport + 8;
    } else {
      // already on screen, and a left-aligned row stays where the reader
      // put it
      return;
    }
    _scroll.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int index) {
    if (index < 0 || index >= widget.items.length) return;
    if (!widget.items[index].enabled) return;
    feedBack();
    // The chosen index goes out before the controller moves, as
    // CenteredGlassTabs has always reported it.
    widget.onSelected?.call(index);
    final controller = widget.controller;
    if (controller != null &&
        controller.index != index &&
        index < controller.length) {
      controller.animateTo(index);
    }
    // And the tap after, as a TabBar reports it: a page that asks
    // indexIsChanging sees the animation it started.
    widget.onTap?.call(index);
  }

  /// How wide the labels before [index] are together.
  double _start(int index) {
    var start = 0.0;
    for (var i = 0; i < index && i < _widths.length; i++) {
      start += _widths[i];
    }
    return start;
  }

  /// Every label's width, the wider of the two styles, so the pill does not
  /// shift when the weights swap; a trailing icon is part of the tab.
  List<double> _measure(BuildContext context, TextStyle style) {
    final scaler = MediaQuery.textScalerOf(context);
    final widths = <double>[];
    for (final item in widget.items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widths.add(
        // a whole number, so the drawn glyphs never outgrow the tab by a
        // fraction of a pixel and get clipped with an ellipsis
        painter.width.ceilToDouble() +
            widget.labelPadding * 2 +
            (item.trailing == null ? 0 : _trailingExtent),
      );
    }
    return widths;
  }

  List<double> _centersOf(List<double> widths) {
    final centers = <double>[];
    var left = 0.0;
    for (final width in widths) {
      centers.add(left + width / 2);
      left += width;
    }
    return centers;
  }

  /// A label's style at [near]: 1 when its tab is the chosen one, 0 when it
  /// is not. The colour slides with the page; the weight swaps at half way,
  /// as a weight cannot be drawn in between.
  TextStyle _labelStyle(
    double near,
    TextStyle selected,
    TextStyle unselected,
    ColorScheme colorScheme,
    bool enabled,
  ) {
    if (!enabled) {
      return unselected.copyWith(
        color: colorScheme.onSurface.withValues(alpha: 0.38),
      );
    }
    return (near >= 0.5 ? selected : unselected).copyWith(
      color: Color.lerp(
        colorScheme.onSurfaceVariant,
        colorScheme.onSecondaryContainer,
        near,
      ),
    );
  }

  /// The row, with the pill under [position]: a tab index as a fraction, so
  /// that while a page is swiped the pill slides between the two tabs.
  Widget _row(
    ColorScheme colorScheme,
    TextStyle selected,
    TextStyle unselected,
    double position,
  ) {
    final count = _widths.length;
    final at = count == 0 ? 0.0 : position.clamp(0.0, (count - 1).toDouble());
    final from = at.floor();
    final to = count == 0 ? 0 : math.min(from + 1, count - 1);
    final t = at - from;
    final left = count == 0 ? 0.0 : lerpDouble(_start(from), _start(to), t)!;
    final width = count == 0 ? 0.0 : lerpDouble(_widths[from], _widths[to], t)!;
    return SizedBox(
      // the row fills the capsule, so its labels sit on the capsule's own
      // middle line rather than 4 above it
      width: _widths.fold<double>(0, (sum, e) => sum + e),
      height: widget.height,
      child: Stack(
        children: [
          Positioned(
            // 8 in from the capsule and the tab's edge, as the old bar's
            // 4 of capsule padding and 4 of indicator inset came to
            left: left + 8,
            width: math.max(0, width - 16),
            top: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: UiGlass.selected(colorScheme),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _tab(
                  i,
                  (1 - (at - i).abs()).clamp(0.0, 1.0),
                  colorScheme,
                  selected,
                  unselected,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tab(
    int index,
    double near,
    ColorScheme colorScheme,
    TextStyle selected,
    TextStyle unselected,
  ) {
    final item = widget.items[index];
    return Semantics(
      button: true,
      selected: index == _selectedIndex,
      enabled: item.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled ? () => _select(index) : null,
        onLongPress: item.enabled ? item.onLongPress : null,
        onSecondaryTap: item.enabled ? item.onSecondaryTap : null,
        child: SizedBox(
          width: _widths[index],
          // the whole strip is a target, not just the glyphs
          height: widget.height,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.labelPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // the colour follows the page with the pill; the
                      // weight swaps at the half way point
                      style: _labelStyle(
                        near,
                        selected,
                        unselected,
                        colorScheme,
                        item.enabled,
                      ),
                    ),
                  ),
                  if (item.trailing case final trailing?) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: _trailingExtent - 4,
                      height: _trailingExtent - 4,
                      child: Center(child: trailing),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Dragging

  /// Turns a finger's x into the fractional index under it.
  double _positionAt(double localX) {
    if (_centers.isEmpty) return 0;
    final x = localX + (_scroll.hasClients ? _scroll.offset : 0.0);
    if (x <= _centers.first) return 0;
    if (x >= _centers.last) return (_centers.length - 1).toDouble();
    for (var i = 0; i < _centers.length - 1; i++) {
      final a = _centers[i];
      final b = _centers[i + 1];
      if (x >= a && x <= b) {
        return i + (x - a) / (b - a);
      }
    }
    return (_centers.length - 1).toDouble();
  }

  void _onDragStart(DragStartDetails details) {
    if (_widths.isEmpty) return;
    // stop a centring animation under the finger
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.offset);
    _dragPosition = _position.clamp(
      0.0,
      (widget.items.length - 1).toDouble(),
    );
    _dragStartIndex = _selectedIndex;
    _committedIndex = _selectedIndex;
    _lastTickIndex = _dragPosition!.round();
    _lastLocalX = details.localPosition.dx;
    widget.onDragStateChanged?.call(true);
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _lastLocalX = details.localPosition.dx;
    final position = _positionAt(_lastLocalX);
    setState(() {
      _dragPosition = position;
    });
    _commitNearest(position);
    _updateEdgeScroll();
  }

  /// A finger that has crossed into another label: a tick, and in live mode
  /// the page follows it.
  void _commitNearest(double position) {
    final nearest = position.round().clamp(0, widget.items.length - 1);
    if (nearest == _lastTickIndex) return;
    _lastTickIndex = nearest;
    feedBack();
    if (widget.drag == GlassTabDrag.live) {
      _commit(nearest, duration: const Duration(milliseconds: 140));
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final from = _dragPosition;
    if (from == null) return;
    final target = from.round().clamp(0, widget.items.length - 1);
    final before = widget.controller?.index;
    _dragPosition = null;
    _stopEdgeScroll();
    widget.onDragStateChanged?.call(false);
    if (widget.drag == GlassTabDrag.live) {
      if (target != _committedIndex) _commit(target);
    } else if (target != _dragStartIndex) {
      // A drag that comes back to where it started is not a selection, so a
      // page's re-tap scroll-to-top is not fired by a scrub.
      _commit(target);
    }
    _dragStartIndex = null;
    _committedIndex = null;
    setState(() {});
    // a commit that moved the page has centred the row through the
    // controller's listener already
    if (widget.controller?.index == before) _centerChosen();
  }

  void _onDragCancel() {
    if (!_dragging) return;
    _dragPosition = null;
    _dragStartIndex = null;
    _committedIndex = null;
    _stopEdgeScroll();
    widget.onDragStateChanged?.call(false);
    setState(() {});
    _centerChosen();
  }

  /// Commits [index]: the page follows, and the pill animates with it from
  /// the tab it was on.
  void _commit(
    int index, {
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _committedIndex = index;
    widget.onSelected?.call(index);
    final controller = widget.controller;
    if (controller == null ||
        index >= controller.length ||
        controller.index == index) {
      return;
    }
    controller.animateTo(
      index,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  /// While the finger is near either end of a row that does not fit, the row
  /// keeps scrolling that way, so every tab can be reached in one drag.
  void _updateEdgeScroll() {
    if (!_ownsDrag || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) {
      _stopEdgeScroll();
      return;
    }
    const edge = 28.0;
    double speed = 0;
    if (_lastLocalX < edge) {
      speed = -(1 - (_lastLocalX / edge)).clamp(0.0, 1.0) * 6;
    } else if (_lastLocalX > _viewportWidth - edge) {
      speed =
          ((_lastLocalX - (_viewportWidth - edge)) / edge).clamp(0.0, 1.0) * 6;
    }
    if (speed == 0) {
      _stopEdgeScroll();
      return;
    }
    _edgeSpeed = speed;
    _edgeTicker ??= createTicker(_onEdgeTick)..start();
  }

  void _onEdgeTick(Duration _) {
    if (!_dragging || !_scroll.hasClients) {
      _stopEdgeScroll();
      return;
    }
    final metrics = _scroll.position;
    final target = (metrics.pixels + _edgeSpeed).clamp(
      metrics.minScrollExtent,
      metrics.maxScrollExtent,
    );
    if (target == metrics.pixels) return;
    _scroll.jumpTo(target);
    final position = _positionAt(_lastLocalX);
    setState(() {
      _dragPosition = position;
    });
    _commitNearest(position);
  }

  void _stopEdgeScroll() {
    final ticker = _edgeTicker;
    if (ticker == null) return;
    _edgeTicker = null;
    ticker
      ..stop()
      ..dispose();
  }

  /// A wheel or a trackpad still scrolls the row, which no longer takes a
  /// drag of its own.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    final delta = event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
        ? event.scrollDelta.dx
        : event.scrollDelta.dy;
    if (delta == 0) return;
    _scroll.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  Widget _panel(Widget child) {
    final body = SizedBox(height: widget.height, child: child);
    if (!widget.capsule) return body;
    return LiquidPress(
      // a press and a drag must not both move the capsule
      enabled: !_dragging,
      maxGrowth: 8,
      pullPastEdges: true,
      child: GlassCapsule(
        refraction: widget.refraction,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          // the capsule's own round, so a scrolled tab is cut cleanly
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabTheme = theme.tabBarTheme;
    final base =
        tabTheme.labelStyle ??
        theme.textTheme.titleSmall ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final selected = base.copyWith(fontWeight: FontWeight.w600);
    final unselected = tabTheme.unselectedLabelStyle ?? base;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.items.isEmpty) return const SizedBox.shrink();
          _widths = _measure(context, selected);
          _centers = _centersOf(_widths);
          final available = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : _widths.fold<double>(0, (sum, e) => sum + e);
          _viewportWidth = available;
          final total = _widths.fold<double>(0, (sum, e) => sum + e);
          final fits = total <= available;
          final width = widget.centered
              ? math.min(total, available)
              : available;

          // the pill keeps step with the page, frame by frame
          final animation = widget.controller?.animation;
          final body = animation == null
              ? _row(colorScheme, selected, unselected, _position)
              : AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => _row(
                    colorScheme,
                    selected,
                    unselected,
                    _position,
                  ),
                );

          final content = SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: _ownsDrag
                // the strip owns the horizontal gesture; it scrolls the row
                // itself while the finger is near an edge
                ? const NeverScrollableScrollPhysics()
                : fits
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: body,
          );

          final scrolled = fits
              ? content
              // a tab running out of room fades instead of being cut
              : ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [
                      0,
                      ((bounds.width - 24) / bounds.width).clamp(0.0, 1.0),
                      1,
                    ],
                  ).createShader(Offset.zero & bounds.size),
                  child: content,
                );

          Widget panel = _panel(scrolled);
          if (_ownsDrag) {
            panel = GestureDetector(
              behavior: HitTestBehavior.opaque,
              // the mouse keeps the row's own scroll; a finger drags the pill
              supportedDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
              },
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _onDragCancel,
              child: fits
                  ? panel
                  : Listener(
                      onPointerSignal: _onPointerSignal,
                      child: panel,
                    ),
            );
          }

          return Align(
            alignment: widget.centered
                ? Alignment.center
                : Alignment.centerLeft,
            child: SizedBox(width: width, child: panel),
          );
        },
      ),
    );
  }
}

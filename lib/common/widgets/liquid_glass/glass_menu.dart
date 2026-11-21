import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
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
    this.minWidth = 160,
    this.maxWidth = 280,
    this.alignEnd = true,
  });

  final Widget Function(GlassMenuOpen open) targetBuilder;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;
  final double minWidth;
  final double maxWidth;

  /// Whether the menu's trailing edge sits on the control's trailing edge,
  /// as a trailing ⋯ does.
  final bool alignEnd;

  @override
  State<GlassPopupAnchor<T>> createState() => _GlassPopupAnchorState<T>();
}

class _GlassPopupAnchorState<T> extends State<GlassPopupAnchor<T>> {
  final _key = GlobalKey();
  final _hidden = ValueNotifier<bool>(false);
  final _snapshot = ValueNotifier<ui.Image?>(null);
  final _menuKey = GlobalKey<_AnchoredGlassMenuState<T>>();

  _GlassMenuRoute<T>? _route;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _moved = false;

  @override
  void dispose() {
    // The route may still be painting the snapshot; it owns it until it is
    // gone. Leaving the page normally pops the menu as well.
    if (_route == null) {
      _snapshot.value?.dispose();
      _snapshot.dispose();
    }
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

  bool _canOpen() => mounted && _route == null;

  void _handlePress(PointerDownEvent event) {
    _pointer = event.pointer;
    _origin = event.position;
    _moved = false;
    // A navigator cancels the pointers it tracks as it navigates
    // (flutter#4770). Take ours out of its set before pushing the menu, or
    // the push cancels the finger that just opened it and the carry dies.
    _releaseFromNavigator(event.pointer);
    _openMenu();
  }

  void _releaseFromNavigator(int pointer) {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    final listener = navigator?.context.findRenderObject();
    if (listener is RenderPointerListener) {
      listener.onPointerCancel?.call(PointerCancelEvent(pointer: pointer));
    }
  }

  // The menu covers the button, so a press let go where it went down leaves
  // the menu open rather than picking what now lies under it.
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
    }
    if (_moved) {
      _menuKey.currentState?.drag(event.position);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _pointer) {
      return;
    }
    _pointer = null;
    if (_moved) {
      _menuKey.currentState?.release(event.position);
    }
  }

  void _handlePressCancel() {
    if (_pointer == null) {
      return;
    }
    _pointer = null;
    _menuKey.currentState?.cancel();
  }

  void _openMenu() {
    if (!mounted || _route != null) {
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
    final previous = _snapshot.value;
    _snapshot.value = null;
    previous?.dispose();
    _hidden.value = false;

    late final _GlassMenuRoute<T> route;
    route = _GlassMenuRoute<T>(
      barrierLabel: MaterialLocalizations.of(
        context,
      ).modalBarrierDismissLabel,
      builder: (context) => _AnchoredGlassMenu<T>(
        key: _menuKey,
        items: items,
        anchor: anchor,
        overlaySize: overlay.size,
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
        alignEnd: widget.alignEnd,
        animation: route.animation!,
        snapshot: _snapshot,
      ),
    );
    _route = route;
    Navigator.of(context, rootNavigator: true).push<T>(route);

    unawaited(
      route.completed.then<void>((_) {
        if (!mounted) {
          return;
        }
        if (identical(_route, route)) {
          _route = null;
        }
        _hidden.value = false;
        final image = _snapshot.value;
        _snapshot.value = null;
        image?.dispose();
      }),
    );

    // The control repaints its ink as it is pressed; capture it after the
    // frame the route was pushed into, then let the menu's drop carry it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_route, route)) {
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
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: {
        _GlassMenuPressRecognizer:
            GestureRecognizerFactoryWithHandlers<_GlassMenuPressRecognizer>(
              () => _GlassMenuPressRecognizer(debugOwner: this),
              (recognizer) => recognizer
                ..delay = Scrollable.maybeOf(context) == null
                    ? Duration.zero
                    : kPressTimeout
                ..canOpen = _canOpen
                ..onPress = _handlePress
                ..onMove = _handlePointerMove
                ..onUp = _handlePointerUp
                ..onCancel = _handlePressCancel,
            ),
      },
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

/// Opens a popup on its button's pointer down and carries the press on into
/// it, claiming the pointer so the button's tap stands down. In a scroll view
/// it waits [delay] first, so a drag scrolls instead.
class _GlassMenuPressRecognizer extends OneSequenceGestureRecognizer {
  _GlassMenuPressRecognizer({super.debugOwner});

  Duration delay = Duration.zero;
  bool Function()? canOpen;
  ValueSetter<PointerDownEvent>? onPress;
  ValueSetter<PointerMoveEvent>? onMove;
  ValueSetter<PointerUpEvent>? onUp;
  VoidCallback? onCancel;

  PointerDownEvent? _down;
  Timer? _timer;
  bool _pressed = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _down == null &&
      event.buttons == kPrimaryButton &&
      super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!(canOpen?.call() ?? false)) {
      return;
    }
    _down = event;
    _pressed = false;
    startTrackingPointer(event.pointer, event.transform);
    if (delay == Duration.zero) {
      _press();
    } else {
      _timer = Timer(delay, _press);
    }
  }

  void _press() {
    _timer?.cancel();
    _timer = null;
    final down = _down;
    if (down == null || _pressed) {
      return;
    }
    _pressed = true;
    resolve(GestureDisposition.accepted);
    onPress?.call(down);
  }

  @override
  void handleEvent(PointerEvent event) {
    final down = _down;
    if (down == null) {
      return;
    }
    if (event is PointerMoveEvent) {
      if (_pressed) {
        onMove?.call(event);
      } else if ((event.position - down.position).distance >
          computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.rejected);
        _reset(event.pointer);
      }
    } else if (event is PointerUpEvent) {
      _press();
      onUp?.call(event);
      _reset(event.pointer);
    } else if (event is PointerCancelEvent) {
      if (_pressed) {
        onCancel?.call();
      } else {
        resolve(GestureDisposition.rejected);
      }
      _reset(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    final pressed = _pressed;
    _reset(pointer);
    if (pressed) {
      onCancel?.call();
    }
  }

  void _reset(int pointer) {
    _timer?.cancel();
    _timer = null;
    _down = null;
    _pressed = false;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'glass menu press';
}

/// A popup route with the menu's own open and return lengths. [completed],
/// unlike the future returned by `showGeneralDialog`, resolves after the
/// bubble has shrunk back into the button.
class _GlassMenuRoute<T> extends PopupRoute<T> {
  _GlassMenuRoute({required this.builder, required this.barrierLabel});

  final WidgetBuilder builder;
  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 500);

  @override
  bool didPop(T? result) {
    // Flutter shortens a reverse by the remaining fraction; a menu popped
    // mid-open would snap back instead of pouring back.
    final controller = this.controller!;
    controller.reverseDuration =
        reverseTransitionDuration * (1 / math.max(controller.value, 1e-3));
    return super.didPop(result);
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);
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
  final _scroll = ScrollController();
  final _interactive = ValueNotifier<bool>(false);
  late List<GlobalKey> _rowKeys;
  int? _pressedRow;
  bool _carrying = false;
  int? _directPointer;
  double _scrollAtDown = 0;

  @override
  void initState() {
    super.initState();
    _rowKeys = List.generate(widget.items.length, (_) => GlobalKey());
    widget.animation.addListener(_syncInteractive);
    _syncInteractive();
  }

  void _syncInteractive() {
    // The platter clips the menu while it grows and pours back; a finger on
    // it may still highlight a row, but it must not swell the platter.
    final interactive =
        widget.animation.value >= 0.999 &&
        widget.animation.status != AnimationStatus.reverse;
    if (_interactive.value != interactive) {
      _interactive.value = interactive;
    }
  }

  @override
  void didUpdateWidget(_AnchoredGlassMenu<T> old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) {
      _rowKeys = List.generate(widget.items.length, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_syncInteractive);
    _interactive.dispose();
    _scroll.dispose();
    super.dispose();
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

  bool _selectable(int? index) {
    if (index == null) {
      return false;
    }
    final entry = widget.items[index];
    return entry is PopupMenuItem<T> && entry.enabled;
  }

  void _setPressedRow(Offset global) {
    final hit = _rowAt(global);
    final row = _selectable(hit) ? hit : null;
    if (row != _pressedRow) {
      setState(() => _pressedRow = row);
      if (row != null) {
        feedBackSelection();
      }
    }
  }

  // A press that starts inside the menu gets the same follow-the-finger
  // highlight as one carried in from the button. A scroll moves the offset,
  // so only a press that stays put picks the row under the finger.
  void _handleMenuDown(PointerDownEvent event) {
    if (_carrying || _directPointer != null) {
      return;
    }
    _directPointer = event.pointer;
    _scrollAtDown = _scroll.hasClients ? _scroll.offset : 0;
    _setPressedRow(event.position);
  }

  void _handleMenuMove(PointerMoveEvent event) {
    if (event.pointer != _directPointer) {
      return;
    }
    _setPressedRow(event.position);
  }

  void _handleMenuUp(PointerEvent event) {
    if (event.pointer != _directPointer) {
      return;
    }
    _directPointer = null;
    final scrolled = (_scroll.hasClients ? _scroll.offset : 0) - _scrollAtDown;
    final row = _pressedRow;
    if (row != null && scrolled.abs() < 0.5) {
      setState(() => _pressedRow = null);
      _choose(row);
    } else if (row != null) {
      setState(() => _pressedRow = null);
    }
  }

  void drag(Offset global) {
    if (_interactive.value) {
      if (!_carrying) {
        _carrying = true;
        _press.press(global);
      }
      _press.drag(global);
    }
    _setPressedRow(global);
  }

  void release(Offset global) {
    if (_carrying && _interactive.value) {
      _press.release();
    }
    final hit = _rowAt(global);
    final row = _selectable(hit) ? hit : null;
    final carry = _carrying;
    _carrying = false;
    if (_pressedRow != null) {
      setState(() => _pressedRow = null);
    }
    if (carry && row != null) {
      _choose(row);
    }
  }

  void cancel() {
    if (_carrying && _interactive.value) {
      _press.cancel();
    }
    _carrying = false;
    if (_pressedRow != null) {
      setState(() => _pressedRow = null);
    }
  }

  void _choose(int index) {
    final entry = widget.items[index];
    if (entry is! PopupMenuItem<T> || !entry.enabled) {
      return;
    }
    final route = ModalRoute.of(context);
    final action = entry.onTap;
    Navigator.pop<T>(context, entry.value);
    if (action != null) {
      if (route != null) {
        // FlClash runs the action only after the bubble has landed back in
        // its button, so the page does not change under the returning glass.
        unawaited(route.completed.then<void>((_) => action()));
      } else {
        action();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;

    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: widget.anchor,
        alignEnd: widget.alignEnd,
        padding: MediaQuery.paddingOf(context),
        textDirection: Directionality.of(context),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: _interactive,
        builder: (context, interactive, child) => LiquidPress(
          controller: _press,
          enabled: interactive,
          maxGrowth: 16,
          pullPastEdges: true,
          child: child!,
        ),
        child: _GlassMenuMorph(
          anchor: widget.anchor,
          animation: widget.animation,
          snapshot: widget.snapshot,
          panelColor: UiGlass.menu(colorScheme),
          shadow: UiGlass.shadowIn(colorScheme, UiGlass.panelShadow),
          rimOpacity: UiGlass.rim * 0.6,
          edge: UiGlass.edge(colorScheme),
          isDark: isDark,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minWidth,
              maxWidth: widget.maxWidth,
            ),
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(
                    120,
                    widget.overlaySize.height -
                        MediaQuery.paddingOf(context).vertical -
                        32,
                  ),
                ),
                child: Listener(
                  onPointerDown: _handleMenuDown,
                  onPointerMove: _handleMenuMove,
                  onPointerUp: _handleMenuUp,
                  onPointerCancel: _handleMenuUp,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < widget.items.length; i++) _row(i),
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
    );
  }

  Widget _row(int index) {
    final entry = widget.items[index];
    if (entry is PopupMenuDivider) {
      return KeyedSubtree(
        key: _rowKeys[index],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: entry,
        ),
      );
    }
    if (entry is! PopupMenuItem<T>) {
      return KeyedSubtree(key: _rowKeys[index], child: entry);
    }

    final colorScheme = ColorScheme.of(context);
    final theme = Theme.of(context);
    final popupTheme = PopupMenuTheme.of(context);
    final states = <WidgetState>{
      if (!entry.enabled) WidgetState.disabled,
    };
    final style =
        entry.labelTextStyle?.resolve(states) ??
        popupTheme.labelTextStyle?.resolve(states) ??
        theme.textTheme.bodyLarge ??
        UiType.body;
    final color = style.color ?? colorScheme.onSurface;
    final contentColor = entry.enabled ? color : color.withValues(alpha: 0.38);
    final selected = _pressedRow == index && entry.enabled;
    final rowHeight = math.min(44.0, entry.height);
    final padding = entry.padding ?? const EdgeInsets.symmetric(horizontal: 12);

    return KeyedSubtree(
      key: _rowKeys[index],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Semantics(
          button: true,
          enabled: entry.enabled,
          onTap: entry.enabled ? () => _choose(index) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.onSurface.withValues(
                      alpha: colorScheme.brightness == .dark ? 0.16 : 0.08,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: rowHeight,
              child: Padding(
                padding: padding,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DefaultTextStyle(
                    style: style,
                    child: IconTheme.merge(
                      data: IconThemeData(color: contentColor),
                      child: ListTileTheme.merge(
                        contentPadding: EdgeInsets.zero,
                        titleTextStyle: style,
                        child: entry.child ?? const SizedBox.shrink(),
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
}

class _GlassMenuMorph extends SingleChildRenderObjectWidget {
  const _GlassMenuMorph({
    required this.anchor,
    required this.animation,
    required this.snapshot,
    required this.panelColor,
    required this.shadow,
    required this.rimOpacity,
    required this.edge,
    required this.isDark,
    required this.devicePixelRatio,
    super.child,
  });

  final Rect anchor;
  final Animation<double> animation;
  final ValueListenable<ui.Image?> snapshot;
  final Color panelColor;
  final BoxShadow? shadow;
  final double rimOpacity;
  final Color? edge;
  final bool isDark;
  final double devicePixelRatio;

  @override
  RenderGlassMenuMorph createRenderObject(BuildContext context) =>
      RenderGlassMenuMorph(
        anchor: anchor,
        animation: animation,
        snapshot: snapshot,
        panelColor: panelColor,
        shadow: shadow,
        rimOpacity: rimOpacity,
        edge: edge,
        isDark: isDark,
        devicePixelRatio: devicePixelRatio,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMenuMorph renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..animation = animation
      ..snapshot = snapshot
      ..panelColor = panelColor
      ..shadow = shadow
      ..rimOpacity = rimOpacity
      ..edge = edge
      ..isDark = isDark
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _MorphFrame {
  const _MorphFrame({
    required this.platter,
    required this.radius,
    required this.droplet,
    required this.progress,
    required this.settled,
    required this.reveal,
    required this.contentBlur,
    required this.time,
    required this.returning,
    required this.blend,
    required this.under,
  });

  final Rect platter;
  final double radius;
  final Rect? droplet;
  final double progress;
  final double settled;
  final double reveal;
  final double contentBlur;
  final double time;
  final bool returning;
  final double blend;
  final double under;
}

const _openSeconds = 0.45;
const _dismissSeconds = 0.5;
const _dropletBlend = 28.0;
const _dropletShare = 0.25;
const _rimDepth = 8.0;
const _maxContentBlur = 8.0;
const _openContentBlur = 4.0;
const _openBlurBump = 1.9;
const _platterInControl = 0.41;
const _cardRadius = 24.0;

double _riseAndFall(double time, double peak, double sharpness) {
  if (time <= 0) {
    return 0;
  }
  final x = time / peak;
  return math.pow(x, sharpness) * math.exp(sharpness * (1 - x));
}

Size _beyondRound(Rect anchor) => Size(
  math.max(0, anchor.width - anchor.height),
  math.max(0, anchor.height - anchor.width),
);

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

/// Paints the menu itself, not a screenshot of one: a platter grows from a
/// drop on the anchor, a droplet beside it flows into it, the corners square
/// off late, and the content is seen through the platter. On the way back the
/// platter and the droplet are poured back into the anchor.
class RenderGlassMenuMorph extends RenderProxyBox {
  RenderGlassMenuMorph({
    required Rect anchor,
    required Animation<double> animation,
    required ValueListenable<ui.Image?> snapshot,
    required Color panelColor,
    required BoxShadow? shadow,
    required double rimOpacity,
    required Color? edge,
    required bool isDark,
    required double devicePixelRatio,
  }) : _anchor = anchor,
       _animation = animation,
       _snapshot = snapshot,
       _panelColor = panelColor,
       _shadow = shadow,
       _rimOpacity = rimOpacity,
       _edge = edge,
       _isDark = isDark,
       _devicePixelRatio = devicePixelRatio;

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
  static final _return = SpringSimulation(
    SpringDescription.withDampingRatio(mass: 1, stiffness: 165, ratio: 0.8),
    0,
    1,
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
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      _animation.removeStatusListener(_handleStatus);
    }
    _animation = value;
    if (attached) {
      _animation.addListener(markNeedsPaint);
      _animation.addStatusListener(_handleStatus);
    }
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

  Color _panelColor;
  set panelColor(Color value) {
    if (value == _panelColor) return;
    _panelColor = value;
    markNeedsPaint();
  }

  BoxShadow? _shadow;
  set shadow(BoxShadow? value) {
    if (value == _shadow) return;
    _shadow = value;
    markNeedsPaint();
  }

  double _rimOpacity;
  set rimOpacity(double value) {
    if (value == _rimOpacity) return;
    _rimOpacity = value;
    markNeedsPaint();
  }

  Color? _edge;
  set edge(Color? value) {
    if (value == _edge) return;
    _edge = value;
    markNeedsPaint();
  }

  bool _isDark;
  set isDark(bool value) {
    if (value == _isDark) return;
    _isDark = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  double? _reverseFrom;
  _MorphFrame? _reverseOpening;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
    _animation.addStatusListener(_handleStatus);
    _snapshot.addListener(markNeedsPaint);
    _loadShader();
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    _animation.removeStatusListener(_handleStatus);
    _snapshot.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  void _loadShader() {
    if (!LiquidGlassShader.isSupported || _shader != null) {
      return;
    }
    final program = LiquidGlassShader.program;
    if (program != null) {
      _shader = program.fragmentShader();
      return;
    }
    unawaited(
      LiquidGlassShader.ensureLoaded().then<void>((_) {
        if (!attached || _shader != null) {
          return;
        }
        final program = LiquidGlassShader.program;
        if (program != null) {
          _shader = program.fragmentShader();
          markNeedsPaint();
        }
      }),
    );
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) {
      _reverseFrom = _animation.value;
      _reverseOpening = _opening(_reverseFrom! * _openSeconds);
    } else if (status == AnimationStatus.forward) {
      _reverseFrom = null;
      _reverseOpening = null;
    }
    markNeedsPaint();
  }

  Rect _localAnchor() {
    final origin = localToGlobal(Offset.zero);
    return _anchor.shift(-origin);
  }

  _MorphFrame get _settledFrame => _MorphFrame(
    platter: Offset.zero & size,
    radius: _cardRadius,
    droplet: null,
    progress: 1,
    settled: 1,
    reveal: 1,
    contentBlur: 0,
    time: 0,
    returning: false,
    blend: 0,
    under: 0,
  );

  _MorphFrame? _frameFor(double value) {
    if (size.isEmpty) {
      return null;
    }
    if (_reverseFrom != null) {
      return _returning(value);
    }
    if (value >= 1) {
      return _settledFrame;
    }
    return _opening(value * _openSeconds);
  }

  _MorphFrame _opening(double time) {
    final card = Offset.zero & size;
    final local = _localAnchor();
    final image = _snapshot.value;
    final progress = _open.x(time);
    final start = math.max(10.0, _anchor.shortestSide * _platterInControl);
    final scale = ui.lerpDouble(start / size.width, 1, progress)!;
    final height = ui.lerpDouble(card.width, card.height, progress)!;
    final toCard = card.center.dy - local.center.dy;
    final distance = toCard.abs();
    final dip = image == null
        ? 0.0
        : toCard.sign *
              (math.min(1.0, distance / 30) * 23 + 0.124 * distance) *
              _riseAndFall(time, 0.098, 3.3);
    final beyond = _beyondRound(_anchor) * (1 - progress).clamp(0.0, 1.0);
    final platter = Rect.fromCenter(
      center:
          Offset.lerp(local.center, card.center, progress)! + Offset(0, dip),
      width: math.max(0.0, card.width * scale + beyond.width),
      height: math.max(0.0, height * scale + beyond.height),
    );
    final corners =
        _cardRadius +
        card.width * 0.48 * _corners.x(math.max(0.0, time - 0.07));
    final radius = math.max(
      0.0,
      math.min(height / 2, corners) * scale,
    );
    Rect? droplet;
    if (image != null) {
      final extent = Size(
        _anchor.width * ui.lerpDouble(1, _dropletShare, progress)!,
        _anchor.height * ui.lerpDouble(1, _dropletShare, progress)!,
      );
      final inner = card.deflate(
        _anchor.longestSide * _dropletShare / 2 + _dropletBlend + _rimDepth,
      );
      final sunk = Offset.lerp(local.center, card.center, _dropletShare)!;
      final target = inner.isEmpty
          ? card.center
          : Offset(
              sunk.dx.clamp(inner.left, inner.right),
              sunk.dy.clamp(inner.top, inner.bottom),
            );
      droplet = Rect.fromCenter(
        center: Offset.lerp(local.center, target, progress)!,
        width: extent.width,
        height: extent.height,
      );
    }
    final settled = progress.clamp(0.0, 1.0);
    final under = math.min(1.0, settled / 0.25);
    final blur = math.sqrt(
      math.pow(_openContentBlur * (1 - settled), 2) +
          math.pow(
            _openBlurBump * _riseAndFall(time, 0.069, 2.1),
            2,
          ),
    );
    return _MorphFrame(
      platter: platter,
      radius: radius,
      droplet: droplet,
      progress: progress,
      settled: settled,
      reveal: settled,
      contentBlur: blur,
      time: time,
      returning: false,
      blend: droplet == null ? 0 : _dropletBlend,
      under: under,
    );
  }

  _MorphFrame _returning(double value) {
    final fromValue = _reverseFrom ?? 1.0;
    final t = fromValue <= 0
        ? 1.0
        : ((fromValue - value) / fromValue).clamp(0.0, 1.0);
    final time = t * _dismissSeconds;
    final local = _localAnchor();
    final opening = _reverseOpening ?? _settledFrame;
    final from = opening.platter;
    final fromRadius = opening.radius;
    final fromDroplet =
        opening.droplet ??
        Rect.fromCenter(
          center: Offset.lerp(local.center, from.center, _dropletShare)!,
          width: _anchor.width * _dropletShare,
          height: _anchor.height * _dropletShare,
        );
    final ringing =
        1 - Curves.easeIn.transform(((time - 0.4) / 0.1).clamp(0.0, 1.0));
    final progress = 1 + (_return.x(time) - 1) * ringing;
    final toCard = from.center.dy - local.center.dy;
    final away = toCard.sign;
    final dip =
        math.min(0.21 * toCard.abs(), 22.0) * _riseAndFall(time, 0.072, 2.4);
    final lift =
        math.min(0.25 * toCard.abs(), 19.0) * _riseAndFall(time, 0.176, 4.9);
    final start = math.max(10.0, _anchor.shortestSide * _platterInControl);
    final scale = ui.lerpDouble(
      1,
      start / math.max(from.width, from.height),
      progress,
    )!;
    final beyond = _beyondRound(_anchor) * progress.clamp(0.0, 1.0);
    final platter = Rect.fromCenter(
      center:
          Offset.lerp(from.center, local.center, progress)! +
          Offset(0, away * dip * ringing),
      width: math.max(0.0, from.width * scale + beyond.width),
      height: math.max(
        0.0,
        ui.lerpDouble(from.height, from.width, progress)! * scale +
            beyond.height,
      ),
    );
    final radius = math.max(
      0.0,
      ui.lerpDouble(fromRadius, from.width / 2, progress)! * scale,
    );
    final droplet = Rect.fromCenter(
      center:
          Offset.lerp(fromDroplet.center, local.center, progress)! -
          Offset(0, away * lift * ringing),
      width: ui.lerpDouble(fromDroplet.width, _anchor.width, progress)!,
      height: ui.lerpDouble(fromDroplet.height, _anchor.height, progress)!,
    );
    final absorbed = const Interval(
      0.6,
      0.9,
      curve: Curves.easeInOut,
    ).transform((time / _dismissSeconds).clamp(0.0, 1.0));
    final blend = _dropletBlend * math.min(1.0, time / 0.05) * (1 - absorbed);
    final reveal =
        opening.progress.clamp(0.0, 1.0) *
        (1 - Curves.easeOut.transform((time / 0.1).clamp(0.0, 1.0)));
    return _MorphFrame(
      platter: platter,
      radius: radius,
      droplet: opening.droplet == null ? null : droplet,
      progress: progress,
      settled: (1 - progress).clamp(0.0, 1.0),
      reveal: reveal,
      contentBlur: _maxContentBlur * (1 - reveal),
      time: time,
      returning: true,
      blend: blend,
      under: 0,
    );
  }

  Path _roundedPath(Rect rect, double radius) {
    final round = math.min(radius, rect.shortestSide / 2);
    return RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(round)),
    ).getOuterPath(rect);
  }

  Path _outline(_MorphFrame frame) {
    final platter = frame.platter;
    final outline = _roundedPath(platter, frame.radius);
    final droplet = frame.droplet;
    if (droplet == null || droplet.isEmpty) {
      return outline;
    }
    final pillRadius = droplet.shortestSide / 2;
    final pill = _roundedPath(droplet, pillRadius);
    if (frame.blend <= 0.01 || platter.overlaps(droplet)) {
      return Path.combine(PathOperation.union, outline, pill);
    }
    final delta = droplet.center - platter.center;
    final distance = delta.distance;
    if (distance < 1) {
      return Path.combine(PathOperation.union, outline, pill);
    }
    final dir = delta / distance;
    final normal = Offset(-dir.dy, dir.dx);
    final neck =
        math.min(platter.shortestSide, droplet.shortestSide) *
        0.24 *
        (frame.blend / _dropletBlend).clamp(0.0, 1.0);
    final a1 =
        platter.center + normal * neck + dir * (platter.shortestSide * 0.15);
    final a2 =
        platter.center - normal * neck + dir * (platter.shortestSide * 0.15);
    final b1 =
        droplet.center + normal * neck - dir * (droplet.shortestSide * 0.25);
    final b2 =
        droplet.center - normal * neck - dir * (droplet.shortestSide * 0.25);
    final bridge = Path()
      ..moveTo(a1.dx, a1.dy)
      ..cubicTo(
        a1.dx + dir.dx * distance * 0.35,
        a1.dy + dir.dy * distance * 0.35,
        b1.dx - dir.dx * distance * 0.35,
        b1.dy - dir.dy * distance * 0.35,
        b1.dx,
        b1.dy,
      )
      ..lineTo(b2.dx, b2.dy)
      ..cubicTo(
        b2.dx - dir.dx * distance * 0.35,
        b2.dy - dir.dy * distance * 0.35,
        a2.dx + dir.dx * distance * 0.35,
        a2.dy + dir.dy * distance * 0.35,
        a2.dx,
        a2.dy,
      )
      ..close();
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, outline, pill),
      bridge,
    );
  }

  ui.ImageFilter? _filterFor(Rect platter, double radius) {
    if (!UiGlass.clear || platter.width <= 0) {
      return null;
    }
    ui.ImageFilter? blur;
    if (UiGlass.panelBlur > 0) {
      blur = ui.ImageFilter.blur(
        sigmaX: UiGlass.panelBlur,
        sigmaY: UiGlass.panelBlur,
        tileMode: TileMode.clamp,
      );
    }
    if (UiGlass.liquid && _shader != null) {
      final global = MatrixUtils.transformRect(
        getTransformTo(null),
        platter,
      );
      final dpr = _devicePixelRatio;
      final scale = global.width / platter.width * dpr;
      final shader = _shader!
        ..setFloat(0, 0) // uSize, set by the engine
        ..setFloat(1, 0)
        ..setFloat(2, global.left * dpr)
        ..setFloat(3, global.top * dpr)
        ..setFloat(4, global.width * dpr)
        ..setFloat(5, global.height * dpr)
        ..setFloat(6, radius * scale)
        ..setFloat(7, radius * scale)
        ..setFloat(8, radius * scale)
        ..setFloat(9, radius * scale)
        ..setFloat(10, UiGlass.panelRefractionHeight * scale)
        ..setFloat(11, UiGlass.panelRefractionAmount * scale)
        ..setFloat(12, 0)
        ..setFloat(13, 0)
        ..setFloat(14, UiGlass.saturation);
      final lens = ui.ImageFilter.shader(shader);
      return blur == null
          ? lens
          : ui.ImageFilter.compose(outer: lens, inner: blur);
    }
    if (UiGlass.saturation == 1) {
      return blur;
    }
    final vibrancy = ui.ColorFilter.matrix(
      _saturationMatrix(UiGlass.saturation),
    );
    return blur == null
        ? vibrancy
        : ui.ImageFilter.compose(outer: vibrancy, inner: blur);
  }

  void _paintShadow(
    Canvas canvas,
    Path path,
    Offset offset,
    _MorphFrame frame,
  ) {
    final shadow = _shadow;
    if (shadow == null || shadow.color.a == 0 || frame.settled <= 0) {
      return;
    }
    final bounds = path.getBounds();
    final reach = shadow.blurSigma * 2 + shadow.offset.distance + 2;
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds.inflate(reach))
      ..addPath(path, Offset.zero);
    canvas
      ..save()
      ..clipPath(outside.shift(offset))
      ..drawPath(
        path.shift(offset + shadow.offset),
        Paint()
          ..color = shadow.color.withValues(
            alpha: shadow.color.a * frame.settled,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shadow.blurSigma,
          ),
      )
      ..restore();
  }

  void _paintGlass(
    PaintingContext context,
    Offset offset,
    _MorphFrame frame,
    Path path,
  ) {
    final filter = _filterFor(frame.platter, frame.radius);
    void paintTint(PaintingContext context, Offset offset) {
      context.canvas.drawPath(
        path.shift(offset),
        Paint()..color = _panelColor,
      );
    }

    context.pushClipPath(
      needsCompositing,
      offset,
      path.getBounds(),
      path,
      (context, offset) {
        if (filter == null) {
          paintTint(context, offset);
          return;
        }
        context.pushLayer(
          BackdropFilterLayer(filter: filter),
          paintTint,
          offset,
        );
      },
    );
  }

  void _paintRim(Canvas canvas, Path path, _MorphFrame frame) {
    final opacity = _rimOpacity * frame.settled;
    final edge = _edge;
    if (opacity > 0) {
      final bounds = path.getBounds();
      final peak = (_isDark ? 0.35 : 0.6) * opacity;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: peak),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: peak * 0.5),
            ],
            stops: const [0, 0.35, 0.65, 1],
          ).createShader(bounds),
      );
    }
    if (edge != null && edge.a > 0 && frame.settled > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = edge.withValues(alpha: edge.a * frame.settled),
      );
    }
  }

  void _paintSource(
    Canvas canvas,
    ui.Image image,
    Rect droplet,
    double opacity, {
    double blur = 0,
  }) {
    if (opacity <= 0) {
      return;
    }
    final pill = _roundedPath(droplet, droplet.shortestSide / 2);
    canvas
      ..save()
      ..clipPath(pill)
      ..drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        droplet,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, opacity)
          ..filterQuality = FilterQuality.medium
          ..imageFilter = blur > 0
              ? ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
              : null,
      )
      ..restore();
  }

  Matrix4 _contentTransform(Rect platter) {
    final scale = platter.width / size.width;
    return Matrix4.translationValues(
        platter.center.dx,
        platter.center.dy,
        0,
      )
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }

  void _paintContent(
    PaintingContext context,
    Offset offset,
    _MorphFrame frame,
  ) {
    final child = this.child;
    if (child == null || frame.reveal <= 0.001) {
      return;
    }
    final clip = _roundedPath(frame.platter, frame.radius);
    context.pushClipPath(
      needsCompositing,
      offset,
      frame.platter,
      clip,
      (context, offset) {
        final matrix = _contentTransform(frame.platter);
        void paintChild(PaintingContext context, Offset offset) =>
            context.pushTransform(
              needsCompositing,
              offset,
              matrix,
              (context, offset) => context.paintChild(child, offset),
            );
        void paintBlurred(PaintingContext context, Offset offset) {
          if (frame.contentBlur <= 0.1) {
            paintChild(context, offset);
            return;
          }
          context.pushLayer(
            ImageFilterLayer(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: frame.contentBlur,
                sigmaY: frame.contentBlur,
              ),
            ),
            paintChild,
            offset,
          );
        }

        if (frame.reveal >= 0.999) {
          paintBlurred(context, offset);
        } else {
          context.pushOpacity(
            offset,
            (frame.reveal * 255).round(),
            paintBlurred,
          );
        }
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      return;
    }
    // The first frame paints the button and hands its snapshot to the drop.
    // Wait for it, so the drop starts as the button rather than as a plain
    // white disc; the anchor stays visible until the capture hides it.
    if (_snapshot.value == null && _reverseFrom == null) {
      return;
    }
    final frame = _frameFor(_animation.value);
    if (frame == null) {
      context.paintChild(child, offset);
      return;
    }
    final image = _snapshot.value;
    final outline = _outline(frame);
    _paintShadow(context.canvas, outline, offset, frame);
    _paintGlass(context, offset, frame, outline);

    final droplet = frame.droplet;
    if (image != null && droplet != null) {
      final double opacity;
      final double blur;
      if (frame.returning) {
        final t = (frame.time / _dismissSeconds).clamp(0.0, 1.0);
        opacity = 0.2 + 0.8 * Curves.easeOutCubic.transform(t);
        blur = 0;
      } else {
        opacity = 1 - frame.under;
        blur = _openContentBlur * frame.under;
      }
      _paintSource(
        context.canvas,
        image,
        droplet.shift(offset),
        opacity,
        blur: blur,
      );
    }

    _paintContent(context, offset, frame);
    if (!frame.returning) {
      // FlClash rims the platter, not the goo neck, and has no rim at all
      // while the glass pours back into the button.
      _paintRim(
        context.canvas,
        _roundedPath(frame.platter, frame.radius).shift(offset),
        frame,
      );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final frame = _frameFor(_animation.value);
    if (frame == null || size.isEmpty) {
      return;
    }
    final scale = frame.platter.width / size.width;
    transform
      ..translateByDouble(
        frame.platter.center.dx,
        frame.platter.center.dy,
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width / 2, -size.height / 2, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final frame = _frameFor(_animation.value);
    if (frame != null && !frame.platter.contains(position)) {
      return false;
    }
    return super.hitTest(result, position: position);
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

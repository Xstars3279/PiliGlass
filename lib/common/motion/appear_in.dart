import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:material_ui/material_ui.dart';

/// Rises and fades in, staggered by [index], when it is built shortly after
/// [since] (the moment the list's data arrived), and again when a refresh
/// brings a new list.
///
/// Items built later, e.g. scrolled into view, appear at once: replaying the
/// animation every time a card comes back on screen would get tiring.
class AppearIn extends StatefulWidget {
  const AppearIn({
    super.key,
    required this.index,
    required this.since,
    required this.child,
  });

  final int index;
  final DateTime? since;
  final Widget child;

  /// how long after the data arrives new items still animate in
  static const _window = Duration(milliseconds: 700);

  @override
  State<AppearIn> createState() => _AppearInState();
}

class _AppearInState extends State<AppearIn>
    with SingleTickerProviderStateMixin, _Rise<AppearIn> {
  @override
  void initState() {
    super.initState();
    if (!_play()) _controller.value = 1;
  }

  /// A refresh brings a new list into the same cards: they rise in again,
  /// as on the first load.
  @override
  void didUpdateWidget(AppearIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.since != oldWidget.since) _play();
  }

  /// Starts the rise if the list arrived just now; false if it did not.
  bool _play() {
    final since = widget.since;
    if (since == null || DateTime.now().difference(since) >= AppearIn._window) {
      return false;
    }
    _rise(widget.index);
    return true;
  }

  // the cards inside rise with this one, not on their own as well
  @override
  Widget build(BuildContext context) =>
      _RiseScope(child: _buildRise(context, widget.child));
}

/// Rises in like [AppearIn] without being told when the list's data came:
/// when it is first built while the list it is in is still, i.e. the list
/// just loaded, refreshed into new cards, or its tab was opened. Built while
/// the list scrolls, it was scrolled into view, and appears at once.
///
/// Put into the common cards, so every list of them rises in.
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child});

  final Widget child;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn>
    with SingleTickerProviderStateMixin, _Rise<RiseIn> {
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final position = Scrollable.maybeOf(context)?.position;
    final still = position != null && !position.isScrollingNotifier.value;
    if (!still || _RiseScope.of(context)) {
      _controller.value = 1;
      return;
    }
    // staggered by where the card lands on screen, top first
    _controller.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final top = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero).dy
          : 0.0;
      final screen = MediaQuery.sizeOf(context).height;
      _rise((top / screen * 8).floor().clamp(0, 8));
    });
  }

  @override
  Widget build(BuildContext context) => _buildRise(context, widget.child);
}

/// The rise both share: up from a little below, fading in, on a spring.
mixin _Rise<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  static const _stagger = Duration(milliseconds: 40);
  static const _maxStaggered = 8;

  late final _controller = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );
  Timer? _timer;

  void _rise(int index) {
    _timer?.cancel();
    _controller.value = 0;
    _timer = Timer(_stagger * math.min(index, _maxStaggered), () {
      if (mounted) _controller.springTo(1, Springs.bouncy);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRise(BuildContext context, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: _controller,
      // the same wrappers at rest: dropping them when done would remount the
      // card (and reload its image)
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          // not from 0: the skeleton is gone by now, and a fully blank
          // first frame would flash
          opacity: 0.25 + 0.75 * t.clamp(0.0, 1.0),
          child: Transform.translate(
            // past 1 on the spring's overshoot: the card bobs up and settles
            offset: Offset(0, (1 - t) * 28),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// below an [AppearIn], which already animates the cards
class _RiseScope extends InheritedWidget {
  const _RiseScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_RiseScope>() != null;

  @override
  bool updateShouldNotify(_RiseScope oldWidget) => false;
}

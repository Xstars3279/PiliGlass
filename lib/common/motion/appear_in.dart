import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Rises and fades in, staggered by [index], when it is built shortly after
/// [since] (the moment the list's data arrived).
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
  static const _stagger = Duration(milliseconds: 40);
  static const _maxStaggered = 8;

  @override
  State<AppearIn> createState() => _AppearInState();
}

class _AppearInState extends State<AppearIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

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
    _controller.value = 0;
    Future.delayed(
      AppearIn._stagger * math.min(widget.index, AppearIn._maxStaggered),
      () {
        if (mounted) _controller.forward();
      },
    );
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      // the same wrappers at rest: dropping them when done would remount the
      // card (and reload its image)
      builder: (context, child) {
        final t = _controller.value;
        return Opacity(
          // not from 0: the skeleton is gone by now, and a fully blank
          // first frame would flash
          opacity: 0.25 + 0.75 * Curves.easeOut.transform(t),
          child: Transform.translate(
            offset: Offset(0, (1 - Curves.easeOutBack.transform(t)) * 28),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

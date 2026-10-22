import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Shrinks the dock only after the content has scrolled a stretch towards
/// the end, and grows it back only after a stretch back, so a short nudge
/// in either direction does not toggle it. Back at the top it always grows.
class DockScrollWatcher extends StatefulWidget {
  const DockScrollWatcher({
    super.key,
    required this.minimized,
    required this.child,
  });

  final RxBool minimized;
  final Widget child;

  @override
  State<DockScrollWatcher> createState() => _DockScrollWatcherState();
}

class _DockScrollWatcherState extends State<DockScrollWatcher> {
  static const _toMinimize = 120.0;
  static const _toRestore = 100.0;

  /// the distance scrolled in one direction: + towards the end, - back
  double _run = 0;

  bool _onScroll(ScrollUpdateNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != .vertical) return false;
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (metrics.pixels <= metrics.minScrollExtent) {
      _run = 0;
      widget.minimized.value = false;
      return false;
    }
    // a change of direction starts a new stretch
    if ((delta > 0) != (_run > 0)) _run = 0;
    _run += delta;
    if (_run >= _toMinimize) {
      widget.minimized.value = true;
    } else if (_run <= -_toRestore) {
      widget.minimized.value = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class PublishRoute<T> extends PopupRoute<T> {
  PublishRoute({
    required this.pageBuilder,
    this.barrierDismissible = true,
    this.barrierLabel,
    this.barrierColor = const Color(0x80000000),
    Duration? transitionDuration,
    this._transitionBuilder,
    super.settings,
  }) : transitionDuration =
           transitionDuration ??
           (PlatformUtils.isDesktop
               ? const Duration(milliseconds: 400)
               : const Duration(milliseconds: 500));

  final RoutePageBuilder pageBuilder;

  /// Set right before pushing a page that grows out of a rect on the screen
  /// by itself, e.g. the reply panel out of the glass input bar; the route
  /// takes it and leaves the transition to the page.
  static Rect? pendingMorph;

  /// see [pendingMorph]
  final Rect? morphFrom = _takePendingMorph();

  static Rect? _takePendingMorph() {
    final rect = pendingMorph;
    pendingMorph = null;
    return rect;
  }

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  final Color barrierColor;

  @override
  final Duration transitionDuration;

  final RouteTransitionsBuilder? _transitionBuilder;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: pageBuilder(context, animation, secondaryAnimation),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_transitionBuilder != null) {
      return _transitionBuilder(context, animation, secondaryAnimation, child);
    }
    if (morphFrom != null) return child;
    return SlideTransition(
      // the redesign eases the panel in and out instead of a constant speed
      position: (Revamp.enabled ? _eased : animation).drive(
        Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ),
      ),
      child: child,
    );
  }

  late final Animation<double> _eased = CurvedAnimation(
    parent: animation!,
    curve: Curves.easeOutQuart,
    reverseCurve: Curves.easeInCubic,
  );
}

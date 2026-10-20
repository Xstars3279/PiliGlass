import 'package:material_ui/material_ui.dart';

/// The M3 default (80) leaves a lot of empty space above and below the
/// destinations; 64 matches the bar of KernelSU/SukiSU.
const kCompactNavigationBarHeight = 64.0;

/// Bigger icons and labels for the compact [NavigationBar].
///
/// Setting `iconTheme`/`labelTextStyle` replaces the M3 defaults entirely,
/// so the default colors are restated here.
class CompactNavigationBarTheme extends StatelessWidget {
  const CompactNavigationBarTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return NavigationBarTheme(
      data: NavigationBarTheme.of(context).copyWith(
        height: kCompactNavigationBarHeight,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => theme.textTheme.labelMedium!.copyWith(
            fontSize: 13,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// The background color a docked (non floating) bottom bar paints, used to
/// fill the gap when the bar springs above its resting position.
Color dockedBottomBarColor(BuildContext context, {required bool md3}) {
  final theme = Theme.of(context);
  if (md3) {
    final navTheme = NavigationBarTheme.of(context);
    return ElevationOverlay.applySurfaceTint(
      navTheme.backgroundColor ?? theme.colorScheme.surfaceContainer,
      navTheme.surfaceTintColor,
      navTheme.elevation ?? 3.0,
    );
  }
  return theme.bottomNavigationBarTheme.backgroundColor ?? theme.canvasColor;
}

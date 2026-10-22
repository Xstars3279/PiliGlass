import 'package:PiliPlus/common/motion/springs.dart';
import 'package:material_ui/material_ui.dart';

/// The redesign's look for the standard components, so the pages that are
/// not redesigned one by one (most of them) still speak the same language:
/// tabs on a raised pill, rounded menus, sheets and dialogs, pill buttons.
abstract final class RevampTheme {
  static ThemeData apply(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final shadow = Colors.black.withValues(alpha: isDark ? 0.4 : 0.12);
    // modal sheets come up on the comment sheet's spring
    // (tool/patches/material-ui_glass_sheet.patch)
    PiliSheetMotion.enterDuration = const Duration(milliseconds: 520);
    PiliSheetMotion.curve = SpringCurve(
      Springs.sheet,
      PiliSheetMotion.enterDuration!,
    );
    PiliSheetMotion.reverseCurve = Curves.easeInCubic;
    // the light catching the edge of the glass surfaces
    final rim = BorderSide(
      color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.6),
      width: 0.8,
    );

    return theme.copyWith(
      tabBarTheme: TabBarThemeData(
        indicator: PillTabIndicator(
          color: colorScheme.surfaceContainerHighest,
          shadow: shadow,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.titleSmall!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: textTheme.titleSmall!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        // the pill is the feedback; a rectangular ripple would cut across it
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      // translucent, so the patched menu blurs what is behind it like the
      // dock's glass (tool/patches/material-ui_glass_menu.patch)
      popupMenuTheme: theme.popupMenuTheme.copyWith(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.72),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: rim,
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: textTheme.labelLarge!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      // translucent like the menus, and blurred by the same kind of patch
      // (tool/patches/material-ui_glass_sheet.patch)
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.85,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          side: rim,
        ),
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerLow.withValues(
          alpha: 0.82,
        ),
        modalBackgroundColor: colorScheme.surfaceContainerLow.withValues(
          alpha: 0.82,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: rim,
        ),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A raised pill behind the selected tab, inset from the tab's edges.
///
/// TabBarThemeData has no indicator padding, and a pill filling the whole
/// tab height looks heavy, so the inset is part of the decoration.
class PillTabIndicator extends Decoration {
  const PillTabIndicator({
    required this.color,
    required this.shadow,
    this.insets = const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
  });

  final Color color;
  final Color shadow;
  final EdgeInsets insets;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _PillPainter(this);
}

class _PillPainter extends BoxPainter {
  _PillPainter(this.decoration);

  final PillTabIndicator decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = decoration.insets.deflateRect(offset & size);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
    canvas
      ..drawRRect(
        rrect.shift(const Offset(0, 1.5)),
        Paint()
          ..color = decoration.shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawRRect(rrect, Paint()..color = decoration.color);
  }
}

import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The redesign's look for the standard components, so the pages that are
/// not redesigned one by one (most of them) still speak the same language:
/// UiType's five sizes, tabs on a tonal pill, white menus, sheets and
/// dialogs with UiRadius's corners, pill buttons.
abstract final class RevampTheme {
  static ThemeData apply(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    // modal sheets come up on the comment sheet's spring
    // (tool/patches/material-ui_glass_sheet.patch)
    if (GlassFeatures.sheetSpring) {
      PiliSheetMotion.enterDuration = const Duration(milliseconds: 520);
      PiliSheetMotion.curve = SpringCurve(
        Springs.sheet,
        PiliSheetMotion.enterDuration!,
      );
      PiliSheetMotion.reverseCurve = Curves.easeInCubic;
    }
    // menus, sheets and dialogs are panels (UiGlass, G2): white, solid at
    // 无, at 标准 and 极致 just translucent enough for the patches to blur
    // what is behind them; a shadow in the light, an outline in the dark
    final panel = UiGlass.panel(colorScheme);
    final rim = UiGlass.side(colorScheme);
    // a Material's shadow at 6 comes near the panel's, see UiGlass.panelShadow
    final shadow = isDark ? Colors.transparent : Colors.black;

    // every size snapped to one of UiType's five; bodyMedium, the default
    // of a Text and the size of a video card's title, stays as it is
    TextStyle? snap(TextStyle? style, TextStyle to) => style?.merge(to);
    final type = textTheme.copyWith(
      headlineMedium: snap(textTheme.headlineMedium, UiType.largeTitle),
      headlineSmall: snap(textTheme.headlineSmall, UiType.largeTitle),
      titleLarge: snap(textTheme.titleLarge, UiType.title),
      titleMedium: snap(textTheme.titleMedium, UiType.bodyStrong),
      titleSmall: snap(textTheme.titleSmall, UiType.bodyStrong),
      bodyLarge: snap(textTheme.bodyLarge, UiType.body),
      bodySmall: snap(textTheme.bodySmall, UiType.caption),
      labelLarge: snap(textTheme.labelLarge, UiType.bodyStrong),
      labelMedium: snap(textTheme.labelMedium, UiType.caption),
      labelSmall: snap(textTheme.labelSmall, UiType.label),
    );

    return theme.copyWith(
      textTheme: type,
      tabBarTheme: TabBarThemeData(
        indicator: PillTabIndicator(color: colorScheme.secondaryContainer),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        labelColor: colorScheme.onSecondaryContainer,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: type.titleSmall!.merge(
          UiType.bodyStrong.copyWith(fontWeight: UiType.title.fontWeight),
        ),
        unselectedLabelStyle: type.titleSmall!.merge(UiType.bodyStrong),
        // the pill is the feedback; a rectangular ripple would cut across it
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      // translucent, so the patched menu blurs what is behind it like the
      // dock's glass (tool/patches/material-ui_glass_menu.patch)
      // every other switch looks like RevampSwitch: a white thumb of one
      // size on a filled track, no outline, no tick
      switchTheme: theme.switchTheme.copyWith(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        thumbIcon: const WidgetStatePropertyAll(Icon(null)),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      popupMenuTheme: theme.popupMenuTheme.copyWith(
        color: panel,
        elevation: 6,
        shadowColor: shadow,
        shape: Revamp.rounded(Revamp.menuRadius, side: rim),
        menuPadding: const EdgeInsets.symmetric(vertical: UiSpace.s8),
        textStyle: type.bodyLarge,
        labelTextStyle: WidgetStatePropertyAll(type.bodyLarge),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: type.labelLarge!.merge(
          UiType.bodyStrong.copyWith(fontWeight: UiType.title.fontWeight),
        ),
      ),
      // translucent like the menus, and blurred by the same kind of patch
      // (tool/patches/material-ui_glass_sheet.patch)
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: panel,
        elevation: 6,
        shadowColor: shadow,
        shape: Revamp.rounded(Revamp.sheetRadius, side: rim),
        titleTextStyle: theme.dialogTheme.titleTextStyle?.merge(UiType.title),
        contentTextStyle: type.bodyLarge!.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        elevation: 6,
        modalElevation: 6,
        shadowColor: shadow,
        shape: Revamp.shape(
          const BorderRadius.vertical(top: Radius.circular(Revamp.sheetRadius)),
          side: rim,
        ),
      ),
      // the cards of the pages not redesigned one by one: white blocks on
      // the gray page, set off by the difference alone, no shadow or tint
      cardTheme: theme.cardTheme.copyWith(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Revamp.rounded(Revamp.coverRadius),
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        titleTextStyle: theme.appBarTheme.titleTextStyle?.merge(UiType.title),
      ),
      // a row: its title as the body, the line under it as a caption, the
      // icon 12 from the text
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle: type.bodyLarge!.copyWith(color: colorScheme.onSurface),
        subtitleTextStyle: type.bodySmall!.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        horizontalTitleGap: UiSpace.iconText,
        minLeadingWidth: 24,
      ),
      dividerTheme: theme.dividerTheme.copyWith(
        color: colorScheme.outlineVariant,
      ),
    );
  }
}

/// A flat tonal pill behind the selected tab, inset from the tab's edges:
/// the one pill of every tab bar in the redesign, the glass ones included.
/// One material only, no shadow or rim: on glass it reads as part of it.
///
/// TabBarThemeData has no indicator padding, and a pill filling the whole
/// tab height looks heavy, so the inset is part of the decoration.
class PillTabIndicator extends Decoration {
  const PillTabIndicator({
    required this.color,
    this.insets = const EdgeInsets.symmetric(
      horizontal: UiSpace.s4,
      vertical: UiSpace.s8,
    ),
  });

  final Color color;
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
    canvas.drawRRect(rrect, Paint()..color = decoration.color);
  }
}

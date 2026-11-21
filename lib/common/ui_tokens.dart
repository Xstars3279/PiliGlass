import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart' show FlexSchemeVariant;
import 'package:material_ui/material_ui.dart';

/// The one set of values the redesign draws with: colors, spacing, corners
/// and type. A page takes its values from here, never a number of its own.
///
/// Three rules decide what is not written down:
/// 1. the content is loud, the shell quiet: neutral surfaces, the color is
///    the covers' and the avatars';
/// 2. the accent marks only what is selected, the main action, progress and
///    switches, and links;
/// 3. glass only for the shell floating over the content; what carries text
///    to read is solid, and the content never glass.

/// Spacing: 4, 8, 12, 16, 24, 32 and nothing else.
abstract final class UiSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;

  /// left and right of a page
  static const double page = s16;

  /// inside a card or a group
  static const double card = s16;

  /// between the columns, and the rows, of the video grid
  static const double gridColumn = s8;
  static const double gridRow = s16;

  /// between an icon and its text
  static const double iconText = s12;

  /// between the elements of one group
  static const double inGroup = s8;

  /// between one section and the next
  static const double section = s24;

  /// the dock: its height, and its gap to the bottom's safe area
  static const double dock = 64;
  static const double dockGap = s8;

  /// the room under a list on a page with the dock, so its last row
  /// scrolls clear of it: the dock, its gap and the safe area, and 24
  static double underDock(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + dockGap + dock + s24;
}

/// Corners. An inner corner is the outer one less the space between them,
/// and never under [small]: see [nested].
abstract final class UiRadius {
  /// badges, the labels on a cover, the selected block in a menu
  static const double small = 8;

  /// covers, posters, thumbnails, the sub-replies, a quoted card
  static const double medium = 12;

  /// groups, menus, dialogs, the top of a sheet
  static const double large = 24;

  // buttons, capsules, the bars, search and input fields are fully round:
  // a StadiumBorder, half their height

  static double nested(double outer, double gap) =>
      outer - gap < small ? small : outer - gap;
}

/// Type: five levels, weights 400, 500 and 600 only. A user who set the
/// app's font weight (全局字体粗细) gets theirs instead.
abstract final class UiType {
  static FontWeight _w(FontWeight weight) {
    final user = Pref.appFontWeight;
    return user == FontWeight.normal ? weight : user;
  }

  static TextStyle _style(double size, double line, FontWeight weight) =>
      TextStyle(fontSize: size, height: line / size, fontWeight: _w(weight));

  /// the title of a top level page
  static TextStyle get largeTitle => _style(24, 32, FontWeight.w600);

  /// a bar's title, a section's, a video's on its page, a name
  static TextStyle get title => _style(17, 24, FontWeight.w600);

  /// a row's title, a comment
  static TextStyle get body => _style(15, 22, FontWeight.w400);

  /// a card's title
  static TextStyle get bodyStrong => _style(15, 22, FontWeight.w500);

  /// an UP's name, views, a description, a time
  static TextStyle get caption => _style(13, 18, FontWeight.w400);

  /// badges, the figures on a cover, the dock's labels
  static TextStyle get label => _style(11, 14, FontWeight.w500);

  /// the weight a card's title takes, at the size it has
  static FontWeight get cardTitleWeight => _w(FontWeight.w500);
}

/// Colors: the accent of the scheme as it is, its surfaces neutral grays.
abstract final class UiColor {
  /// [scheme] with the surfaces, the text on them and the outlines of a
  /// near-gray scheme from the same seed: a light gray page with white
  /// blocks on it, a near black one with blocks a little lighter.
  ///
  /// As the scheme itself changes, the pages not redesigned turn gray and
  /// white too.
  static ColorScheme neutralize(ColorScheme scheme) {
    final dark = scheme.brightness.isDark;
    final n = scheme.primary.asColorSchemeSeed(
      FlexSchemeVariant.neutral,
      scheme.brightness,
    );
    return scheme.copyWith(
      // the page
      surface: dark ? n.surface : n.surfaceContainerLow,
      // the white blocks on it
      surfaceContainerLow: dark ? n.surfaceContainer : n.surfaceContainerLowest,
      surfaceContainerLowest: n.surfaceContainerLowest,
      surfaceContainer: n.surfaceContainer,
      surfaceContainerHigh: n.surfaceContainerHigh,
      surfaceContainerHighest: n.surfaceContainerHighest,
      surfaceDim: n.surfaceDim,
      surfaceBright: n.surfaceBright,
      onSurface: n.onSurface,
      onSurfaceVariant: n.onSurfaceVariant,
      outline: n.outline,
      outlineVariant: n.outlineVariant,
      inverseSurface: n.inverseSurface,
      onInverseSurface: n.onInverseSurface,
      // no accent mixed into a raised surface
      surfaceTint: Colors.transparent,
    );
  }
}

/// 透明效果 in 设置 › PiliGlass 特性: how much of the content shows
/// through what floats over it. 无 by default: floating, but solid.
///
/// 增强 is the redesign's look until now, the level that used to be called
/// 极致. 极致 is the liquid glass of v0.1.4: the shell a clear lens, and the
/// panels bend what is behind them as well.
enum UiGlassLevel {
  none('无'),
  standard('标准'),
  enhanced('增强'),
  extreme('极致');

  const UiGlassLevel(this.label);

  final String label;
}

/// What floats over the content, in two kinds:
/// - the shell (G1): the dock, the rail, the home tabs, the round buttons;
/// - a panel (G2): the comments, menus, sheets, dialogs, input bars, which
///   carry text to read and so are always all but solid.
///
/// Both are white blocks with a shadow, an outline instead in the dark,
/// where a shadow does not show. The player's controls (G3) keep their dark
/// gradient at every level, and the content is solid at every level.
abstract final class UiGlass {
  static const String key = 'glassLevel';

  /// read once, like the other features: a restart applies a change.
  /// 增强, the redesign's look until now, is where it starts.
  static final UiGlassLevel level =
      UiGlassLevel.values[(GStorage.setting.get(
                key,
                defaultValue: UiGlassLevel.enhanced.index,
              )
              as int)
          .clamp(0, UiGlassLevel.values.length - 1)];

  /// anything showing through at all
  static bool get clear => level != UiGlassLevel.none;

  /// the shell bending what is behind it, at 增强 and 极致
  static bool get refraction => level.index >= UiGlassLevel.enhanced.index;

  /// the liquid glass of 极致: much clearer, and the panels bend too
  static bool get liquid => level == UiGlassLevel.extreme;

  /// the colors behind the glass made more vivid where it shows them
  static double get saturation => clear ? 1.5 : 1;

  /// The unified alpha value across shell and panel floating surfaces.
  /// none: 1.0 (纯白不透明)
  /// standard: 0.90
  /// enhanced: 0.75 (原来的极致)
  /// extreme: 0.30 (v0.1.4 的透明液态玻璃，底栏 0.28、按钮 0.40)
  static double get alpha => switch (level) {
    UiGlassLevel.none => 1.0,
    UiGlassLevel.standard => 0.90,
    UiGlassLevel.enhanced => 0.75,
    UiGlassLevel.extreme => 0.30,
  };

  /// the shell: solid, 90%, 75% or the clear 30% of 极致
  static double get shellAlpha => alpha;
  static double get shellBlur => switch (level) {
    UiGlassLevel.none => 0,
    UiGlassLevel.standard => 6,
    UiGlassLevel.enhanced => 6,
    // v0.1.4 let the lens do the work, not the blur
    UiGlassLevel.extreme => 3,
  };
  static Color shell(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerLow.withValues(alpha: shellAlpha);

  /// a panel: solid, 90%, 75%, or the thick glass of 极致
  static double get panelAlpha => switch (level) {
    UiGlassLevel.none => 1.0,
    UiGlassLevel.standard => 0.90,
    UiGlassLevel.enhanced => 0.75,
    UiGlassLevel.extreme => 0.66,
  };
  static double get panelBlur => switch (level) {
    UiGlassLevel.none => 0,
    UiGlassLevel.standard => 4,
    UiGlassLevel.enhanced => 4,
    // v0.1.4's GlassBox
    UiGlassLevel.extreme => 16,
  };
  static Color panel(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerLow.withValues(alpha: panelAlpha);

  /// A menu floats over the content and is read at a glance, so it takes
  /// more of what is behind it as the glass gets deeper: solid at 无, nearly
  /// solid at 标准, and clearly liquid at 极致.
  static double get menuAlpha => switch (level) {
    UiGlassLevel.none => 1.0,
    UiGlassLevel.standard => 0.90,
    UiGlassLevel.enhanced => 0.78,
    UiGlassLevel.extreme => 0.54,
  };
  static Color menu(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerLow.withValues(alpha: menuAlpha);

  /// The pill behind the selected tab, in the bottom bar and the top tabs.
  /// At 极致 it lets 30% of the content behind it through, so the moving
  /// indicator reads as a tinted lens rather than a solid chip.
  static double get selectedAlpha => liquid ? 0.70 : 1.0;
  static Color selected(ColorScheme colorScheme) =>
      colorScheme.secondaryContainer.withValues(alpha: selectedAlpha);

  /// a panel bending what is behind it, at 极致 only, as v0.1.4's GlassBox
  /// did
  static double get panelRefractionHeight => liquid ? 16 : 0;
  static double get panelRefractionAmount => liquid ? 18 : 0;

  /// the lit rim of a panel, back with the thick glass of 极致
  static double get panelRim => liquid ? 0.75 : 0;

  /// a bar floating over content, as the comment sheet's: the dock's clear
  /// glass at 极致 (v0.1.4's input bar), the panel's tint elsewhere
  static Color input(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerHigh.withValues(alpha: inputAlpha);
  static double get inputAlpha => switch (level) {
    UiGlassLevel.none => 1.0,
    UiGlassLevel.standard => 0.90,
    UiGlassLevel.enhanced => 0.75,
    UiGlassLevel.extreme => 0.40,
  };

  static const shellShadow = BoxShadow(
    color: Color(0x14000000),
    offset: Offset(0, 4),
    blurRadius: 16,
  );
  static const panelShadow = BoxShadow(
    color: Color(0x1F000000),
    offset: Offset(0, 8),
    blurRadius: 24,
  );

  /// [shadow] in the light, none in the dark
  static BoxShadow? shadowIn(ColorScheme colorScheme, BoxShadow shadow) =>
      colorScheme.brightness.isDark ? null : shadow;

  /// the outline in the dark, none in the light
  static Color? edge(ColorScheme colorScheme) =>
      colorScheme.brightness.isDark ? colorScheme.outlineVariant : null;

  /// the dark outline as a side, for a shape
  static BorderSide side(ColorScheme colorScheme) => switch (edge(
    colorScheme,
  )) {
    final color? => BorderSide(color: color),
    null => BorderSide.none,
  };

  /// the lit rim of glass, at 增强 and 极致, where the shell is glass
  static double get rim => refraction ? 0.75 : 0;
}

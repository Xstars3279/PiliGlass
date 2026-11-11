import 'package:PiliPlus/utils/extension/theme_ext.dart';
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

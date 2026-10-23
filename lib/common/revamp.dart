import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// The redesigned interface comes with the liquid glass dock: turning that
/// off (悬浮底栏 or 液态玻璃悬浮底栏) brings back the original pages.
/// Both settings need a restart, so reading them once is enough.
abstract final class Revamp {
  static final bool enabled = Pref.floatingNavBar && Pref.liquidGlassNavBar;

  /// A light wash for a block inside a surface, glass or not, e.g. the
  /// sub-replies under a comment or an image that is still loading: it
  /// tints whatever is behind instead of covering it.
  static Color wash(ColorScheme colorScheme) =>
      colorScheme.onSurface.withValues(alpha: 0.06);

  // The redesign has two kinds of blocks. A group sets off a section on a
  // plain page: solid, see [RevampGroup]. A tile sits on something tinted
  // or on glass, e.g. in the video intro: the wash, smaller corners.

  /// corner radius of a group
  static const double groupRadius = 24;

  /// corner radius of a tile; upstream's small blocks where it is off
  static final double tileCorner = enabled ? 14 : 6;
  static final BorderRadius tileRadius = BorderRadius.all(
    Radius.circular(tileCorner),
  );

  /// a tile's color; upstream's where the redesign is off
  static Color tile(ColorScheme colorScheme) =>
      enabled ? wash(colorScheme) : colorScheme.onInverseSurface;

  /// Buttons over the video: a dark round of smoked glass behind each, so
  /// they read on a bright frame as well as a dark one.
  /// The light rim shows the round on the black bars beside a video too.
  static const overlayButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    backgroundColor: WidgetStatePropertyAll(Color(0x47000000)),
    shape: WidgetStatePropertyAll(
      CircleBorder(side: BorderSide(color: Color(0x33FFFFFF), width: 0.8)),
    ),
    fixedSize: WidgetStatePropertyAll(Size.square(34)),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// the smoked round of [overlayButtonStyle], for controls that are not
  /// buttons of their own
  static const overlayRoundDecoration = ShapeDecoration(
    color: Color(0x47000000),
    shape: CircleBorder(
      side: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
    ),
  );

  /// [child] on the smoked round when the redesign is on
  static Widget overlayRound(Widget child) => enabled
      ? DecoratedBox(decoration: overlayRoundDecoration, child: child)
      : child;

  /// A label over the video, e.g. 1.0X or 1080P, on a capsule of the same
  /// smoked glass as [overlayButtonStyle]; upstream's bare text if off.
  static Widget overlayChip(Widget label) => enabled
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              color: Color(0x47000000),
              shape: StadiumBorder(
                side: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: label,
            ),
          ),
        )
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: label,
        );
}

/// A rounded group of rows, the way the redesign sets off a section.
class RevampGroup extends StatelessWidget {
  const RevampGroup({super.key, required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(12, 0, 12, 12),
      // a Material, not a ColoredBox: ink ripples paint on the nearest
      // Material, and one below the group would be hidden by its color
      child: Material(
        color: ColorScheme.of(context).surfaceContainerLow,
        borderRadius: const BorderRadius.all(
          Radius.circular(Revamp.groupRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A large title that collapses into the bar as the page scrolls.
///
/// The app's AppBar theme sets a 16sp title style, which would also apply to
/// the expanded large title; it is left out here so the large title gets
/// its full size (the rest of the AppBar theme is kept).
class RevampLargeAppBar extends StatelessWidget {
  const RevampLargeAppBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = theme.appBarTheme;
    return Theme(
      data: theme.copyWith(
        appBarTheme: AppBarThemeData(
          backgroundColor: a.backgroundColor,
          foregroundColor: a.foregroundColor,
          elevation: a.elevation,
          scrolledUnderElevation: a.scrolledUnderElevation,
          shadowColor: a.shadowColor,
          surfaceTintColor: a.surfaceTintColor,
          iconTheme: a.iconTheme,
          actionsIconTheme: a.actionsIconTheme,
          centerTitle: a.centerTitle,
          titleSpacing: a.titleSpacing,
          toolbarHeight: a.toolbarHeight,
          systemOverlayStyle: a.systemOverlayStyle,
        ),
      ),
      child: SliverAppBar.large(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// An icon on a tinted rounded square, as in a settings list.
class RevampIconTile extends StatelessWidget {
  const RevampIconTile({super.key, required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: SizedBox.square(
        dimension: 34,
        child: IconTheme.merge(
          data: IconThemeData(
            size: 20,
            color: colorScheme.onPrimaryContainer,
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// A settings row's leading icon, on a tile when the redesign is on.
Widget? revampLeading(Widget? leading) =>
    Revamp.enabled && leading != null ? RevampIconTile(icon: leading) : leading;

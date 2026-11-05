import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/motion/pressable_scale.dart';
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

  /// corner radius of what rises over a page: sheets and dialogs
  static const double sheetRadius = 28;

  /// corner radius of a capsule to type in, e.g. the reply panel
  static const double fieldRadius = 24;

  /// corner radius of a menu
  static const double menuRadius = 20;

  /// corner radius of a cover across a card, and of a thumbnail beside a
  /// card's text
  static const double coverRadius = 16;
  static const double thumbRadius = 14;

  /// 关注 and 追番 buttons: the primary color while the tap would follow,
  /// the wash once followed. Null where the redesign is off, for upstream's.
  static Color? followBg(ColorScheme colorScheme, bool followed) => !enabled
      ? null
      : followed
      ? wash(colorScheme)
      : colorScheme.primary;
  static Color? followFg(ColorScheme colorScheme, bool followed) => !enabled
      ? null
      : followed
      ? colorScheme.onSurfaceVariant
      : colorScheme.onPrimary;

  /// A card that dips when pressed and springs back and rises in when its
  /// list loads, like the feed's cards; as it is when the redesign is off.
  static Widget pressable(Widget card) => enabled
      ? RiseIn(child: PressableScale(pressedScale: 0.97, child: card))
      : card;

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

  /// the smoked glass of [overlayRoundDecoration] as a capsule
  static const overlayCapsuleDecoration = ShapeDecoration(
    color: Color(0x47000000),
    shape: StadiumBorder(
      side: BorderSide(color: Color(0x33FFFFFF), width: 0.8),
    ),
  );

  /// A label over the video, e.g. 1.0X or 1080P, on a capsule of the same
  /// smoked glass as [overlayButtonStyle]; upstream's bare text if off.
  static Widget overlayChip(Widget label) => enabled
      ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: DecoratedBox(
            decoration: overlayCapsuleDecoration,
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

/// [RevampGroup] for slivers: the rows of [sliver], e.g. a long list built
/// lazily, on one rounded group.
class RevampSliverGroup extends StatelessWidget {
  const RevampSliverGroup({super.key, required this.sliver, this.margin});

  final Widget sliver;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: margin ?? const EdgeInsets.fromLTRB(12, 0, 12, 12),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: ColorScheme.of(context).surfaceContainerLow,
          borderRadius: const BorderRadius.all(
            Radius.circular(Revamp.groupRadius),
          ),
        ),
        sliver: sliver,
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
  const RevampLargeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.implyLeading = true,
  });

  final String title;
  final List<Widget>? actions;

  /// false for a pane beside a list, e.g. the settings on a tablet: the
  /// back button belongs to the page, not to each pane
  final bool implyLeading;

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
        automaticallyImplyLeading: implyLeading,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: actions,
      ),
    );
  }
}

/// The large title of [RevampLargeAppBar] over a page whose body scrolls on
/// its own, e.g. a settings page with a list: the title collapses into the
/// bar as the body scrolls. Just [body] where the redesign is off, and the
/// page keeps its own AppBar.
class RevampLargeTitle extends StatelessWidget {
  const RevampLargeTitle({
    super.key,
    required this.title,
    this.actions,
    this.implyLeading = true,
    required this.body,
  });

  final String title;
  final List<Widget>? actions;
  final bool implyLeading;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    if (!Revamp.enabled) return body;
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        RevampLargeAppBar(
          title: title,
          actions: actions,
          implyLeading: implyLeading,
        ),
      ],
      // the bar keeps the status bar's room
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: body,
      ),
    );
  }
}

/// [rows] drawn as one rounded group, see [revampGroupRow]
List<Widget> revampGroupRows(BuildContext context, List<Widget> rows) => [
  for (final (index, row) in rows.indexed)
    revampGroupRow(
      context: context,
      index: index,
      count: rows.length,
      child: row,
    ),
];

/// What a message answers, quoted on the wash under it; empty lines are
/// left out, and the whole of it when all are.
class RevampQuote extends StatelessWidget {
  const RevampQuote({super.key, required this.lines});

  final List<String?> lines;

  @override
  Widget build(BuildContext context) {
    final shown = lines.whereType<String>().where((e) => e.isNotEmpty);
    if (shown.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Revamp.wash(theme.colorScheme),
        borderRadius: Revamp.tileRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          for (final line in shown)
            Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium!.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}

/// A list of rows drawn as one rounded group, see [revampGroupRow]; where
/// the redesign is off, upstream's list with a separator between rows.
/// Takes what [SliverList.separated] takes, so a page swaps the one name.
Widget revampSliverList({
  required NullableIndexedWidgetBuilder itemBuilder,
  required IndexedWidgetBuilder separatorBuilder,
  required int itemCount,
}) {
  if (!Revamp.enabled) {
    return SliverList.separated(
      itemBuilder: itemBuilder,
      separatorBuilder: separatorBuilder,
      itemCount: itemCount,
    );
  }
  return SliverList.builder(
    itemCount: itemCount,
    itemBuilder: (context, index) => revampGroupRow(
      context: context,
      index: index,
      count: itemCount,
      child: itemBuilder(context, index) ?? const SizedBox.shrink(),
    ),
  );
}

/// A row of a list built row by row, drawn as a part of one rounded group
/// like [RevampGroup]: the first row rounds the top, the last the bottom.
/// Just [child] where the redesign is off.
Widget revampGroupRow({
  required BuildContext context,
  required int index,
  required int count,
  required Widget child,
}) {
  if (!Revamp.enabled) return child;
  const radius = Radius.circular(Revamp.groupRadius);
  final first = index == 0;
  final last = index == count - 1;
  return Padding(
    padding: EdgeInsets.fromLTRB(12, first ? 4 : 0, 12, last ? 12 : 0),
    // a Material, not a ColoredBox: ink ripples paint on the nearest
    // Material, and one below the group would be hidden by its color
    child: Material(
      color: ColorScheme.of(context).surfaceContainerLow,
      borderRadius: BorderRadius.vertical(
        top: first ? radius : Radius.zero,
        bottom: last ? radius : Radius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(top: first ? 8 : 0, bottom: last ? 8 : 0),
        child: child,
      ),
    ),
  );
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

/// The height of a bar floating over the top of a feed, e.g. the home tabs
/// on glass: the feed starts below it and scrolls on under it. Zero where
/// nothing floats.
class RevampTopInset extends InheritedWidget {
  const RevampTopInset({super.key, required this.inset, required super.child});

  final double inset;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RevampTopInset>()?.inset ?? 0;

  /// room for the bar at the start of a scroll view's slivers
  static Widget sliver(BuildContext context) {
    final inset = of(context);
    return SliverToBoxAdapter(
      child: inset > 0 ? SizedBox(height: inset) : null,
    );
  }

  @override
  bool updateShouldNotify(RevampTopInset oldWidget) => oldWidget.inset != inset;
}

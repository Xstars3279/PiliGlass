import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/motion/pressable_scale.dart';
import 'package:PiliPlus/common/ui_icons.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
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

  // Surfaces, from the bottom up: the light gray page (surface); a white
  // block on it, a group or a card (surfaceContainerLow, see [RevampGroup]);
  // a block inside that, e.g. the sub-replies (surfaceContainerHigh, see
  // [tile]); and what rises over the page, sheets, dialogs and menus, white
  // again, see RevampTheme. See UiColor.neutralize.
  //
  // The corners are UiRadius's, all of them continuous, see [shape].

  /// the color of a group, see [RevampGroup]
  static Color groupColor(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerLow;

  /// corner radius of a group
  static const double groupRadius = UiRadius.large;

  /// The redesign's corner: continuous, a superellipse rather than a
  /// circle's quarter, so the edge eases into its turn instead of starting
  /// it all at once, as Apple's corners do. Upstream's round corners where
  /// the redesign is off.
  static OutlinedBorder shape(
    BorderRadiusGeometry radius, {
    BorderSide side = BorderSide.none,
  }) => enabled
      ? RoundedSuperellipseBorder(borderRadius: radius, side: side)
      : RoundedRectangleBorder(borderRadius: radius, side: side);

  /// [shape] with the same [radius] at every corner
  static OutlinedBorder rounded(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => shape(BorderRadius.all(Radius.circular(radius)), side: side);

  /// [child] clipped to [shape]
  static Widget clip({
    required BorderRadius radius,
    required Widget child,
    Clip clipBehavior = Clip.antiAlias,
  }) => enabled
      ? ClipRSuperellipse(
          borderRadius: radius,
          clipBehavior: clipBehavior,
          child: child,
        )
      : ClipRRect(
          borderRadius: radius,
          clipBehavior: clipBehavior,
          child: child,
        );

  /// A bar pinned over a list, e.g. the sort bar over the comments: part
  /// of the content, so solid, the page's own gray.
  static Color barColor(ColorScheme colorScheme) => colorScheme.surface;

  /// corner radius of what rises over a page: sheets and dialogs
  static const double sheetRadius = UiRadius.large;

  /// corner radius of a capsule to type in, e.g. the reply panel: round at
  /// its usual height
  static const double fieldRadius = UiRadius.large;

  /// corner radius of a menu
  static const double menuRadius = UiRadius.large;

  /// the menus over the video: black 72%, so the picture still shows a
  /// little through them, and 120 wide (7.3)
  static const playerMenuColor = Color(0xB8000000);
  static const playerMenuConstraints = BoxConstraints(
    minWidth: 120,
    maxWidth: 120,
  );

  /// corner radius of a cover across a card, and of a thumbnail beside a
  /// card's text
  static const double coverRadius = UiRadius.medium;
  static const double thumbRadius = UiRadius.medium;

  /// 关注 and 追番 buttons: the primary color while the tap would follow,
  /// a [tile]'s once followed. Null where the redesign is off, for upstream's.
  static Color? followBg(ColorScheme colorScheme, bool followed) => !enabled
      ? null
      : followed
      ? tile(colorScheme)
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
  static final double tileCorner = enabled ? UiRadius.medium : 6;
  static final BorderRadius tileRadius = BorderRadius.all(
    Radius.circular(tileCorner),
  );

  /// a tile's [shape], e.g. for a Material, or an InkWell's customBorder
  static final OutlinedBorder tileShape = shape(tileRadius);

  /// a block inside a white block, e.g. the sub-replies or an episode;
  /// upstream's where the redesign is off
  static Color tile(ColorScheme colorScheme) =>
      enabled ? colorScheme.surfaceContainerHigh : colorScheme.onInverseSurface;

  /// a field or an unselected capsule straight on the gray page: white
  static Color onPage(ColorScheme colorScheme) =>
      colorScheme.surfaceContainerLow;

  /// Buttons over the video or a cover: a round of black 32% behind each,
  /// 40 across, so the white icon reads on a bright frame as well as a dark
  /// one. Never light glass.
  static const overlayButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    backgroundColor: WidgetStatePropertyAll(Color(0x52000000)),
    shape: WidgetStatePropertyAll(CircleBorder()),
    fixedSize: WidgetStatePropertyAll(Size.square(40)),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// A control on the full screen video: no round behind it, a 48 tap
  /// target, and the scrim above and below carries it instead (7.2).
  static const playerButtonStyle = ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(CircleBorder()),
    fixedSize: WidgetStatePropertyAll(Size.square(48)),
    minimumSize: WidgetStatePropertyAll(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  /// the smoked round of [overlayButtonStyle], for controls that are not
  /// buttons of their own
  static const overlayRoundDecoration = ShapeDecoration(
    color: Color(0x52000000),
    shape: CircleBorder(),
  );

  /// [child] on the smoked round when the redesign is on
  static Widget overlayRound(Widget child) => enabled
      ? DecoratedBox(decoration: overlayRoundDecoration, child: child)
      : child;

  /// the smoked glass of [overlayRoundDecoration] as a capsule
  static const overlayCapsuleDecoration = ShapeDecoration(
    color: Color(0x52000000),
    shape: StadiumBorder(),
  );

  /// A label over the video, e.g. 1.0X or 1080P: plain white text, no
  /// capsule or outline behind it (7.2); upstream's bare text if off.
  static Widget overlayChip(Widget label) => Padding(
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
      padding:
          margin ??
          const EdgeInsets.fromLTRB(
            UiSpace.page,
            0,
            UiSpace.page,
            UiSpace.section,
          ),
      // a Material, not a ColoredBox: ink ripples paint on the nearest
      // Material, and one below the group would be hidden by its color
      child: Material(
        color: Revamp.groupColor(ColorScheme.of(context)),
        shape: Revamp.rounded(Revamp.groupRadius),
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
      padding:
          margin ??
          const EdgeInsets.fromLTRB(
            UiSpace.page,
            0,
            UiSpace.page,
            UiSpace.section,
          ),
      sliver: DecoratedSliver(
        decoration: ShapeDecoration(
          color: Revamp.groupColor(ColorScheme.of(context)),
          shape: Revamp.rounded(Revamp.groupRadius),
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
      // medium, not large: its title is the large title's 24, and it sits
      // just below the bar instead of a bar's height lower
      child: SliverAppBar.medium(
        automaticallyImplyLeading: implyLeading,
        title: Text(title),
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

/// The small label above a group, e.g. 内容 over the settings: lined up with
/// the text in the group, 8 above it.
class RevampGroupLabel extends StatelessWidget {
  const RevampGroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      UiSpace.page + UiSpace.card,
      0,
      UiSpace.page + UiSpace.card,
      UiSpace.s8,
    ),
    child: Text(
      text,
      style: UiType.caption.copyWith(
        fontWeight: UiType.label.fontWeight,
        color: ColorScheme.of(context).onSurfaceVariant,
      ),
    ),
  );
}

/// The line between two rows of a group: 1dp, from where the row's text
/// starts, past its 24 icon and the 12 after it, to the group's padding.
class RevampRowDivider extends StatelessWidget {
  const RevampRowDivider({super.key, this.indent = rowTextStart});

  /// where a row's text starts: its padding, the icon, the gap
  static const double rowTextStart = UiSpace.card + 24 + UiSpace.iconText;

  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: indent,
    endIndent: UiSpace.card,
    color: ColorScheme.of(context).outlineVariant,
  );
}

/// [rows] with a [RevampRowDivider] between each two
List<Widget> revampDivided(Iterable<Widget> rows) => [
  for (final (index, row) in rows.indexed) ...[
    if (index > 0) const RevampRowDivider(),
    row,
  ],
];

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
      margin: const EdgeInsets.only(bottom: UiSpace.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s12,
        vertical: UiSpace.s8,
      ),
      decoration: ShapeDecoration(
        color: Revamp.tile(theme.colorScheme),
        shape: Revamp.tileShape,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: UiSpace.s4,
        children: [
          for (final line in shown)
            Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: UiType.caption.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
    padding: EdgeInsets.fromLTRB(
      UiSpace.page,
      first ? UiSpace.s4 : 0,
      UiSpace.page,
      last ? UiSpace.section : 0,
    ),
    // a Material, not a ColoredBox: ink ripples paint on the nearest
    // Material, and one below the group would be hidden by its color
    child: Material(
      color: Revamp.groupColor(ColorScheme.of(context)),
      shape: Revamp.shape(
        BorderRadius.vertical(
          top: first ? radius : Radius.zero,
          bottom: last ? radius : Radius.zero,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          top: first ? UiSpace.s8 : 0,
          bottom: last ? UiSpace.s8 : 0,
        ),
        child: child,
      ),
    ),
  );
}

/// A row's leading icon as the redesign draws it, e.g. in a settings list:
/// plain, rounded and outlined (UiIcons), 24dp, in the gray of secondary
/// text; no tile behind it, the accent is not for decoration.
class RevampIconTile extends StatelessWidget {
  const RevampIconTile({super.key, required this.icon});

  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return IconTheme.merge(
      data: IconThemeData(
        size: 24,
        color: ColorScheme.of(context).onSurfaceVariant,
      ),
      child: UiIcons.rounded(icon),
    );
  }
}

/// A settings row's leading icon, as [RevampIconTile] when the redesign is
/// on.
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

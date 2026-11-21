import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_strip.dart';
import 'package:material_ui/material_ui.dart';

/// A page's tabs on a capsule of refracting glass, floating over its feed:
/// the home tabs and the 动态 tabs share it, so they look and move alike.
/// The tabs start at the left and scroll if they run out of room.
///
/// The work is [GlassTabStrip]'s; this keeps the member page's API.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.onTap,
    this.refraction = true,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int>? onTap;

  /// whether a feed passes under it; above a page that stays put, the
  /// bending would only cost
  final bool refraction;

  /// the bar's own height; with [margin], the room it takes over a feed
  static const height = 44.0;
  static const margin = EdgeInsets.fromLTRB(
    UiSpace.page,
    UiSpace.s8,
    UiSpace.page,
    UiSpace.s4,
  );
  static const extent = UiSpace.s8 + height + UiSpace.s4;

  /// the width over which the tabs fade out at the right, so a tab that
  /// runs out of room is never cut off sharp
  static const fade = UiSpace.s24;

  @override
  Widget build(BuildContext context) => GlassTabStrip(
    items: [for (final label in labels) GlassTabItem(label)],
    controller: controller,
    // reported after the controller moves, as TabBar's own onTap is: the
    // member page checks indexIsChanging to go back to the top
    onTap: onTap,
    capsule: true,
    centered: false,
    height: height,
    refraction: refraction,
    drag: GlassTabDrag.scrub,
  );
}

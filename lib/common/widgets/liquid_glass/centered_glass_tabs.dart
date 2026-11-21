import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_strip.dart';
import 'package:material_ui/material_ui.dart';

/// A page's tabs on the shell's glass, sized to what they hold: a short row
/// sits in the middle of the room it is given instead of hugging the left, and
/// a long one takes the whole width and scrolls. The pill under the chosen tab
/// follows the page as it is swiped, in step with the page itself, and whenever
/// the chosen tab has something on both of its sides the row is scrolled to put
/// it in the middle, as far as the row's ends allow.
///
/// With [centered] off the row keeps the whole width and its tabs start at the
/// left, as upstream's own bar does.
///
/// One label is enough to size it: a page with a single tab gets a small
/// capsule with that one tab in it.
///
/// The work is [GlassTabStrip]'s; this keeps the home and 动态 callers' API.
class CenteredGlassTabs extends StatelessWidget {
  const CenteredGlassTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.onTap,
    this.refraction = true,
    this.height = 44,
    this.labelPadding = 14,
    this.centered = true,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int>? onTap;

  /// whether a feed passes under it, so the glass may bend at its rim
  final bool refraction;

  /// the capsule's own height, the room of its padding included
  final double height;

  /// the room each label keeps on either side
  final double labelPadding;

  /// whether the row sits in the middle of the room it is given
  final bool centered;

  @override
  Widget build(BuildContext context) => GlassTabStrip(
    items: [for (final label in labels) GlassTabItem(label)],
    controller: controller,
    // reported before the controller moves, as this bar has always done: the
    // home and 动态 pages read it to go back to the top
    onSelected: onTap,
    // the pill follows the finger across the labels and commits on release;
    // a row that does not fit scrolls at its edge as the finger gets there
    drag: GlassTabDrag.scrub,
    capsule: true,
    centered: centered,
    height: height,
    labelPadding: labelPadding,
    refraction: refraction,
  );
}

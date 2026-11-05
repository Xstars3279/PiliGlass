import 'package:PiliPlus/common/revamp_theme.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:material_ui/material_ui.dart';

/// A page's tabs on a capsule of refracting glass, floating over its feed:
/// the home tabs and the 动态 tabs share it, so they look and move alike.
/// The tabs start at the left and scroll if they run out of room.
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
  static const height = 48.0;
  static const margin = EdgeInsets.fromLTRB(12, 6, 12, 4);
  static const extent = 6.0 + height + 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GlassCapsule(
      // a feed passing under it is bent like the dock bends it
      refraction: refraction,
      child: TabBar(
        controller: controller,
        tabs: labels.map((e) => Tab(text: e)).toList(),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        // the theme's pill, filling the capsule's height here
        indicator: PillTabIndicator(
          color: colorScheme.surfaceContainerHighest,
          shadow: Colors.black.withValues(
            alpha: colorScheme.brightness == .dark ? 0.4 : 0.12,
          ),
          insets: EdgeInsets.zero,
        ),
        onTap: (index) {
          feedBack();
          onTap?.call(index);
        },
      ),
    );
  }
}

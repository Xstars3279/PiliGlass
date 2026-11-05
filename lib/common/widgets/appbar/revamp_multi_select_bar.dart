import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// The bar of a list while picking from it, in the redesign: the count and
/// what can be done to the picked on a capsule of glass, like the tabs at
/// the top of the home page, in place of a plain AppBar.
class RevampMultiSelectBar extends StatelessWidget {
  const RevampMultiSelectBar({
    super.key,
    required this.ctr,
    this.actions,
    this.bottom,
  });

  final MultiSelectBase ctr;
  final List<Widget>? actions;

  /// e.g. the page's tabs, kept below the capsule
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final style = TextButton.styleFrom(visualDensity: VisualDensity.compact);
    final bar = SafeArea(
      bottom: false,
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: GlassCapsule(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: '取消',
                  onPressed: ctr.handleSelect,
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Obx(
                    () => Text(
                      '已选 ${ctr.checkedCount} 项',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: style,
                  onPressed: () => ctr.handleSelect(checked: true),
                  child: const Text('全选'),
                ),
                ...?actions,
                TextButton(
                  style: style,
                  onPressed: () {
                    if (ctr.checkedCount == 0) return;
                    ctr.onRemove();
                  },
                  child: Text(
                    '移除',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final bottom = this.bottom;
    return Material(
      color: colorScheme.surface,
      child: bottom == null
          ? bar
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [bar, bottom],
            ),
    );
  }
}

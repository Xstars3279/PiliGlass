import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/setting/models/glass_settings.dart';
import 'package:material_ui/material_ui.dart';

/// 设置 › PiliGlass 特性: the switches of what PiliGlass adds, under small
/// labels in rounded groups, like the settings' first page.
class GlassFeaturesPage extends StatelessWidget {
  const GlassFeaturesPage({super.key, this.showAppBar = true});

  /// false beside the list of settings on a wide screen
  final bool showAppBar;

  static const title = 'PiliGlass 特性';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final side = EdgeInsets.only(
      left: showAppBar ? padding.left : 0,
      right: showAppBar ? padding.right : 0,
    );
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (!Revamp.enabled) {
      return SimpleScaffold(
        appBar: showAppBar ? AppBar(title: const Text(title)) : null,
        body: ListView(
          padding: side.copyWith(bottom: padding.bottom + 100),
          children: [
            for (final (name, models) in glassSettingGroups) ...[
              label(name),
              ...models.map((e) => e.widget),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          RevampLargeAppBar(title: title, implyLeading: showAppBar),
          for (final (name, models) in glassSettingGroups)
            SliverPadding(
              padding: side,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label(name),
                    RevampGroup(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: models.map((e) => e.widget).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(padding: EdgeInsets.only(bottom: padding.bottom + 60)),
        ],
      ),
    );
  }
}

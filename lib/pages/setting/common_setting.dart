import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:material_ui/material_ui.dart';

class CommonSetting extends StatefulWidget {
  const CommonSetting({
    super.key,
    required this.settingType,
    this.showAppBar = true,
  });

  final bool showAppBar;
  final SettingType settingType;

  @override
  State<CommonSetting> createState() => _CommonSettingState();
}

class _CommonSettingState extends State<CommonSetting> {
  late EdgeInsets padding;
  late List<SettingsModel> settings;

  void _initSetting() {
    settings = widget.settingType.settings;
  }

  @override
  void initState() {
    super.initState();
    _initSetting();
  }

  @override
  void didUpdateWidget(CommonSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingType != oldWidget.settingType) {
      _initSetting();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    if (Revamp.enabled) {
      // large title, and all the options in one rounded group; beside the
      // list of settings on a wide screen too, without a back button
      return Scaffold(
        body: CustomScrollView(
          key: ValueKey(widget.settingType),
          slivers: [
            RevampLargeAppBar(
              title: widget.settingType.title,
              implyLeading: showAppBar,
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                (showAppBar ? padding.left : 0) + UiSpace.page,
                UiSpace.s4,
                (showAppBar ? padding.right : 0) + UiSpace.page,
                padding.bottom + 60,
              ),
              sliver: RevampSliverGroup(
                margin: EdgeInsets.zero,
                sliver: SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.separated(
                    itemCount: settings.length,
                    // ink ripples need a Material above the group's color
                    itemBuilder: (context, index) => Material(
                      type: MaterialType.transparency,
                      child: settings[index].widget,
                    ),
                    separatorBuilder: (_, _) => const RevampRowDivider(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SimpleScaffold(
      appBar: showAppBar ? AppBar(title: Text(widget.settingType.title)) : null,
      body: ListView.builder(
        key: ValueKey(widget.settingType),
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        itemCount: settings.length,
        itemBuilder: (context, index) => settings[index].widget,
      ),
    );
  }
}

import 'package:PiliPlus/common/revamp.dart';
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
    if (Revamp.enabled && showAppBar) {
      // large title, and all the options in one rounded group
      return Scaffold(
        body: CustomScrollView(
          key: ValueKey(widget.settingType),
          slivers: [
            RevampLargeAppBar(title: widget.settingType.title),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                padding.left + 12,
                4,
                padding.right + 12,
                padding.bottom + 60,
              ),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: ColorScheme.of(context).surfaceContainerLow,
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                ),
                sliver: SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  sliver: SliverList.builder(
                    itemCount: settings.length,
                    // ink ripples need a Material above the group's color
                    itemBuilder: (context, index) => Material(
                      type: MaterialType.transparency,
                      child: settings[index].widget,
                    ),
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

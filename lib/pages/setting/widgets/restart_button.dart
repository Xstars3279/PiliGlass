import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_icon_button.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_menu.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Top-right restart menu button shared across settings pages.
class SettingRestartButton extends StatelessWidget {
  const SettingRestartButton({super.key});

  static const List<Widget> actions = [
    SettingRestartButton(),
    SizedBox(width: 4),
  ];

  static const _menuItems = <PopupMenuEntry<void>>[
    PopupMenuItem<void>(
      onTap: DeviceUtils.restartApp,
      child: Row(
        spacing: 10,
        mainAxisSize: .min,
        children: [
          Icon(Icons.restart_alt_rounded, size: 19),
          Text('重启软件'),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (!Revamp.enabled) {
      return PopupMenuButton<void>(
        tooltip: '重启',
        icon: const Icon(Icons.restart_alt_rounded),
        itemBuilder: (_) => _menuItems,
      );
    }
    return GlassPopupAnchor<void>(
      itemBuilder: (_) => _menuItems,
      targetBuilder: (open) => GlassIconButton(
        tapSize: 44,
        tooltip: '重启',
        onTap: open,
        icon: const Icon(Icons.restart_alt_rounded),
      ),
    );
  }
}

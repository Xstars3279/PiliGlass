import 'package:PiliPlus/common/ui_icons_map.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:material_ui/material_ui.dart';

/// The redesign's icons: Flutter's own rounded ones, full and soft, 24dp.
/// Only the shell and the redesigned pages; upstream's pages keep their own.
abstract final class UiIcons {
  /// [icon]'s rounded twin, or [icon] itself when it has none, e.g. one of
  /// MdiIcons
  static IconData of(IconData icon) => materialToRounded[icon] ?? icon;

  /// [icon] as its rounded twin; any other widget as it is
  static Widget rounded(Widget icon) {
    if (icon is Icon) {
      final twin = materialToRounded[icon.icon];
      if (twin != null) {
        return Icon(
          twin,
          size: icon.size,
          color: icon.color,
          semanticLabel: icon.semanticLabel,
        );
      }
    }
    return icon;
  }

  /// a tab of the dock or the rail; the selected one is told by its pill
  /// and its color
  static Icon nav(NavigationBarType type) => Icon(switch (type) {
    NavigationBarType.home => Icons.home_rounded,
    NavigationBarType.dynamics => Icons.motion_photos_on_rounded,
    NavigationBarType.mine => Icons.person_rounded,
  });
}

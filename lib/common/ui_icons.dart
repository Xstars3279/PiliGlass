import 'package:PiliPlus/common/ui_icons_map.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The redesign's icons: Material Symbols, rounded, 24dp; outlined, and
/// filled where they stand for what is selected. Only the shell and the
/// redesigned pages; upstream's pages keep their own.
abstract final class UiIcons {
  /// [icon]'s rounded twin, or [icon] itself when it has none, e.g. one of
  /// MdiIcons
  static IconData of(IconData icon) => materialToRounded[icon] ?? icon;

  /// [icon] as its rounded twin, outlined, or filled when [filled]; any
  /// other widget as it is
  static Widget rounded(Widget icon, {bool filled = false}) {
    if (icon is Icon) {
      final twin = materialToRounded[icon.icon];
      if (twin != null) {
        return Icon(
          twin,
          fill: filled ? 1 : 0,
          size: icon.size,
          color: icon.color,
          semanticLabel: icon.semanticLabel,
        );
      }
    }
    return icon;
  }

  /// a tab of the dock or the rail
  static Icon nav(NavigationBarType type, {required bool selected}) => Icon(
    switch (type) {
      NavigationBarType.home => Symbols.home_rounded,
      NavigationBarType.dynamics => Symbols.motion_photos_on_rounded,
      NavigationBarType.mine => Symbols.person_rounded,
    },
    fill: selected ? 1 : 0,
  );
}

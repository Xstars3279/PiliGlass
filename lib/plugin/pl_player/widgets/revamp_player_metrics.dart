import 'package:PiliPlus/common/revamp.dart';
import 'package:material_ui/material_ui.dart';

/// Compact measurements used only by the redesigned player controls.
///
/// Other pages keep their larger touch targets. The player has many controls
/// in two short rows, so matching their visible weight matters more here than
/// applying the app's usual 48dp button everywhere.
abstract final class RevampPlayerMetrics {
  static const double compactButtonWidth = 42;
  static const double compactButtonHeight = 34;
  static const double compactIconSize = 20;
  static const double compactGap = 4;
  static const double danmakuFieldHeight = 32;
  static const double settingsSheetWidth = 360;
  static const double settingsRowHeight = 40;

  static final ButtonStyle compactButtonStyle = Revamp.playerButtonStyle
      .copyWith(
        fixedSize: const WidgetStatePropertyAll(
          Size(compactButtonWidth, compactButtonHeight),
        ),
      );
}

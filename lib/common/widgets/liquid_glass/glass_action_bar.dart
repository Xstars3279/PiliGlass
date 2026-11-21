import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:material_ui/material_ui.dart';

/// A page's top-right actions on one capsule of the dock's glass, as 我的
/// has them: each button swells under its own finger, and the capsule holds
/// them together as one floating block.
class GlassActionBar extends StatelessWidget {
  const GlassActionBar({
    super.key,
    required this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.spacing = 5,
    this.refraction = true,
    this.maxGrowth = 8,
  });

  final List<Widget> actions;
  final EdgeInsetsGeometry padding;
  final double spacing;

  /// Whether the feed or page passes under it, so the rim bends it.
  final bool refraction;

  /// How far one button swells on a full press, in dp.
  final double maxGrowth;

  @override
  Widget build(BuildContext context) {
    return GlassCapsule(
      refraction: refraction,
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: spacing,
        children: [
          for (final action in actions)
            LiquidPress(maxGrowth: maxGrowth, child: action),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:material_ui/material_ui.dart';

/// A round glass coin for a bare icon button: a light tint, the lit rim of
/// the level, and a press that swells it as the dock's buttons do.
///
/// [liquid] adds the blur and refraction of the shell; list rows keep it off,
/// as a backdrop filter per card would cost frames.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.size = 36,
    this.tapSize = 40,
    this.iconSize,
    this.color,
    this.liquid = false,
    this.selected = false,
    this.enabled = true,
  });

  final Widget icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double size;
  final double tapSize;
  final double? iconSize;
  final Color? color;
  final bool liquid;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final radius = Radius.circular(size / 2);
    final foreground =
        color ??
        (selected
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant);
    final fill = selected ? colorScheme.secondaryContainer : UiGlass.panel(colorScheme);

    Widget button = SizedBox.square(
      dimension: size,
      child: IconTheme.merge(
        data: IconThemeData(size: iconSize ?? size * 0.55, color: foreground),
        child: Center(child: icon),
      ),
    );

    final glass = liquid
        ? LiquidGlass(
            radius: size / 2,
            blurSigma: UiGlass.shellBlur,
            refractionHeight: UiGlass.refraction ? 12 : 0,
            refractionAmount: UiGlass.refraction ? 14 : 0,
            saturation: UiGlass.saturation,
            color: fill,
            child: button,
          )
        : DecoratedBox(
            decoration: ShapeDecoration(color: fill, shape: const StadiumBorder()),
            child: button,
          );

    final coin = CustomPaint(
      painter: GlassShadowPainter.of(
        radius: radius,
        shadow: UiGlass.shadowIn(colorScheme, UiGlass.shellShadow),
      ),
      foregroundPainter: GlassRimPainter(
        radius: radius,
        // a light outline, not the full lit rim of a larger panel
        opacity: UiGlass.rim * 0.7,
        isDark: isDark,
        edge: UiGlass.edge(colorScheme),
      ),
      child: glass,
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Semantics(
      button: true,
      label: tooltip,
      enabled: enabled,
      child: LiquidPress(
        enabled: enabled,
        maxGrowth: 10,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: SizedBox.square(
              // the coin may be smaller than a comfortable tap target
              dimension: math.max(size, tapSize),
              child: Center(child: coin),
            ),
          ),
        ),
      ),
    );
  }
}

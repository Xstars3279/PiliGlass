import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// The pull-to-refresh spinner on a round of liquid glass: the feed behind
/// bends at its rim, like the dock's buttons.
class GlassRefreshIndicator extends StatelessWidget {
  const GlassRefreshIndicator({super.key, this.value, this.color});

  /// null spins
  final double? value;
  final Color? color;

  static const _size = 42.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const radius = Radius.circular(_size / 2);
    return Padding(
      // the room the stock indicator keeps around its circle
      padding: const EdgeInsets.all(4),
      child: SizedBox.square(
        dimension: _size,
        child: CustomPaint(
          painter: GlassShadowPainter.of(
            radius: radius,
            shadow: UiGlass.shadowIn(colorScheme, UiGlass.shellShadow),
          ),
          foregroundPainter: GlassRimPainter(
            radius: radius,
            opacity: UiGlass.rim,
            isDark: isDark,
            edge: UiGlass.edge(colorScheme),
          ),
          child: LiquidGlass(
            blurSigma: UiGlass.shellBlur,
            refractionHeight:
                UiGlass.refraction ? 12 * UiGlass.shellRefractionScale : 0,
            refractionAmount:
                UiGlass.refraction ? 14 * UiGlass.shellRefractionScale : 0,
            saturation: UiGlass.saturation,
            color: UiGlass.shell(colorScheme),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                color: color ?? colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

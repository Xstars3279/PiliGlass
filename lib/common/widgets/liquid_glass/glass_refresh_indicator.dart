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
          painter: GlassShadowPainter(
            radius: radius,
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
          ),
          foregroundPainter: GlassRimPainter(
            radius: radius,
            opacity: 0.8,
            isDark: isDark,
          ),
          child: LiquidGlass(
            blurSigma: 3,
            refractionHeight: 12,
            refractionAmount: 14,
            saturation: 1.5,
            color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2.5,
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

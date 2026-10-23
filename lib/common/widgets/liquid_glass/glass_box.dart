import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A box of liquid glass floating over the page, with a shadow and a lit
/// rim: what the redesign's input boxes sit on, the reply box and the
/// danmaku box among them.
class GlassBox extends StatelessWidget {
  const GlassBox({super.key, required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final corner = Radius.circular(radius);
    return CustomPaint(
      painter: GlassShadowPainter(
        radius: corner,
        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
      ),
      foregroundPainter: GlassRimPainter(
        radius: corner,
        opacity: 0.75,
        isDark: isDark,
      ),
      child: LiquidGlass(
        radius: radius,
        blurSigma: 16,
        refractionHeight: 16,
        refractionAmount: 18,
        saturation: 1.5,
        color: colorScheme.surfaceContainer.withValues(alpha: 0.78),
        child: child,
      ),
    );
  }
}

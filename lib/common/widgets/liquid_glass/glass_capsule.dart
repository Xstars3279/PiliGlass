import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A capsule of the dock's glass, for the rows of controls at the top of a
/// page, e.g. the home tabs: the same tint, rim and shadow as the dock, so
/// the top of a page and its bottom read as one set.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    // the painters and the glass round off whatever the height
    return CustomPaint(
      painter: _StadiumShadow(
        Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
      ),
      foregroundPainter: _StadiumRim(isDark),
      child: LiquidGlass(
        blurSigma: 3,
        saturation: 1.5,
        color: colorScheme.surfaceContainer.withValues(alpha: 0.55),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _StadiumShadow extends CustomPainter {
  _StadiumShadow(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => GlassShadowPainter(
    radius: Radius.circular(size.height / 2),
    color: color,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(_StadiumShadow old) => old.color != color;
}

class _StadiumRim extends CustomPainter {
  _StadiumRim(this.isDark);

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) => GlassRimPainter(
    radius: Radius.circular(size.height / 2),
    opacity: 0.75,
    isDark: isDark,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(_StadiumRim old) => old.isDark != isDark;
}

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A panel floating over the page (UiGlass, G2), with a shadow, an outline
/// in the dark: what the redesign's input boxes sit on, the reply box and
/// the danmaku box among them. It carries text, so it is all but solid and
/// never bends what is behind it.
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
      painter: GlassShadowPainter.of(
        radius: corner,
        shadow: UiGlass.shadowIn(colorScheme, UiGlass.panelShadow),
      ),
      foregroundPainter: GlassRimPainter(
        radius: corner,
        opacity: 0,
        isDark: isDark,
        edge: UiGlass.edge(colorScheme),
      ),
      child: LiquidGlass(
        radius: radius,
        blurSigma: UiGlass.panelBlur,
        color: UiGlass.panel(colorScheme),
        child: child,
      ),
    );
  }
}

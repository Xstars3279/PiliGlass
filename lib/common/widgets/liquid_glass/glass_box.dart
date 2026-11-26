import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A panel floating over the page (UiGlass, G2), with a shadow, an outline
/// in the dark: what the redesign's input boxes sit on, the reply box and
/// the danmaku box among them. It carries text, so it stays all but solid
/// and only at 极致 bends what is behind it, as v0.1.4's panels did.
class GlassBox extends StatelessWidget {
  const GlassBox({super.key, required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final corner = Radius.circular(radius);
    return ListenableBuilder(
      listenable: UiGlass.revision,
      builder: (context, child) => CustomPaint(
        painter: GlassShadowPainter.of(
          radius: corner,
          shadow: UiGlass.shadowIn(colorScheme, UiGlass.panelShadow),
        ),
        foregroundPainter: GlassRimPainter(
          radius: corner,
          opacity: UiGlass.panelRim,
          isDark: isDark,
          edge: UiGlass.edge(colorScheme),
        ),
        child: LiquidGlass(
          radius: radius,
          blurSigma: UiGlass.panelBlur,
          refractionHeight: UiGlass.panelRefractionHeight,
          refractionAmount: UiGlass.panelRefractionAmount,
          saturation: UiGlass.saturation,
          color: UiGlass.panel(colorScheme),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

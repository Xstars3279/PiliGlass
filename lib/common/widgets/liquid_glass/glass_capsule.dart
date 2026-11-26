import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A capsule of the shell, as the dock is (UiGlass, G1), for the rows of
/// controls at the top of a page, e.g. the home tabs: the same color,
/// shadow and transparency as the dock, so the top of a page and its bottom
/// read as one set.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(4),
    this.refraction = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// over content that moves, e.g. a feed: bending it at the rim like the
  /// dock, where the shell is glass enough (极致)
  final bool refraction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    final content = Padding(padding: padding, child: child);
    // the painters and the glass round off whatever the height
    return ListenableBuilder(
      listenable: UiGlass.revision,
      builder: (context, child) {
        final lens = refraction && UiGlass.refraction;
        return CustomPaint(
          painter: _StadiumShadow(
            UiGlass.shadowIn(colorScheme, UiGlass.shellShadow),
          ),
          foregroundPainter: _StadiumRim(isDark, UiGlass.edge(colorScheme)),
          child: LiquidGlass(
            blurSigma: UiGlass.shellBlur,
            refractionHeight: lens ? 16 * UiGlass.shellRefractionScale : 0,
            refractionAmount: lens ? 18 * UiGlass.shellRefractionScale : 0,
            saturation: UiGlass.saturation,
            color: UiGlass.shell(colorScheme),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

class _StadiumShadow extends CustomPainter {
  _StadiumShadow(this.shadow);

  final BoxShadow? shadow;

  @override
  void paint(Canvas canvas, Size size) => GlassShadowPainter.of(
    radius: Radius.circular(size.height / 2),
    shadow: shadow,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(_StadiumShadow old) => old.shadow != shadow;
}

class _StadiumRim extends CustomPainter {
  _StadiumRim(this.isDark, this.edge);

  final bool isDark;
  final Color? edge;

  @override
  void paint(Canvas canvas, Size size) => GlassRimPainter(
    radius: Radius.circular(size.height / 2),
    opacity: UiGlass.rim,
    isDark: isDark,
    edge: edge,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(_StadiumRim old) =>
      old.isDark != isDark || old.edge != edge;
}

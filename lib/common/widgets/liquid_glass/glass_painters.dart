import 'package:material_ui/material_ui.dart';

/// A drop shadow drawn only outside the shape, so it does not darken the
/// translucent glass.
class GlassShadowPainter extends CustomPainter {
  GlassShadowPainter({
    required this.radius,
    required this.color,
    this.offset = const Offset(0, 2),
    this.sigma = 10,
  });

  /// [shadow] around the shape, or nothing for none, e.g. in the dark,
  /// see UiGlass.shadowIn
  GlassShadowPainter.of({required this.radius, required BoxShadow? shadow})
    : color = shadow?.color ?? const Color(0x00000000),
      offset = shadow?.offset ?? Offset.zero,
      sigma = shadow?.blurSigma ?? 0;

  final Radius radius;
  final Color color;
  final Offset offset;
  final double sigma;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas
      ..save()
      ..clipPath(
        Path()
          ..fillType = .evenOdd
          ..addRect((Offset.zero & size).inflate(40))
          ..addRRect(rrect),
      )
      ..drawRRect(
        rrect.shift(offset),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(.normal, sigma),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.sigma != sigma;
}

/// The specular rim: light from the top left and, weaker, the bottom right.
/// Optionally a glow under the finger, an inner shadow, and a plain [edge]
/// all round, the outline a floating surface has in the dark.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter({
    required this.radius,
    required this.opacity,
    required this.isDark,
    this.glow = 0,
    this.glowCenter = 0,
    this.innerShadow = 0,
    this.edge,
  });

  final Radius radius;
  final double opacity;
  final bool isDark;
  final double glow;
  final double glowCenter;
  final double innerShadow;
  final Color? edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, radius);

    if (glow > 0) {
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawCircle(
          Offset(glowCenter, size.height / 2),
          size.height,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Colors.white.withValues(
                      alpha: (isDark ? 0.08 : 0.15) * glow,
                    ),
                    Colors.white.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCircle(
                    center: Offset(glowCenter, size.height / 2),
                    radius: size.height,
                  ),
                ),
        )
        ..restore();
    }

    if (innerShadow > 0) {
      final width = 8 * innerShadow;
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRRect(
          rrect.inflate(width / 2),
          Paint()
            ..style = .stroke
            ..strokeWidth = width
            ..color = Colors.black.withValues(alpha: 0.15 * innerShadow)
            ..maskFilter = MaskFilter.blur(.normal, width / 2),
        )
        ..restore();
    }

    if (edge case final edge?) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = .stroke
          ..strokeWidth = isDark ? 1 : 0.8
          ..color = edge,
      );
    }

    if (opacity <= 0) return;
    final peak = (isDark ? 0.35 : 0.6) * opacity;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = .stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: .topLeft,
          end: .bottomRight,
          colors: [
            Colors.white.withValues(alpha: peak),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: peak * 0.5),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius ||
      old.opacity != opacity ||
      old.isDark != isDark ||
      old.glow != glow ||
      old.glowCenter != glowCenter ||
      old.innerShadow != innerShadow ||
      old.edge != edge;
}

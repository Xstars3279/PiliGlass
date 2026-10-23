import 'package:PiliPlus/common/motion/pressable_scale.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:material_ui/material_ui.dart';

/// A floating action button on liquid glass, like the dock's search
/// button: what every FloatingActionButton of the app becomes in the
/// redesign. Takes the parameters the app gives its buttons, and is the
/// plain FloatingActionButton where the redesign is off.
class RevampFab extends StatelessWidget {
  const RevampFab({
    super.key,
    required this.onPressed,
    this.child,
    this.tooltip,
    this.heroTag = const _DefaultHeroTag(),
  }) : label = null,
       icon = null;

  const RevampFab.extended({
    super.key,
    required this.onPressed,
    required Widget this.label,
    this.icon,
    this.tooltip,
    this.heroTag = const _DefaultHeroTag(),
  }) : child = null;

  final VoidCallback? onPressed;
  final Widget? child;
  final Widget? label;
  final Widget? icon;
  final String? tooltip;
  final Object? heroTag;

  bool get _extended => label != null;

  @override
  Widget build(BuildContext context) {
    if (!Revamp.enabled) {
      return _extended
          ? FloatingActionButton.extended(
              onPressed: onPressed,
              label: label!,
              icon: icon,
              tooltip: tooltip,
              heroTag: heroTag,
            )
          : FloatingActionButton(
              onPressed: onPressed,
              tooltip: tooltip,
              heroTag: heroTag,
              child: child,
            );
    }
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const size = 56.0;
    const radius = Radius.circular(size / 2);
    Widget content = IconTheme.merge(
      data: IconThemeData(color: colorScheme.primary, size: 24),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        child: _extended
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: .min,
                  spacing: 8,
                  children: [?icon, label!],
                ),
              )
            : Center(child: child),
      ),
    );
    content = SizedBox(
      height: size,
      width: _extended ? null : size,
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
          refractionHeight: 18,
          refractionAmount: 20,
          saturation: 1.5,
          color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
          child: content,
        ),
      ),
    );
    content = PressableScale(
      pressedScale: 0.9,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: GestureDetector(
          behavior: .opaque,
          onTap: onPressed,
          child: content,
        ),
      ),
    );
    if (tooltip != null) content = Tooltip(message: tooltip!, child: content);
    return content;
  }
}

/// FloatingActionButton's default hero tag is private; the glass button
/// flies no hero, so any default stands in for it.
class _DefaultHeroTag {
  const _DefaultHeroTag();
}

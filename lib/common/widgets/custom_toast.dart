import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class CustomToast extends StatelessWidget {
  const CustomToast(this.msg, {super.key});

  final String msg;

  static double toastOpacity = Pref.defaultToastOp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    // the redesign: a capsule of the level's glass, 36 high, that pops in
    // on a spring and follows 透明效果 like the dock
    if (Revamp.enabled && GlassFeatures.toast) {
      return Padding(
        padding: .only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + UiSpace.s24,
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 460),
          curve: SpringCurve(
            Springs.bouncy,
            const Duration(milliseconds: 460),
          ),
          builder: (context, t, child) =>
              Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            child: CustomPaint(
              painter: GlassShadowPainter.of(
                radius: const Radius.circular(18),
                shadow: UiGlass.shadowIn(
                  colorScheme,
                  UiGlass.shellShadow,
                ),
              ),
              foregroundPainter: GlassRimPainter(
                radius: const Radius.circular(18),
                opacity: UiGlass.rim * 0.7,
                isDark: colorScheme.brightness == .dark,
                edge: UiGlass.edge(colorScheme),
              ),
              child: LiquidGlass(
                radius: 18,
                blurSigma: UiGlass.shellBlur,
                refractionHeight: UiGlass.refraction ? 12 : 0,
                refractionAmount: UiGlass.refraction ? 14 : 0,
                saturation: UiGlass.saturation,
                color: UiGlass.input(colorScheme),
                // widthFactor 1, not Container's alignment: that one wraps
                // the child in an Align that takes the whole width the toast
                // host offers, and the capsule came out as a strip across
                // the screen
                child: SizedBox(
                  height: 36,
                  child: Padding(
                    padding: const .symmetric(horizontal: UiSpace.s16),
                    child: Align(
                      alignment: Alignment.center,
                      widthFactor: 1,
                      child: Text(
                        msg,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: UiType.label.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      margin: .only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 30,
      ),
      padding: const .symmetric(horizontal: 17, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: toastOpacity),
        borderRadius: const .all(.circular(20)),
      ),
      child: Text(
        msg,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget(this.msg, {super.key});

  ///loading msg
  final String msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const .symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: theme.dialogTheme.backgroundColor,
        borderRadius: const .all(.circular(15)),
      ),
      child: Column(
        spacing: 20,
        mainAxisSize: .min,
        children: [
          //loading animation
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(onSurfaceVariant),
          ),
          //msg
          Text(msg, style: TextStyle(color: onSurfaceVariant)),
        ],
      ),
    );
  }
}

class NotifyWarning extends StatelessWidget {
  const NotifyWarning(this.msg, {super.key});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(8)),
        color: theme.dialogTheme.backgroundColor,
      ),
      padding: const .symmetric(horizontal: 20, vertical: 10),
      child: Column(
        spacing: 5,
        mainAxisSize: .min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: onSurfaceVariant,
          ),
          Text(msg, style: TextStyle(color: onSurfaceVariant)),
        ],
      ),
    );
  }
}

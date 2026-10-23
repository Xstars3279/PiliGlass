import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class CustomToast extends StatelessWidget {
  const CustomToast(this.msg, {super.key});

  final String msg;

  static double toastOpacity = Pref.defaultToastOp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    // the redesign: a capsule of the dock's glass that pops in on a spring
    if (Revamp.enabled) {
      return Padding(
        padding: .only(bottom: MediaQuery.viewPaddingOf(context).bottom + 30),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 460),
          curve: SpringCurve(
            Springs.bouncy,
            const Duration(milliseconds: 460),
          ),
          builder: (context, t, child) =>
              Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          child: GlassCapsule(
            refraction: true,
            padding: const .symmetric(horizontal: 18, vertical: 11),
            child: Text(
              msg,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
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

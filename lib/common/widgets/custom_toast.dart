import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

class CustomToast extends StatelessWidget {
  const CustomToast(this.msg, {super.key});

  final String msg;

  static double toastOpacity = Pref.defaultToastOp;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    // the redesign: a solid capsule in the inverse surface, 36 high, that
    // pops in on a spring; never glass (11.5)
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
          child: Container(
            height: 36,
            padding: const .symmetric(horizontal: UiSpace.s16),
            decoration: ShapeDecoration(
              color: colorScheme.inverseSurface,
              shape: const StadiumBorder(),
            ),
            // widthFactor 1, not Container's alignment: that one wraps the
            // child in an Align that takes the whole width the toast host
            // offers, and the capsule came out as a strip across the screen
            child: Align(
              alignment: Alignment.center,
              widthFactor: 1,
              child: Text(
                msg,
                maxLines: 1,
                overflow: .ellipsis,
                style: UiType.label.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onInverseSurface,
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

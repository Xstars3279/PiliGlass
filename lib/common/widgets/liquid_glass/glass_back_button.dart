import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_icon_button.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_press.dart';
import 'package:material_ui/material_ui.dart';

/// The app's top-left back button: a round glass coin with the same swell
/// and rubber-band drag as the ⋯ buttons.
///
/// [GlassIconButton] draws the coin on a page. [overlay] instead uses the
/// smoked round of the player's controls, so it reads over a video or a
/// cover. [GlassBackButton.visual] is the coin alone, for a slot that already
/// owns the tap, as [BackButton] does when it builds [BackButtonIcon].
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    this.onTap,
    this.tooltip = '返回',
    this.icon = const Icon(Icons.arrow_back),
    this.size = 36,
    this.tapSize = 44,
    this.iconSize,
    this.color,
    this.overlay = false,
    this.semanticLabel,
    this.enabled = true,
  }) : _visual = false;

  /// The coin without a tap of its own, for a parent that already handles
  /// one. It keeps the press, and stays out of the semantics tree so the
  /// parent's label is not read twice.
  const GlassBackButton.visual({
    super.key,
    this.icon = const Icon(Icons.arrow_back),
    this.size = 36,
    this.iconSize,
    this.color,
    this.overlay = false,
  }) : onTap = null,
       tooltip = null,
       tapSize = size,
       semanticLabel = null,
       enabled = true,
       _visual = true;

  final VoidCallback? onTap;
  final String? tooltip;
  final Widget icon;
  final double size;
  final double tapSize;
  final double? iconSize;
  final Color? color;

  /// Over a video or a cover: a black 32% round with a white icon, as the
  /// player's other controls, instead of the page's light glass coin.
  final bool overlay;

  final String? semanticLabel;
  final bool enabled;
  final bool _visual;

  @override
  Widget build(BuildContext context) {
    if (_visual) {
      return ExcludeSemantics(child: _coin(context));
    }
    if (overlay) {
      final message = semanticLabel ?? tooltip ?? '返回';
      return Semantics(
        button: true,
        label: message,
        enabled: enabled,
        child: Tooltip(
          message: tooltip ?? '返回',
          child: LiquidPress(
            enabled: enabled,
            maxGrowth: 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled
                  ? (onTap ?? () => Navigator.maybePop(context))
                  : null,
              child: SizedBox.square(
                dimension: math.max(size, tapSize),
                child: Center(child: _coin(context)),
              ),
            ),
          ),
        ),
      );
    }
    return GlassIconButton(
      icon: icon,
      onTap: enabled ? (onTap ?? () => Navigator.maybePop(context)) : null,
      tooltip: semanticLabel ?? tooltip,
      size: size,
      tapSize: tapSize,
      iconSize: iconSize,
      color: color,
      enabled: enabled,
    );
  }

  Widget _coin(BuildContext context) {
    if (!overlay) {
      return GlassIconButton(
        icon: icon,
        size: size,
        tapSize: size,
        iconSize: iconSize,
        color: color ?? IconTheme.of(context).color,
      );
    }
    final foreground = color ?? Colors.white;
    return CustomPaint(
      foregroundPainter: GlassRimPainter(
        radius: Radius.circular(size / 2),
        opacity: 0.5,
        isDark: true,
        edge: Colors.white.withValues(alpha: 0.16),
      ),
      child: DecoratedBox(
        decoration: const ShapeDecoration(
          color: Color(0x52000000),
          shape: CircleBorder(),
        ),
        child: SizedBox.square(
          dimension: size,
          child: IconTheme.merge(
            data: IconThemeData(
              size: iconSize ?? size * 0.5,
              color: foreground,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// Styles the implicit [BackButton] of every app bar in a page as a
/// [GlassBackButton] coin. The [BackButton] keeps the tap, tooltip and
/// semantics; only its icon is replaced.
const glassBackActionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _buildBackIcon,
);

const _appBarCoinSize = 40.0;

Widget _buildBackIcon(BuildContext context) {
  final iconTheme = IconTheme.of(context);
  return OverflowBox(
    minWidth: _appBarCoinSize,
    maxWidth: _appBarCoinSize,
    minHeight: _appBarCoinSize,
    maxHeight: _appBarCoinSize,
    child: GlassBackButton.visual(
      icon: Icon(_backIconData(context)),
      size: 36,
      iconSize: 20,
      color: iconTheme.color,
    ),
  );
}

IconData _backIconData(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
      ? Icons.arrow_back_ios_new_rounded
      : Icons.arrow_back;
}

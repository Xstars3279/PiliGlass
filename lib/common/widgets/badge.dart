import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

class PBadge extends StatelessWidget {
  final String? text;

  final bool isStack;
  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final EdgeInsets? padding;

  final PBadgeType type;
  final PBadgeSize size;

  final double fontSize;
  final bool isBold;
  final double? textScaleFactor;

  const PBadge({
    super.key,
    required this.text,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.type = PBadgeType.primary,
    this.size = PBadgeSize.medium,
    this.isStack = true,
    this.fontSize = 11,
    this.isBold = true,
    this.textScaleFactor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isNullOrEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = ColorScheme.of(context);

    final Color bgColor;
    final Color color;
    Color borderColor = Colors.transparent;

    switch (type) {
      case PBadgeType.primary:
        bgColor = colorScheme.primary;
        color = colorScheme.onPrimary;
      case PBadgeType.secondary:
        bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.5);
        color = colorScheme.onSecondaryContainer;
      case PBadgeType.gray:
        bgColor = Colors.black45;
        color = Colors.white;
      case PBadgeType.error:
        if (colorScheme.isDark) {
          bgColor = colorScheme.errorContainer;
          color = colorScheme.onErrorContainer;
        } else {
          bgColor = colorScheme.error;
          color = colorScheme.onError;
        }
      case PBadgeType.line_primary:
        color = colorScheme.primary;
        bgColor = Colors.transparent;
        borderColor = colorScheme.primary;
      case PBadgeType.line_secondary:
        color = colorScheme.secondary;
        bgColor = Colors.transparent;
        borderColor = colorScheme.secondary;
      case PBadgeType.free:
        bgColor = colorScheme.freeColor;
        color = Colors.white;
      case PBadgeType.shop:
        bgColor = colorScheme.secondaryContainer.withValues(alpha: 0.5);
        color = colorScheme.onSurfaceVariant;
    }

    if (Revamp.enabled) {
      return _revamp(colorScheme);
    }

    const defPaddingStyle = EdgeInsets.symmetric(vertical: 2, horizontal: 3);
    final BorderRadius br = size == .small
        ? const .all(.circular(3))
        : const .all(.circular(4));

    Widget content = Container(
      padding: padding ?? defPaddingStyle,
      decoration: BoxDecoration(
        borderRadius: br,
        color: bgColor,
        border: .all(color: borderColor),
      ),
      child: Text(
        text!,
        textScaler: textScaleFactor != null ? .linear(textScaleFactor!) : null,
        style: TextStyle(
          height: 1,
          fontSize: fontSize,
          color: color,
          fontWeight: isBold ? FontWeight.bold : null,
        ),
        strutStyle: StrutStyle(
          leading: 0,
          height: 1,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : null,
        ),
      ),
    );
    if (isStack) {
      return Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: content,
      );
    } else {
      return content;
    }
  }

  /// The redesign's badges: on a cover, white on black 50%; beside text, a
  /// neutral tag, gray on the gray of a block in a block. The accent is not
  /// for labels; red stays for what is red (error), and the free badge
  /// keeps its color.
  Widget _revamp(ColorScheme colorScheme) {
    final (Color bg, Color fg) = switch (type) {
      PBadgeType.error =>
        colorScheme.isDark
            ? (colorScheme.errorContainer, colorScheme.onErrorContainer)
            : (colorScheme.error, colorScheme.onError),
      PBadgeType.free => (colorScheme.freeColor, Colors.white),
      _ when isStack => (const Color(0x80000000), Colors.white),
      PBadgeType.gray => (const Color(0x80000000), Colors.white),
      _ => (colorScheme.surfaceContainerHigh, colorScheme.onSurfaceVariant),
    };
    Widget content = Container(
      padding:
          padding ??
          (isStack
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : const EdgeInsets.symmetric(
                  horizontal: UiSpace.s8,
                  vertical: UiSpace.s4,
                )),
      decoration: ShapeDecoration(
        color: bg,
        shape: Revamp.rounded(UiRadius.small),
      ),
      child: Text(
        text!,
        textScaler: textScaleFactor != null ? .linear(textScaleFactor!) : null,
        style: UiType.label.copyWith(height: 1, color: fg),
        strutStyle: const StrutStyle(leading: 0, height: 1, fontSize: 11),
      ),
    );
    if (isStack) {
      content = Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: content,
      );
    }
    return content;
  }
}

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:material_ui/material_ui.dart';

class ActionRowLineItem extends StatelessWidget {
  const ActionRowLineItem({
    super.key,
    required this.selectStatus,
    this.onTap,
    this.text,
    this.iconData,
    this.icon,
  });
  final bool selectStatus;
  final VoidCallback? onTap;
  final String? text;
  final IconData? iconData;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final revamp = Revamp.enabled;
    final bg = selectStatus
        ? colorScheme.secondaryContainer
        : revamp
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : null;
    final fg = selectStatus
        ? colorScheme.onSecondaryContainer
        : revamp
        ? colorScheme.onSurfaceVariant
        : colorScheme.outline;
    final label = text?.trim() ?? '';
    return Material(
      color: bg,
      type: bg != null ? MaterialType.canvas : MaterialType.transparency,
      borderRadius: const BorderRadius.all(Radius.circular(30)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        onTap: () {
          feedBack();
          onTap?.call();
        },
        child: Container(
          padding: revamp
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 7)
              : const EdgeInsets.fromLTRB(13, 5.5, 13, 4.5),
          decoration: revamp
              ? null
              : BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(30)),
                  border: Border.all(
                    color: selectStatus
                        ? Colors.transparent
                        : colorScheme.secondaryContainer,
                  ),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: revamp && (iconData != null || icon != null) ? 5 : 0,
            children: [
              if (iconData != null)
                Icon(
                  iconData,
                  size: revamp ? 15 : 13,
                  color: fg,
                )
              else
                ?icon,
              Text(
                revamp ? label : text!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: revamp && selectStatus ? FontWeight.w500 : null,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionIconItem extends StatelessWidget {
  const ActionIconItem({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.iconData,
  });

  final String tooltip;
  final VoidCallback onTap;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        type: .transparency,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => {
            feedBack(),
            onTap(),
          },
          child: Container(
            padding: const .all(5),
            decoration: BoxDecoration(
              shape: .circle,
              border: Border.all(color: colorScheme.secondaryContainer),
            ),
            child: Icon(
              iconData,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

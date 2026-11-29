import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_menu.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

typedef PopupMenuItemSelected<T> = void Function(
  T value,
  VoidCallback setState,
);

List<PopupMenuEntry<T>> enumItemBuilder<T extends EnumWithLabel>(
  Iterable<T> items,
) => items.map((e) => PopupMenuItem(value: e, child: Text(e.label))).toList();

enum DescPosType { subtitle, title, trailing }

class PopupListTile<T> extends StatefulWidget {
  const PopupListTile({
    super.key,
    this.dense,
    this.safeArea = true,
    this.enabled = true,
    this.leading,
    this.useRevampLeading = true,
    required this.title,
    this.descPosType = .subtitle,
    required this.value,
    required this.itemBuilder,
    required this.onSelected,
    this.titleStyle,
    this.descStyle,
  });

  final bool? dense;
  final bool safeArea;
  final bool enabled;
  final Widget? leading;
  final bool useRevampLeading;
  final Widget title;

  final DescPosType descPosType;
  final ValueGetter<(T, String)> value;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final TextStyle? titleStyle;
  final TextStyle? descStyle;

  @override
  State<PopupListTile<T>> createState() => _PopupListTileState<T>();
}

class _PopupListTileState<T> extends State<PopupListTile<T>> {
  final _key = PlatformUtils.isDesktop ? null : GlobalKey();
  VoidCallback? _openGlassMenu;

  void _showButtonMenu(TapUpDetails details, T value) {
    final thisOffset = details.globalPosition - details.localPosition;
    final double dx;
    if (PlatformUtils.isDesktop) {
      dx = details.globalPosition.dx + 1;
    } else {
      final thisBox = context.findRenderObject();
      final titleBox = _key!.currentContext!.findRenderObject() as RenderBox;
      final titleOffset = titleBox.localToGlobal(.zero, ancestor: thisBox);
      dx = thisOffset.dx + titleOffset.dx;
    }
    showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(dx, thisOffset.dy + 5, dx, 0),
      items: widget.itemBuilder(context),
      initialValue: value,
      requestFocus: false,
    ).then<void>((newValue) {
      if (!mounted) return;
      if (newValue == null || newValue == value) return;
      widget.onSelected(newValue, _refresh);
    });
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (value, descStr) = widget.value();
    Widget title = KeyedSubtree(key: _key, child: widget.title);
    Widget? subtitle;
    Widget? trailing;
    final desc = Text(
      descStr,
      style: (widget.descStyle ?? theme.textTheme.labelMedium!).copyWith(
        color: widget.enabled
            ? theme.colorScheme.secondary
            : theme.disabledColor,
      ),
    );
    if (!Revamp.enabled || !widget.enabled) {
      switch (widget.descPosType) {
        case DescPosType.subtitle:
          subtitle = desc;
        case DescPosType.title:
          title = Row(
            spacing: 12,
            mainAxisSize: .min,
            children: [title, desc],
          );
        case DescPosType.trailing:
          trailing = desc;
      }
      return ListTile(
        dense: widget.dense,
        safeArea: widget.safeArea,
        enabled: widget.enabled,
        onTapUp: widget.enabled
            ? (details) => _showButtonMenu(details, value)
            : null,
        leading: widget.useRevampLeading
            ? revampLeading(widget.leading)
            : widget.leading,
        title: title,
        titleTextStyle: widget.titleStyle ?? theme.textTheme.titleMedium,
        subtitle: subtitle,
        trailing: trailing,
      );
    }

    final anchorWidget = GlassPopupAnchor<T>(
      alignEnd: true,
      minWidth: 160,
      itemBuilder: (context) {
        final colorScheme = ColorScheme.of(context);
        return widget.itemBuilder(context).map((entry) {
          if (entry is PopupMenuItem<T>) {
            final itemVal = entry.value;
            final isSelected = itemVal == value;
            return PopupMenuItem<T>(
              value: itemVal,
              enabled: entry.enabled,
              height: entry.height,
              padding: entry.padding,
              onTap: () {
                if (itemVal != null && itemVal != value) {
                  widget.onSelected(itemVal, _refresh);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: entry.child ?? const SizedBox.shrink()),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                ],
              ),
            );
          }
          return entry;
        }).toList();
      },
      targetBuilder: (open) {
        _openGlassMenu = open;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                descStr,
                style: (widget.descStyle ?? theme.textTheme.bodyMedium!)
                    .copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        );
      },
    );

    return ListTile(
      dense: widget.dense,
      safeArea: widget.safeArea,
      enabled: widget.enabled,
      onTap: () => _openGlassMenu?.call(),
      leading: widget.useRevampLeading
          ? revampLeading(widget.leading)
          : widget.leading,
      title: title,
      titleTextStyle: widget.titleStyle ?? theme.textTheme.titleMedium,
      trailing: anchorWidget,
    );
  }
}

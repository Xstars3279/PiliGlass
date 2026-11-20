import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One row of a menu over the video: its label, and what choosing it does.
class PlayerMenuRow {
  const PlayerMenuRow({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;
}

/// A control over the video that opens a list above itself, e.g. 倍速 or 清晰度
/// (7.3): black 72% over a blur, corners 24, [width] wide, rows of 48, the
/// chosen one 600 in the accent on a white 12% block. The menu keeps 8 clear of
/// the button, follows it wherever the player is, and when the rows do not fit
/// between the button and the top of the screen it stops below the bar up there
/// and scrolls inside itself.
class PlayerMenuButton extends StatefulWidget {
  const PlayerMenuButton({
    super.key,
    required this.buildRows,
    required this.child,
    this.width = 112,
  });

  /// the rows, read when the menu opens
  final List<PlayerMenuRow> Function() buildRows;

  final Widget child;
  final double width;

  @override
  State<PlayerMenuButton> createState() => _PlayerMenuButtonState();
}

class _PlayerMenuButtonState extends State<PlayerMenuButton> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _open() {
    if (_entry != null) {
      _close();
      return;
    }
    final rows = widget.buildRows();
    final box = context.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    if (rows.isEmpty || box is! RenderBox || !box.hasSize) return;

    final media = MediaQuery.of(context);
    final colorScheme = ColorScheme.of(context);
    final top = box.localToGlobal(Offset.zero);
    final bottom = box.localToGlobal(box.size.bottomRight(Offset.zero));
    final centre = (top.dx + bottom.dx) / 2;
    final screen = media.size;

    // how tall it may be: the rows, or the room above the button
    const gap = UiSpace.s8;
    final room = (top.dy - gap - media.padding.top - UiSpace.s24).clamp(
      48.0,
      double.infinity,
    );
    final full = Revamp.playerMenuHeight(rows.length);
    final height = math.min(full, room);

    // it is centred on the button, as far as the screen's edges allow
    final half = widget.width / 2;
    final dx = centre - half < UiSpace.s16
        ? UiSpace.s16 - (centre - half)
        : centre + half > screen.width - UiSpace.s16
        ? screen.width - UiSpace.s16 - (centre + half)
        : 0.0;

    late final OverlayEntry entry;
    var closed = false;

    void close() {
      if (closed) return;
      closed = true;
      _close();
    }

    entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // a tap anywhere else closes it
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: Offset(dx, -gap),
            child: SizedBox(
              width: widget.width,
              height: height,
              child: _Panel(
                colorScheme: colorScheme,
                rows: rows,
                onChosen: close,
              ),
            ),
          ),
        ],
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _open,
        child: widget.child,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.colorScheme,
    required this.rows,
    required this.onChosen,
  });

  final ColorScheme colorScheme;
  final List<PlayerMenuRow> rows;
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * UiSpace.s8),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Revamp.menuRadius),
        child: BackdropFilter(
          // the picture still shows, blurred, through the black
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Revamp.playerMenuColor),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: UiSpace.s8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows)
                    _Row(
                      colorScheme: colorScheme,
                      row: row,
                      onChosen: onChosen,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.colorScheme,
    required this.row,
    required this.onChosen,
  });

  final ColorScheme colorScheme;
  final PlayerMenuRow row;
  final VoidCallback onChosen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: row.enabled
          ? () {
              onChosen();
              row.onTap();
            }
          : null,
      child: Revamp.playerMenuItem(
        colorScheme,
        label: row.label,
        selected: row.selected,
        enabled: row.enabled,
      ),
    );
  }
}

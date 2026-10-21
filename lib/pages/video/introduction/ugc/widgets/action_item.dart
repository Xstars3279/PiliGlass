import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/custom_arc.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:material_ui/material_ui.dart';

class ActionItem extends StatelessWidget {
  const ActionItem({
    super.key,
    required this.icon,
    this.selectIcon,
    this.onTap,
    this.onLongPress,
    this.text,
    this.selectStatus = false,
    required this.semanticsLabel,
    this.expand = true,
    this.animation,
    this.onStartTriple,
    this.onCancelTriple,
  }) : assert(!selectStatus || selectIcon != null),
       _isThumbsUp = onStartTriple != null;

  final Icon icon;
  final Icon? selectIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? text;
  final bool selectStatus;
  final String semanticsLabel;
  final bool expand;
  final Animation<double>? animation;
  final VoidCallback? onStartTriple;
  final void Function([bool])? onCancelTriple;
  final bool _isThumbsUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    late final primary = !expand && colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    Widget child = _PopIcon(
      selected: selectStatus,
      color: primary,
      // swells while the like button is held for a triple
      hold: animation,
      child: Icon(
        selectStatus ? selectIcon!.icon! : icon.icon,
        size: 22,
        color: selectStatus ? primary : icon.color ?? colorScheme.outline,
        semanticLabel: semanticsLabel,
      ),
    );

    if (animation != null) {
      child = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: animation!,
            builder: (context, child) =>
                Arc(size: 32, color: primary, progress: -animation!.value),
          ),
          child,
        ],
      );
    } else {
      child = SizedBox.square(dimension: 32, child: child);
    }

    child = Material(
      type: .transparency,
      child: InkWell(
        borderRadius: const .all(.circular(6)),
        onTap: _isThumbsUp ? null : onTap,
        onLongPress: _isThumbsUp ? null : onLongPress,
        onSecondaryTap: PlatformUtils.isMobile || _isThumbsUp
            ? null
            : onLongPress,
        onTapDown: _isThumbsUp ? (_) => onStartTriple!() : null,
        onTapUp: _isThumbsUp ? (_) => onCancelTriple!(true) : null,
        onTapCancel: _isThumbsUp ? onCancelTriple : null,
        child: expand
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [child, _buildText(theme)],
              )
            : child,
      ),
    );
    return expand ? Expanded(child: child) : child;
  }

  Widget _buildText(ThemeData theme) {
    final hasText = text != null;
    final child = Text(
      hasText ? text! : '-',
      key: hasText ? ValueKey(text!) : null,
      style: TextStyle(
        color: selectStatus
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        fontSize: theme.textTheme.labelSmall!.fontSize,
      ),
    );
    if (hasText) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: child,
      );
    }
    return child;
  }
}

/// The icon pops with a little burst when it turns on, and dips when it
/// turns off.
class _PopIcon extends StatefulWidget {
  const _PopIcon({
    required this.selected,
    required this.color,
    required this.child,
    this.hold,
  });

  final bool selected;
  final Color color;
  final Widget child;
  final Animation<double>? hold;

  @override
  State<_PopIcon> createState() => _PopIconState();
}

class _PopIconState extends State<_PopIcon> with TickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  late final _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  static final _popSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 0.35,
  );

  @override
  void didUpdateWidget(_PopIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected == oldWidget.selected) return;
    if (widget.selected) {
      // an upward kick: it swells to about 1.3x and bounces back
      _scale.animateWith(
        SpringSimulation(_popSpring, _scale.value, 1, 10),
      );
      _burst.forward(from: 0);
    } else {
      _scale.animateWith(SpringSimulation(_popSpring, _scale.value, 1, -6));
    }
  }

  @override
  void dispose() {
    _scale.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hold = widget.hold;
    return CustomPaint(
      foregroundPainter: _BurstPainter(_burst, widget.color),
      child: AnimatedBuilder(
        animation: hold == null ? _scale : Listenable.merge([_scale, hold]),
        builder: (context, child) => Transform.scale(
          scale: _scale.value * (1 + 0.15 * (hold?.value ?? 0)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Eight dots flying out from the icon and fading.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.animation, this.color) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;

  static const _count = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t == 0 || t == 1) return;
    final eased = Curves.easeOutCubic.transform(t);
    final center = size.center(Offset.zero);
    final distance = size.shortestSide * (0.45 + 0.6 * eased);
    final paint = Paint()..color = color.withValues(alpha: 1 - t);
    for (var i = 0; i < _count; i++) {
      final angle = i * 2 * math.pi / _count - math.pi / 2;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        2.6 * (1 - t),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.animation != animation;
}

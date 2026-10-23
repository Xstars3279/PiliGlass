import 'package:PiliPlus/common/motion/springs.dart';
import 'package:material_ui/material_ui.dart';

/// The redesign's switch: a white thumb on a track that fills with the
/// primary color. The thumb springs to its side and, like jelly, stretches
/// while it is held.
class RevampSwitch extends StatefulWidget {
  const RevampSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const width = 46.0;
  static const height = 28.0;

  @override
  State<RevampSwitch> createState() => _RevampSwitchState();
}

class _RevampSwitchState extends State<RevampSwitch>
    with TickerProviderStateMixin {
  static final _move = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: 0.35,
  );

  /// 0 off .. 1 on, past either end while it bounces
  late final _position = SpringFollower(
    vsync: this,
    value: widget.value ? 1 : 0,
    spring: _move,
  );

  /// 0 .. 1 while held: the thumb stretches
  late final _press = SpringFollower(
    vsync: this,
    value: 0,
    spring: Springs.snappy,
  );

  @override
  void didUpdateWidget(RevampSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _position.animateTo(widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onChanged != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      child: GestureDetector(
        behavior: .opaque,
        onTapDown: _enabled ? (_) => _press.animateTo(1) : null,
        onTapUp: _enabled ? (_) => _press.animateTo(0) : null,
        onTapCancel: () => _press.animateTo(0),
        onTap: _enabled ? () => widget.onChanged!(!widget.value) : null,
        child: SizedBox(
          width: RevampSwitch.width,
          height: RevampSwitch.height,
          child: CustomPaint(
            painter: _SwitchPainter(
              position: _position,
              press: _press,
              on: colorScheme.primary,
              off: colorScheme.surfaceContainerHighest,
              enabled: _enabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchPainter extends CustomPainter {
  _SwitchPainter({
    required this.position,
    required this.press,
    required this.on,
    required this.off,
    required this.enabled,
  }) : super(repaint: Listenable.merge([position, press]));

  final SpringFollower position;
  final SpringFollower press;
  final Color on;
  final Color off;
  final bool enabled;

  static const _inset = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = position.value;
    final fill = Color.lerp(off, on, t.clamp(0.0, 1.0))!;
    final alpha = enabled ? 1.0 : 0.45;
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = fill.withValues(alpha: fill.a * alpha),
    );

    final d = size.height - _inset * 2;
    // held, the thumb grows wider towards the middle
    final stretch = d * 0.3 * press.value.clamp(0.0, 1.0);
    final travel = size.width - _inset * 2 - d;
    // past an end, the thumb squashes against the edge instead of leaving
    // the track
    final tc = t.clamp(0.0, 1.0);
    final squash = ((t - tc).abs() * travel).clamp(0.0, d * 0.3);
    var left = _inset + travel * tc - stretch * tc;
    if (t > 1) left += squash;
    final thumb = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, _inset, d + stretch - squash, d),
      Radius.circular(d / 2),
    );
    canvas
      ..drawRRect(
        thumb.shift(const Offset(0, 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18 * alpha)
          ..maskFilter = const MaskFilter.blur(.normal, 2),
      )
      ..drawRRect(
        thumb,
        Paint()..color = Colors.white.withValues(alpha: enabled ? 1 : 0.8),
      );
  }

  @override
  bool shouldRepaint(_SwitchPainter old) =>
      old.on != on || old.off != off || old.enabled != enabled;
}

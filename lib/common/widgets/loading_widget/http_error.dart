import 'dart:math' as math;

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class HttpError extends StatelessWidget {
  const HttpError({
    super.key,
    this.isSliver = true,
    this.errMsg,
    this.onReload,
    this.btnText,
    this.safeArea = true,
  });

  final bool isSliver;
  final String? errMsg;
  final VoidCallback? onReload;
  final String? btnText;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Column(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        const SizedBox(height: 40),
        if (Revamp.enabled)
          const _ExpressiveEmptyBadge()
        else
          SvgPicture.asset(Assets.error, height: 200),
        const SizedBox(height: 24),
        Padding(
          padding: const .symmetric(horizontal: 16, vertical: 5),
          child: SelectionText(
            errMsg ?? '没有数据',
            textAlign: .center,
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (onReload != null)
          FilledButton.tonal(
            onPressed: onReload,
            style: FilledButton.styleFrom(
              tapTargetSize: .padded,
              backgroundColor: theme.colorScheme.primary.withAlpha(20),
            ),
            child: Text(
              btnText ?? '点击重试',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        if (safeArea)
          SizedBox(height: 40 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );

    return isSliver
        ? SliverToBoxAdapter(child: child)
        : SizedBox(width: double.infinity, child: child);
  }
}

/// Modern Material 3 Expressive scalloped-badge empty state illustration.
class _ExpressiveEmptyBadge extends StatelessWidget {
  const _ExpressiveEmptyBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 176,
      height: 152,
      child: CustomPaint(
        painter: _ScallopBadgePainter(
          badgeColor: colorScheme.primaryContainer.withValues(alpha: 0.7),
          dotColor: colorScheme.tertiary,
          ringColor: colorScheme.primary,
          starColor: colorScheme.secondary,
        ),
        child: Center(
          child: Icon(
            Icons.inbox_rounded,
            size: 54,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ScallopBadgePainter extends CustomPainter {
  const _ScallopBadgePainter({
    required this.badgeColor,
    required this.dotColor,
    required this.ringColor,
    required this.starColor,
  });

  final Color badgeColor;
  final Color dotColor;
  final Color ringColor;
  final Color starColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const lobes = 12;
    const outerR = 62.0;
    const innerR = 54.0;
    final path = Path();
    const steps = lobes * 8;
    for (int i = 0; i <= steps; i++) {
      final a = (i / steps) * math.pi * 2;
      final r = (outerR + innerR) / 2 +
          ((outerR - innerR) / 2) * math.cos(lobes * a);
      final pt = Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();

    // Soft 4-point blob at bottom-left
    final blobCenter = Offset(center.dx - 52, center.dy + 44);
    final blob = Path();
    for (int i = 0; i <= 32; i++) {
      final a = (i / 32) * math.pi * 2;
      final r = 8.5 + 2.5 * math.cos(4 * a + 0.6);
      final pt = Offset(
        blobCenter.dx + r * math.cos(a),
        blobCenter.dy + r * math.sin(a),
      );
      if (i == 0) {
        blob.moveTo(pt.dx, pt.dy);
      } else {
        blob.lineTo(pt.dx, pt.dy);
      }
    }
    blob.close();

    canvas
      ..drawPath(path, Paint()..color = badgeColor)
      ..drawCircle(
        Offset(center.dx - 64, center.dy - 30),
        4.5,
        Paint()..color = dotColor,
      )
      ..drawCircle(
        Offset(center.dx + 68, center.dy + 16),
        5.5,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      )
      ..drawPath(blob, Paint()..color = starColor.withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(_ScallopBadgePainter oldDelegate) =>
      badgeColor != oldDelegate.badgeColor ||
      dotColor != oldDelegate.dotColor ||
      ringColor != oldDelegate.ringColor ||
      starColor != oldDelegate.starColor;
}

import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:flutter/widgets.dart';

Widget fromHero({
  required Object tag,
  required Widget child,
}) => Hero(
  tag: tag,
  createRectTween: createEndRectTween,
  child: child,
);

RectTween createEndRectTween(Rect? begin, Rect? end) {
  if (begin != null && end != null) {
    final endWidth = end.width;
    final endHeight = end.height;
    // TODO: use real image rect
    final beginRect = Rect.fromLTWH(
      begin.left + (begin.width - endWidth) / 2,
      begin.top + (begin.height - endHeight) / 2,
      endWidth,
      endHeight,
    );
    return Revamp.enabled
        ? SpringRectTween(begin: beginRect, end: end)
        : RectTween(begin: beginRect, end: end);
  }
  return Revamp.enabled
      ? SpringRectTween(begin: begin, end: end)
      : RectTween(begin: begin, end: end);
}

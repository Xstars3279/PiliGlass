import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/skeleton/skeleton.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

class VideoCardVSkeleton extends StatelessWidget {
  const VideoCardVSkeleton({super.key});

  /// The redesigned card's shape: a fully rounded cover, two title lines
  /// and the UP line, with rounded ends.
  Widget _revamp(Color color) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
      ),
    );
    return Skeleton(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AspectRatio(
            aspectRatio: Style.aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const .all(.circular(16)),
              ),
            ),
          ),
          Padding(
            padding: const .fromLTRB(2, 10, 2, 0),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 7,
              children: [
                bar(double.infinity, 13),
                bar(110, 13),
                const SizedBox(height: 1),
                bar(70, 11),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = ColorScheme.of(context).onInverseSurface;
    if (Revamp.enabled) return _revamp(color);
    return Skeleton(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AspectRatio(
            aspectRatio: Style.aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: const .vertical(top: Style.imgRadius),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const .fromLTRB(4, 5, 6, 6),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .spaceBetween,
                children: [
                  Container(width: 200, height: 13, color: color),
                  Container(
                    height: 13,
                    width: 140,
                    color: color,
                    margin: const .only(top: 5),
                  ),
                  const Spacer(),
                  Row(
                    spacing: 8,
                    children: [
                      Container(
                        height: 11,
                        color: color,
                        width: 40,
                      ),
                      Container(
                        height: 11,
                        color: color,
                        width: 40,
                      ),
                    ],
                  ),
                  Container(
                    height: 11,
                    width: 75,
                    color: color,
                    margin: const .only(top: 5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

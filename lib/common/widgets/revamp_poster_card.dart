import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

/// A 番剧 poster in the redesign's look, as the video cards: no card box,
/// the 3:4 poster with its corners rounded like a video's cover, the
/// bottom label on a scrim, the text directly on the page; it dips when
/// pressed and rises in with its list. The four 番剧 cards each hand over
/// to it while the redesign is on.
///
/// The grids leave room under the poster for a line of title and a line of
/// [subtitle], so the title takes [titleLines] only where nothing follows.
class RevampPosterCard extends StatelessWidget {
  const RevampPosterCard({
    super.key,
    required this.cover,
    required this.title,
    this.subtitle,
    this.badge,
    this.label,
    this.titleLines = 1,
    required this.onTap,
    this.onLongPress,
  });

  final String? cover;
  final String title;
  final String? subtitle;

  /// e.g. 会员专享, at the top right in its color
  final String? badge;

  /// e.g. the update time, white on the scrim at the bottom
  final String? label;
  final int titleLines;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const _radius = BorderRadius.all(Radius.circular(Revamp.coverRadius));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Revamp.pressable(
      Material(
        type: .transparency,
        child: InkWell(
          borderRadius: _radius,
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AspectRatio(
                aspectRatio: Style.aspectRatio3x4,
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _poster(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const .fromLTRB(2, 6, 2, 2),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        title,
                        maxLines: titleLines,
                        overflow: .ellipsis,
                        style: const TextStyle(height: 1.35),
                      ),
                      if (subtitle?.isNotEmpty == true)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: TextStyle(
                            fontSize: theme.textTheme.labelMedium!.fontSize,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster(double width, double height) {
    final label = this.label;
    final hasLabel = label?.isNotEmpty == true;
    return Revamp.clip(
      radius: _radius,
      child: Stack(
        fit: .expand,
        children: [
          NetworkImgLayer(
            src: cover,
            width: width,
            height: height,
            borderRadius: BorderRadius.zero,
          ),
          if (hasLabel) ...[
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: .topCenter,
                    end: .bottomCenter,
                    colors: [Color(0x00000000), Color(0x8C000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Text(
                label!,
                maxLines: 1,
                overflow: .ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: .w600,
                ),
              ),
            ),
          ],
          if (badge?.isNotEmpty == true)
            PBadge(text: badge, top: 6, right: 6, bottom: null, left: null),
        ],
      ),
    );
  }
}

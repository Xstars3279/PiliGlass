import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/motion/cover_hero.dart';
import 'package:PiliPlus/common/motion/pressable_scale.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  Future<void> onPushDetail() async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem is RcmdVideoItemAppModel) {
          if (videoItem.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
            extraArguments: {'coverHero': coverHeroTag(videoItem)},
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  /// rises in when its list loads, see [RiseIn]
  @override
  Widget build(BuildContext context) =>
      Revamp.enabled ? RiseIn(child: _build(context)) : _build(context);

  Widget _build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    return PressableScale(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // no card box: the cover and the text sit directly on the page
          Material(
            type: .transparency,
            child: InkWell(
              onTap: PressableScale.delayTap(onPushDetail),
              onLongPress: onLongPress,
              onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
              borderRadius: _coverRadius,
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AspectRatio(
                    aspectRatio: Style.aspectRatio,
                    child: LayoutBuilder(
                      builder: (context, boxConstraints) => _cover(
                        boxConstraints.maxWidth,
                        boxConstraints.maxHeight,
                      ),
                    ),
                  ),
                  content(context),
                ],
              ),
            ),
          ),
          if (videoItem.goto == 'av')
            Positioned(
              right: -5,
              bottom: -2,
              width: 29,
              height: 29,
              child: VideoPopupMenu(
                iconSize: 17,
                videoItem: videoItem,
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
  }

  static const _coverRadius = BorderRadius.all(Radius.circular(16));

  /// The cover, with play count, danmaku count and duration on a scrim.
  /// Only the image flies to the player; the labels stay on the card.
  Widget _cover(double width, double height) {
    const white = Colors.white;
    return ClipRRect(
      borderRadius: _coverRadius,
      child: Stack(
        fit: .expand,
        children: [
          CoverHero(
            tag: videoItem.goto == 'av' ? coverHeroTag(videoItem) : null,
            borderRadius: _coverRadius,
            child: NetworkImgLayer(
              src: videoItem.cover,
              width: width,
              height: height,
              borderRadius: BorderRadius.zero,
            ),
          ),
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
            child: Row(
              spacing: 6,
              children: [
                StatWidget(
                  type: .play,
                  value: videoItem.stat.view,
                  color: white,
                ),
                if (videoItem.goto != 'picture')
                  StatWidget(
                    type: .danmaku,
                    value: videoItem.stat.danmu,
                    color: white,
                  ),
                const Spacer(),
                if (videoItem.duration > 0)
                  Text(
                    DurationUtils.formatDuration(videoItem.duration),
                    style: const TextStyle(
                      color: white,
                      fontSize: 11,
                      fontWeight: .w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const .fromLTRB(2, 8, 2, 4),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // the UP row follows the title directly, also when the title
            // takes one line; any leftover height stays below
            Text(
              videoItem.title,
              maxLines: 2,
              overflow: .ellipsis,
              style: const TextStyle(height: 1.35),
            ),
            const SizedBox(height: 4),
            Row(
              spacing: 2,
              children: [
                if (videoItem.goto == 'bangumi')
                  PBadge(
                    text: videoItem.pgcBadge,
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.rcmdReason != null)
                  PBadge(
                    text: videoItem.rcmdReason,
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                if (videoItem.goto == 'picture')
                  const PBadge(
                    text: '动态',
                    isStack: false,
                    size: .small,
                    type: .line_primary,
                    fontSize: 9,
                  ),
                if (videoItem.isFollowed)
                  const PBadge(
                    text: '已关注',
                    isStack: false,
                    size: .small,
                    type: .secondary,
                  ),
                Expanded(
                  flex: 1,
                  child: Text(
                    videoItem is RcmdVideoItemModel
                        ? '${videoItem.owner.name} · ${DateFormatUtils.dateFormat(videoItem.pubdate, short: shortFormat, long: longFormat)}'
                        : videoItem.owner.name.toString(),
                    maxLines: 1,
                    overflow: .clip,
                    semanticsLabel: 'UP：${videoItem.owner.name}',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: theme.textTheme.labelMedium!.fontSize,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                if (videoItem.goto == 'av') const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  Widget videoStat(ThemeData theme) {
    return Row(
      children: [
        StatWidget(
          type: .play,
          value: videoItem.stat.view,
        ),
        if (videoItem.goto != 'picture') ...[
          const SizedBox(width: 4),
          StatWidget(
            type: .danmaku,
            value: videoItem.stat.danmu,
          ),
        ],
        if (videoItem is RcmdVideoItemModel) ...[
          const Spacer(),
          Text.rich(
            maxLines: 1,
            TextSpan(
              style: TextStyle(
                fontSize: theme.textTheme.labelSmall!.fontSize,
                color: theme.colorScheme.outline.withValues(alpha: 0.8),
              ),
              text: DateFormatUtils.dateFormat(
                videoItem.pubdate,
                short: shortFormat,
                long: longFormat,
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );
  }
}

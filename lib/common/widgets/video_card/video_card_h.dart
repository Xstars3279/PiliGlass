import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/motion/cover_hero.dart';
import 'package:PiliPlus/common/motion/pressable_scale.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/progress_bar/video_progress_indicator.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 水平布局
class VideoCardH extends StatelessWidget {
  const VideoCardH({
    super.key,
    required this.videoItem,
    this.onTap,
    this.onViewLater,
    this.onRemove,
  });
  final HorizontalVideoModel videoItem;
  final VoidCallback? onTap;
  final ValueChanged<int>? onViewLater;
  final VoidCallback? onRemove;

  void onLongPress() => imageSaveDialog(
    bvid: videoItem.bvid,
    title: videoItem.title,
    cover: videoItem.cover,
  );

  static const _coverRadius = BorderRadius.all(
    Radius.circular(Revamp.thumbRadius),
  );

  /// rises in when its list loads, see [RiseIn]
  @override
  Widget build(BuildContext context) =>
      Revamp.enabled ? RiseIn(child: _build(context)) : _build(context);

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      pressedScale: 0.97,
      child: Material(
        type: .transparency,
        child: Stack(
          clipBehavior: .none,
          children: [
            InkWell(
              onLongPress: onLongPress,
              onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
              onTap:
                  onTap ?? PressableScale.delayTap(() => pushVideoH(videoItem)),
              child: Padding(
                padding: .symmetric(
                  horizontal: Style.safeSpace,
                  vertical: Revamp.enabled ? UiSpace.s12 / 2 : 5,
                ),
                child: Row(
                  crossAxisAlignment: .start,
                  children: [
                    AspectRatio(
                      aspectRatio: Style.aspectRatio,
                      child: LayoutBuilder(
                        builder: (context, boxConstraints) {
                          final double maxWidth = boxConstraints.maxWidth;
                          final double maxHeight = boxConstraints.maxHeight;

                          final progress = videoItem.progress;

                          return Revamp.clip(
                            radius: _coverRadius,
                            child: Stack(
                              clipBehavior: .none,
                              children: [
                                CoverHero(
                                  tag: coverHeroTag(videoItem),
                                  borderRadius: _coverRadius,
                                  child: NetworkImgLayer(
                                    src: videoItem.cover,
                                    width: maxWidth,
                                    height: maxHeight,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                if (videoItem.badge case final badge?)
                                  PBadge(
                                    text: badge,
                                    top: 6.0,
                                    right: 6.0,
                                    type: switch (badge) {
                                      '充电专属' => .error,
                                      _ => .primary,
                                    },
                                  ),
                                if (Revamp.enabled) ...[
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: maxHeight * 0.4,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: .topCenter,
                                          end: .bottomCenter,
                                          colors: [
                                            Color(0x00000000),
                                            Color(0x99000000),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (progress != null && progress != 0) ...[
                                    Positioned(
                                      right: UiSpace.s8,
                                      bottom: UiSpace.s8,
                                      child: Text(
                                        progress == -1
                                            ? '已看完'
                                            : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(videoItem.duration)}',
                                        style: UiType.label.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      right: 0,
                                      child: VideoProgressIndicator(
                                        color: theme.colorScheme.primary,
                                        backgroundColor: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        progress: progress == -1
                                            ? 1
                                            : progress / videoItem.duration,
                                      ),
                                    ),
                                  ] else if (videoItem.duration > 0)
                                    Positioned(
                                      right: UiSpace.s8,
                                      bottom: UiSpace.s8,
                                      child: Text(
                                        DurationUtils.formatDuration(
                                          videoItem.duration,
                                        ),
                                        style: UiType.label.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ] else ...[
                                  if (progress != null && progress != 0) ...[
                                    PBadge(
                                      text: progress == -1
                                          ? '已看完'
                                          : '${DurationUtils.formatDuration(progress)}/${DurationUtils.formatDuration(videoItem.duration)}',
                                      right: 6,
                                      bottom: 8,
                                      type: .gray,
                                    ),
                                    Positioned(
                                      left: 0,
                                      bottom: 0,
                                      right: 0,
                                      child: VideoProgressIndicator(
                                        color: theme.colorScheme.primary,
                                        backgroundColor: theme
                                            .colorScheme
                                            .secondaryContainer,
                                        progress: progress == -1
                                            ? 1
                                            : progress / videoItem.duration,
                                      ),
                                    ),
                                  ] else if (videoItem.duration > 0)
                                    PBadge(
                                      text: DurationUtils.formatDuration(
                                        videoItem.duration,
                                      ),
                                      right: 6.0,
                                      bottom: 6.0,
                                      type: .gray,
                                    ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(width: Revamp.enabled ? UiSpace.s12 : 10),
                    content(theme),
                  ],
                ),
              ),
            ),
            // 更多: a 20 icon on a 40 tap target at the bottom right
            Positioned(
              bottom: Revamp.enabled ? -4 : 0,
              right: Revamp.enabled ? 6 : 12,
              width: Revamp.enabled ? 40 : 29,
              height: Revamp.enabled ? 40 : 29,
              child: VideoPopupMenu(
                iconSize: Revamp.enabled ? 20 : 17,
                videoItem: videoItem,
                onRemove: onRemove,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget content(ThemeData theme) {
    String pubdate = DateFormatUtils.dateFormat(videoItem.pubdate!);
    if (pubdate != '') pubdate += '  ';
    return Expanded(
      child: Column(
        crossAxisAlignment: .start,
        children: [
          if (videoItem.titleList?.isNotEmpty == true)
            Expanded(
              child: Text.rich(
                overflow: .ellipsis,
                maxLines: 2,
                TextSpan(
                  children: videoItem.titleList!
                      .map(
                        (e) => TextSpan(
                          text: e.text,
                          style:
                              (Revamp.enabled
                                      ? UiType.bodyStrong
                                      : TextStyle(
                                          fontSize: theme
                                              .textTheme
                                              .bodyMedium!
                                              .fontSize,
                                          height: 1.42,
                                          letterSpacing: 0.3,
                                        ))
                                  .copyWith(
                                    color: e.isEm
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                        ),
                      )
                      .toList(),
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                videoItem.title,
                textAlign: .start,
                style: Revamp.enabled
                    ? UiType.bodyStrong
                    : TextStyle(
                        fontSize: theme.textTheme.bodyMedium!.fontSize,
                        height: 1.42,
                        letterSpacing: 0.3,
                      ),
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ),
          if (Revamp.enabled) ...[
            // three lines: the title, the UP, then the figures and the date
            // together (6.6, 9.1)
            Text(
              videoItem.isLive == true
                  ? "$pubdate${videoItem.owner.name}"
                  : videoItem.owner.name ?? '',
              maxLines: 1,
              style: UiType.caption.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                overflow: .clip,
              ),
            ),
            if (videoItem.isLive != true)
              Padding(
                // room for 更多
                padding: const .only(right: 28),
                child: Row(
                  spacing: UiSpace.s12,
                  children: [
                    StatWidget(
                      type: .play,
                      value: videoItem.stat.view,
                      color: theme.colorScheme.onSurfaceVariant,
                      textStyle: UiType.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    StatWidget(
                      type: .danmaku,
                      value: videoItem.stat.danmu,
                      color: theme.colorScheme.onSurfaceVariant,
                      textStyle: UiType.caption.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        pubdate.trim(),
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: UiType.caption.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Text(
              "$pubdate${videoItem.owner.name}",
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                color: theme.colorScheme.outline,
                overflow: .clip,
              ),
            ),
            if (videoItem.isLive != true) ...[
              const SizedBox(height: 3),
              Row(
                spacing: 8,
                children: [
                  StatWidget(
                    type: .play,
                    value: videoItem.stat.view,
                  ),
                  StatWidget(
                    type: .danmaku,
                    value: videoItem.stat.danmu,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Future<void> pushVideoH(HorizontalVideoModel videoItem) async {
  if (videoItem.isPugv ?? false) {
    PageUtils.viewPugv(seasonId: videoItem.seasonId);
    return;
  }

  if (videoItem.isLive ?? false) {
    if (videoItem.roomId case final roomId?) {
      PageUtils.toLiveRoom(roomId);
    }
    return;
  }

  if (videoItem.redirectUrl?.isNotEmpty == true &&
      PageUtils.viewPgcFromUri(videoItem.redirectUrl!)) {
    return;
  }

  int? cid = videoItem.cid;
  Dimension? dimension = videoItem.dimension;
  if (cid == null) {
    if (await SearchHttp.ab2cWithDimension(
          aid: videoItem.aid,
          bvid: videoItem.bvid,
        )
        case final res?) {
      cid = res.cid;
      dimension = res.dimension;
    }
  }
  if (cid != null) {
    PageUtils.toVideoPage(
      bvid: videoItem.bvid,
      cid: cid,
      cover: videoItem.cover,
      title: videoItem.title,
      dimension: dimension,
      extraArguments: {'coverHero': coverHeroTag(videoItem)},
    );
  }
}

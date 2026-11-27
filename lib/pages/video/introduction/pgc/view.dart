import 'dart:math';

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/grow_from.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/image_viewer/hero.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/image_preview_type.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/stat.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/widgets/episode.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/widgets/season.dart';
import 'package:PiliPlus/pages/video/introduction/pgc/widgets/section.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class PgcIntroPage extends StatefulWidget {
  final String heroTag;
  final ShowEpisodes showEpisodes;
  final Function(PgcInfoModel videoDetail, List<VideoTagItem>? videoTags)
  showIntroDetail;
  final double maxWidth;
  final bool isPortrait;

  const PgcIntroPage({
    super.key,
    required this.heroTag,
    required this.showEpisodes,
    required this.showIntroDetail,
    required this.maxWidth,
    required this.isPortrait,
  });

  @override
  State<PgcIntroPage> createState() => _PgcIntroPageState();
}

class _PgcIntroPageState extends State<PgcIntroPage> {
  late final PgcIntroController introController;
  late final VideoDetailController videoDetailCtr;
  late ColorScheme colorScheme;

  @override
  void initState() {
    super.initState();
    introController = Get.putOrFind(
      PgcIntroController.new,
      tag: widget.heroTag,
    );
    videoDetailCtr = introController.videoDetailCtr;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = introController.pgcItem;
    final isPortrait = widget.isPortrait;
    Widget sliver = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Revamp.enabled ? UiSpace.s12 : 10,
            children: [
              _buildCover(item),
              Expanded(child: _buildInfoPanel(isPortrait, item)),
            ],
          ),
          // below the block, two lines of it, the whole of it in the dialog
          if (Revamp.enabled &&
              introController.isPgc &&
              (item.evaluate?.isNotEmpty ?? false))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.showIntroDetail(
                item,
                introController.videoTags.value,
              ),
              child: Padding(
                padding: const .only(top: UiSpace.s12),
                child: Text(
                  '简介：${item.evaluate}',
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: UiType.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          // 点赞收藏转发 布局样式2
          if (introController.isPgc) actionGrid(item.stat!, introController),
          if (isPortrait ||
              !videoDetailCtr.plPlayerController.horizontalSeasonPanel) ...[
            // seasons
            if (item.hasSeasons)
              Padding(
                padding: const .only(top: 5),
                child: SeasonPanel(
                  pgcController: introController,
                  onSeasonChanged: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            // 番剧分集
            if (item.hasEpisodes)
              EpisodePanel(
                pgcController: introController,
                showEpisodes: widget.showEpisodes,
                onChangeEpisode: introController.onChangeEpisode,
              ),
          ],
          if (item.hasSections)
            SectionPanel(
              pgcController: introController,
              showEpisodes: widget.showEpisodes,
              onChangeEpisode: introController.onChangeEpisode,
            ),
        ],
      ),
    );
    if (!introController.isPgc) {
      final brief = _buildBrief(item);
      if (brief != null) {
        sliver = SliverMainAxisGroup(slivers: [sliver, brief]);
      }
    }
    return SliverPadding(
      padding: .fromLTRB(
        Style.safeSpace,
        Style.safeSpace,
        Style.safeSpace,
        // 24 to the comment card, which brings 12 of its own (6.7)
        Revamp.enabled ? UiSpace.s12 : Style.safeSpace + 50,
      ),
      sliver: sliver,
    );
  }

  Widget? _buildBrief(PgcInfoModel item) {
    final img = item.brief?.img;
    if (img != null && img.isNotEmpty) {
      final maxWidth = widget.maxWidth - 24;
      double padding = max(0, maxWidth - 400);
      final imgWidth = maxWidth - padding;
      padding = padding / 2;
      return SliverPadding(
        padding: .only(top: 10, left: padding, right: padding),
        sliver: SliverMainAxisGroup(
          slivers: img.map((e) {
            return SliverToBoxAdapter(
              child: NetworkImgLayer(
                type: .emote,
                src: e.url,
                width: imgWidth,
                height: imgWidth * e.aspectRatio,
              ),
            );
          }).toList(),
        ),
      );
    }
    return null;
  }

  Widget _buildCover(PgcInfoModel item) {
    // 96 wide, 3:4, rounded in the redesign (6.7)
    final width = Revamp.enabled ? 96.0 : 115.0;
    final height = Revamp.enabled ? 128.0 : 153.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => PageUtils.imageView(
            imgList: [SourceModel(url: item.cover!)],
          ),
          child: fromHero(
            tag: item.cover!,
            child: NetworkImgLayer(
              width: width,
              height: height,
              src: item.cover!,
              borderRadius: Revamp.enabled
                  ? const .all(.circular(UiRadius.medium))
                  : BorderRadius.zero,
            ),
          ),
        ),
        if (item.rating != null)
          PBadge(
            text: '评分 ${item.rating!.score!}',
            top: null,
            right: Revamp.enabled ? UiSpace.s8 : 6,
            bottom: Revamp.enabled ? UiSpace.s8 : 6,
            left: null,
          ),
        if (!introController.isPgc)
          Positioned(
            right: Revamp.enabled ? UiSpace.s8 : 6,
            bottom: Revamp.enabled ? UiSpace.s8 : 6,
            child: Obx(() {
              final isFav = introController.isFav.value;
              return iconButton(
                size: 28,
                iconSize: 26,
                tooltip: '${isFav ? '取消' : ''}收藏',
                onPressed: () => introController.onFavPugv(isFav),
                icon: isFav
                    ? const Icon(Icons.star_rounded)
                    : const Icon(Icons.star_border_rounded),
                bgColor: isFav
                    ? colorScheme.secondaryContainer
                    : colorScheme.onInverseSurface,
                iconColor: isFav
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              );
            }),
          ),
      ],
    );
  }

  Widget _buildInfoPanel(bool isPortrait, PgcInfoModel item) {
    if (introController.isPgc) {
      Widget subBtn() => Builder(
        builder: (btnCtx) => Obx(
          () {
            final isFollowed = introController.isFollowed.value;
            final followStatus = introController.followStatus.value;
            return FilledButton.tonal(
              style: FilledButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(
                  horizontal: Revamp.enabled ? UiSpace.s16 : 20,
                  vertical: Revamp.enabled ? 0 : 10,
                ),
                minimumSize: Revamp.enabled ? const Size(0, 32) : null,
                visualDensity: Revamp.enabled
                    ? VisualDensity.standard
                    : VisualDensity.compact,
                foregroundColor:
                    Revamp.followFg(colorScheme, isFollowed) ??
                    (isFollowed ? colorScheme.outline : null),
                backgroundColor:
                    Revamp.followBg(colorScheme, isFollowed) ??
                    (isFollowed ? colorScheme.onInverseSurface : null),
                textStyle: Revamp.enabled
                    ? UiType.caption.copyWith(fontWeight: FontWeight.w500)
                    : null,
              ),
              onPressed: followStatus == -1
                  ? null
                  : () {
                      if (isFollowed) {
                        showPgcFollowDialog(
                          context: btnCtx,
                          type: introController.pgcType,
                          followStatus: followStatus,
                          from: morphRectOf(btnCtx),
                          onUpdateStatus: (followStatus) {
                            if (followStatus == -1) {
                              introController.pgcDel();
                            } else {
                              introController.pgcUpdate(
                                followStatus,
                              );
                            }
                          },
                        );
                      } else {
                        introController.pgcAdd();
                      }
                    },
              child: Text(
                isFollowed
                    ? '已${introController.pgcType}'
                    : introController.pgcType,
              ),
            );
          },
        ),
      );
      // the redesign: the title takes the whole width beside the poster,
      // the button drops below it (6.7)
      Widget title() => Text(
        item.title!,
        style: Revamp.enabled ? UiType.title : const TextStyle(fontSize: 16),
        maxLines: Revamp.enabled ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      );
      List<Widget> desc() => [
        Text(
          item.newEp!.desc!,
          style: Revamp.enabled
              ? UiType.caption.copyWith(color: colorScheme.onSurfaceVariant)
              : TextStyle(fontSize: 12, color: colorScheme.outline),
        ),
        Text.rich(
          TextSpan(
            children: [
              if (item.areas?.isNotEmpty == true)
                TextSpan(text: '${item.areas!.first.name!}  '),
              TextSpan(
                text: item.publish!.pubTimeShow!,
              ),
            ],
          ),
          style: Revamp.enabled
              ? UiType.caption.copyWith(color: colorScheme.onSurfaceVariant)
              : TextStyle(fontSize: 12, color: colorScheme.outline),
        ),
      ];
      Widget stat() => Wrap(
        spacing: Revamp.enabled ? UiSpace.s12 : 6,
        runSpacing: 2,
        children: [
          StatWidget(
            type: .play,
            value: item.stat!.view,
            color: Revamp.enabled ? colorScheme.onSurfaceVariant : null,
          ),
          StatWidget(
            type: .danmaku,
            value: item.stat!.danmaku,
            color: Revamp.enabled ? colorScheme.onSurfaceVariant : null,
          ),
          if (!isPortrait && !Revamp.enabled) ...desc(),
        ],
      );
      // 全13话 · 日本 · 2012, on one line under the figures
      Widget meta() {
        final year = RegExp(r'\d{4}')
            .firstMatch(item.publish?.pubTimeShow ?? '');
        final parts = [
          item.newEp?.desc,
          if (item.areas?.isNotEmpty == true) item.areas!.first.name,
          year?.group(0),
        ].whereType<String>().where((e) => e.isNotEmpty);
        return Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UiType.caption.copyWith(color: colorScheme.onSurfaceVariant),
        );
      }

      if (Revamp.enabled) {
        return GestureDetector(
          onTap: () => widget.showIntroDetail(
            item,
            introController.videoTags.value,
          ),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: UiSpace.s4,
            children: [
              title(),
              stat(),
              meta(),
              const SizedBox(height: UiSpace.s4),
              subBtn(),
            ],
          ),
        );
      }
      return GestureDetector(
        onTap: () => widget.showIntroDetail(
          item,
          introController.videoTags.value,
        ),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 153,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title(),
              stat(),
              const SizedBox(height: 5),
              if (isPortrait) ...desc(),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  '简介：${item.evaluate}',
                  style: TextStyle(fontSize: 13, color: colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // pugv
    Widget upInfo(int mid, String avatar, String name, {String? role}) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Get.toNamed('/member?mid=$mid'),
          child: Row(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            children: [
              NetworkImgLayer(
                src: avatar,
                width: 35,
                height: 35,
                type: ImageType.avatar,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name),
                  if (role != null && role.isNotEmpty)
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.cooperators?.isNotEmpty == true) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 25,
              children: item.cooperators!.map((e) {
                return upInfo(e.mid!, e.avatar!, e.nickName!, role: e.role);
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
        ] else if (item.upInfo?.mid != null) ...[
          upInfo(
            item.upInfo!.mid!,
            item.upInfo!.avatar!,
            item.upInfo!.uname!,
          ),
          const SizedBox(height: 6),
        ],
        Text(
          item.title!,
          style: const TextStyle(fontSize: 16),
        ),
        if (item.subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            item.subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget actionGrid(PgcStat stat, PgcIntroController introController) {
    return SizedBox(
      // the same 56 as the UGC page, four items this time (6.4)
      height: Revamp.enabled ? 56 : 48,
      child: Row(
        crossAxisAlignment: Revamp.enabled
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.thumbsUp),
              selectIcon: const Icon(FontAwesomeIcons.solidThumbsUp),
              iconSize: Revamp.enabled ? 20.0 : 19.0,
              fontSize: 10.0,
              selectStatus: introController.hasLike.value,
              semanticsLabel: '点赞',
              text: NumUtils.numFormat(stat.like),
              onStartTriple: introController.onStartTriple,
              onCancelTriple: introController.onCancelTriple,
            ),
          ),
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.b),
              selectIcon: const Icon(FontAwesomeIcons.b),
              iconSize: Revamp.enabled ? 20.0 : 19.0,
              fontSize: 10.0,
              onTap: introController.actionCoinVideo,
              selectStatus: introController.hasCoin,
              semanticsLabel: '投币',
              text: NumUtils.numFormat(stat.coin),
            ),
          ),
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.star),
              selectIcon: const Icon(FontAwesomeIcons.solidStar),
              iconSize: Revamp.enabled ? 20.0 : 19.0,
              fontSize: 10.0,
              onTap: () => introController.showFavBottomSheet(context),
              onLongPress: () => introController.showFavBottomSheet(
                context,
                isLongPress: true,
              ),
              selectStatus: introController.hasFav.value,
              semanticsLabel: '收藏',
              text: NumUtils.numFormat(stat.favorite),
            ),
          ),
          // the redesign moved both into the ⋯ menu
          if (!Revamp.enabled) ...[
            ActionItem(
              icon: const Icon(CustomIcons.download),
              iconSize: 19.0,
              fontSize: 10.0,
              onTap: () => videoDetailCtr.onDownload(context),
              text: '缓存',
              semanticsLabel: '缓存',
            ),
            Obx(
              () => ActionItem(
                icon: const Icon(FontAwesomeIcons.clock),
                selectIcon: const Icon(FontAwesomeIcons.solidClock),
                iconSize: 19.0,
                fontSize: 10.0,
                onTap: () =>
                    introController.handleAction(introController.viewLater),
                selectStatus: introController.hasLater.value,
                semanticsLabel: '再看',
                text: '再看',
              ),
            ),
          ],
          ActionItem(
            icon: const Icon(FontAwesomeIcons.shareFromSquare),
            iconSize: Revamp.enabled ? 20.0 : 19.0,
            fontSize: 10.0,
            onTap: () => introController.actionShareVideo(context),
            selectStatus: false,
            semanticsLabel: '转发',
            text: NumUtils.numFormat(stat.share),
          ),
          ActionItem(
            icon: const Icon(Icons.download_rounded),
            iconSize: Revamp.enabled ? 20.0 : 19.0,
            fontSize: 10.0,
            onTap: () => videoDetailCtr.onDownloadMp4(context),
            text: '下载视频',
            semanticsLabel: '下载视频',
          ),
        ],
      ),
    );
  }
}

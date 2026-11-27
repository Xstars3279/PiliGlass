import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_menu.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/badge_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc;
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart' as ugc;
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/pages/download/download/view.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class DownloadPanel extends StatefulWidget {
  const DownloadPanel({
    super.key,
    required this.index,
    this.pgcItem,
    this.videoDetail,
    required this.episodes,
    required this.scrollController,
    required this.videoDetailController,
    required this.heroTag,
    this.ugcIntroController,
    required this.cidSet,
  });

  final int index;
  final PgcInfoModel? pgcItem;
  final VideoDetailData? videoDetail;
  final List<ugc.BaseEpisodeItem> episodes;
  final ScrollController scrollController;
  final VideoDetailController videoDetailController;
  final String heroTag;
  final UgcIntroController? ugcIntroController;
  final Set<int> cidSet;

  @override
  State<DownloadPanel> createState() => _DownloadPanelState();
}

class _DownloadPanelState extends State<DownloadPanel> {
  final DownloadService _downloadService = Get.find<DownloadService>();
  final ListController _listController = ListController();

  late final cidSet = widget.cidSet;
  final Set<int> _selectedCids = <int>{};
  VideoQuality _quality = VideoQuality.fromCode(Pref.defaultVideoQa);
  AudioQuality _audioQuality = AudioQuality.fromCode(Pref.defaultAudioQa);

  late ColorScheme colorScheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = .of(context);
  }

  @override
  void initState() {
    super.initState();
    if (widget.index != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _listController.jumpToItem(
          index: widget.index,
          scrollController: widget.scrollController,
          alignment: 0,
        );
      });
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = colorScheme.outline.withValues(alpha: 0.2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildHeader(),
        _buildBody(),
        Divider(height: 1, color: dividerColor),
        _buildFooter(dividerColor),
      ],
    );
  }

  Widget _buildHeader() {
    final textStyle = TextStyle(color: colorScheme.onSurfaceVariant);
    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              spacing: 12,
              children: [
                Text('画质', style: textStyle),
                Builder(
                  builder: (context) => _buildMenuAnchor<VideoQuality>(
                    value: _quality,
                    label: _quality.desc,
                    items: VideoQuality.values,
                    itemLabel: (e) => e.desc,
                    onSelected: (value) {
                      _quality = value;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                Text('音质', style: textStyle),
                Builder(
                  builder: (context) => _buildMenuAnchor<AudioQuality>(
                    value: _audioQuality,
                    label: _audioQuality.desc,
                    items: AudioQuality.values,
                    itemLabel: (e) => e.desc,
                    onSelected: (value) {
                      _audioQuality = value;
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) => iconButton(
              size: 34,
              iconSize: 20,
              tooltip: '缓存字幕/分段',
              onPressed: () {
                _downloadService.toggleCachePlayInfo();
                (context as Element).markNeedsBuild();
              },
              icon: Icon(
                _downloadService.cachePlayInfo
                    ? Icons.subtitles_outlined
                    : Icons.subtitles_off_outlined,
                color: _downloadService.cachePlayInfo
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.outline,
              ),
            ),
          ),
          if (PlatformUtils.isMobile)
            StreamBuilder(
              stream: Connectivity().onConnectivityChanged,
              builder: (context, snapshot) {
                if (snapshot.data case final data?) {
                  return Padding(
                    padding: const .only(left: 6),
                    child: Icon(
                      data.contains(ConnectivityResult.wifi)
                          ? Icons.wifi
                          : Icons.signal_cellular_alt,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          else if (kDebugMode)
            Padding(
              padding: const .only(left: 6),
              child: Icon(
                Icons.wifi,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuAnchor<T>({
    required T value,
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onSelected,
  }) {
    final trigger = _buildPopupMenuChild(label);
    if (!Revamp.enabled) {
      return PopupMenuButton<T>(
        initialValue: value,
        onSelected: onSelected,
        itemBuilder: (context) => items
            .map(
              (e) => PopupMenuItem<T>(
                value: e,
                child: Text(itemLabel(e)),
              ),
            )
            .toList(),
        child: trigger,
      );
    }
    return GlassPopupAnchor<T>(
      alignEnd: false,
      minWidth: 160,
      itemBuilder: (context) => items
          .map(
            (e) => PopupMenuItem<T>(
              value: e,
              onTap: () => onSelected(e),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(itemLabel(e)),
                  if (e == value)
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          )
          .toList(),
      targetBuilder: (open) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: trigger,
      ),
    );
  }

  Widget _buildPopupMenuChild(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(height: 1),
            strutStyle: const StrutStyle(height: 1, leading: 0),
          ),
          Icon(
            size: 18,
            Icons.keyboard_arrow_down,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  List<int> _collectSelectableCids() {
    final result = <int>[];
    for (final episode in widget.episodes) {
      if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
        for (final p in episode.pages!) {
          final cid = p.cid;
          if (cid != null && !cidSet.contains(cid)) {
            result.add(cid);
          }
        }
      } else {
        final cid = episode.cid;
        if (cid != null && !cidSet.contains(cid)) {
          result.add(cid);
        }
      }
    }
    return result;
  }

  bool _isEpisodeDownloaded(ugc.BaseEpisodeItem episode) {
    if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
      final pages = episode.pages!;
      return pages.isNotEmpty &&
          pages.every((p) => p.cid != null && cidSet.contains(p.cid));
    }
    return episode.cid != null && cidSet.contains(episode.cid);
  }

  bool _isEpisodeSelected(ugc.BaseEpisodeItem episode) {
    if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
      final selectable = episode.pages!
          .map((p) => p.cid)
          .whereType<int>()
          .where((c) => !cidSet.contains(c))
          .toList();
      return selectable.isNotEmpty &&
          selectable.every(_selectedCids.contains);
    }
    final cid = episode.cid;
    return cid != null &&
        !cidSet.contains(cid) &&
        _selectedCids.contains(cid);
  }

  void _toggleEpisodeSelection(ugc.BaseEpisodeItem episode) {
    if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
      final selectable = episode.pages!
          .map((p) => p.cid)
          .whereType<int>()
          .where((c) => !cidSet.contains(c))
          .toList();
      if (selectable.isEmpty) {
        SmartDialog.showToast('已全部缓存');
        return;
      }
      setState(() {
        if (selectable.every(_selectedCids.contains)) {
          _selectedCids.removeAll(selectable);
        } else {
          _selectedCids.addAll(selectable);
        }
      });
      return;
    }
    final cid = episode.cid;
    if (cid == null) {
      SmartDialog.showToast('null cid');
      return;
    }
    if (cidSet.contains(cid)) {
      SmartDialog.showToast('已缓存');
      return;
    }
    setState(() {
      if (!_selectedCids.add(cid)) {
        _selectedCids.remove(cid);
      }
    });
  }

  bool _togglePartSelection(Part part) {
    final cid = part.cid;
    if (cid == null) {
      SmartDialog.showToast('null cid');
      return false;
    }
    if (cidSet.contains(cid)) {
      SmartDialog.showToast('已缓存');
      return false;
    }
    setState(() {
      if (!_selectedCids.add(cid)) {
        _selectedCids.remove(cid);
      }
    });
    return true;
  }

  void _downloadSelected() {
    final selectable = _collectSelectableCids().toSet();
    final toDownload = _selectedCids.intersection(selectable);
    if (toDownload.isEmpty) {
      SmartDialog.showToast('请先选择要缓存的视频');
      return;
    }
    var count = 0;
    for (int i = 0; i < widget.episodes.length; i++) {
      final episode = widget.episodes[i];
      if (episode is ugc.EpisodeItem && episode.pages!.length > 1) {
        for (final p in episode.pages!) {
          if (p.cid != null && toDownload.contains(p.cid)) {
            if (_onDownload(indexInSeason: i, episode: p, parent: episode)) {
              count++;
            }
          }
        }
      } else if (episode.cid != null && toDownload.contains(episode.cid)) {
        if (_onDownload(indexInSeason: i, episode: episode)) {
          count++;
        }
      }
    }
    setState(() {
      _selectedCids.removeAll(toDownload);
    });
    if (count > 0) {
      SmartDialog.showToast('已将 $count 项加入缓存队列');
    }
  }

  Widget _buildBody() {
    final episodes = widget.episodes;
    return Expanded(
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SuperSliverList.builder(
                itemCount: episodes.length,
                listController: _listController,
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  final hasParts =
                      episode is ugc.EpisodeItem && episode.pages!.length > 1;
                  Widget child = _buildItem(
                    index: index,
                    episode: episode,
                    isCurrentIndex: index == widget.index,
                  );
                  if (hasParts) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        child,
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          child: PagePanel(
                            parts: episode.pages,
                            cover: episode.arc?.pic,
                            ugcIntroController: widget.ugcIntroController!,
                            bvid: episode.bvid ?? IdUtils.av2bv(episode.aid!),
                            cidSet: cidSet,
                            selectedCids: _selectedCids,
                            onDownload: _togglePartSelection,
                          ),
                        ),
                      ],
                    );
                  }
                  return child;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @pragma('vm:notify-debugger-on-exception')
  bool _onDownload({
    required int indexInSeason,
    required ugc.BaseEpisodeItem episode,
    bool isFromList = false,
    bool isDownloadAll = false,
    ugc.EpisodeItem? parent,
  }) {
    final cid = episode.cid;
    // on download
    if (cid == null) {
      SmartDialog.showToast('null cid');
      return false;
    }

    if (cidSet.contains(cid)) {
      if (kDebugMode) {
        SmartDialog.showToast('downloaded');
      }
      return false;
    }

    if (episode is ugc.EpisodeItem) {
      final pages = episode.pages!;
      if (pages.length > 1) {
        if (isFromList && kDebugMode) {
          SmartDialog.showToast('hasParts');
        }
        if (isDownloadAll) {
          for (int i = 0; i < pages.length; i++) {
            _onDownload(
              indexInSeason: indexInSeason,
              episode: pages[i],
              parent: episode,
            );
          }
          return true;
        }
        return false;
      }
    }

    try {
      switch (episode) {
        case Part part:
          _downloadService.downloadVideo(
            page: part,
            videoDetail: parent == null ? widget.videoDetail : null,
            videoArc: parent,
            videoQuality: _quality,
            audioQuality: _audioQuality,
            seasonInfo: widget.videoDetail?.seasonInfo(indexInSeason),
          );
          break;
        case ugc.EpisodeItem episode:
          _downloadService.downloadVideo(
            page: episode.pages!.first,
            videoDetail: null,
            videoArc: episode,
            videoQuality: _quality,
            audioQuality: _audioQuality,
            seasonInfo: widget.videoDetail?.seasonInfo(indexInSeason),
          );
          break;
        case pgc.EpisodeItem episode:
          _downloadService.downloadBangumi(
            index: indexInSeason,
            pgcItem: widget.pgcItem!,
            episode: episode,
            quality: _quality,
            audioQuality: _audioQuality,
          );
          break;
      }
      cidSet.add(cid);
      return true;
    } catch (e, s) {
      Utils.reportError(e, s);
      SmartDialog.showToast(e.toString());
    }
    return false;
  }

  Widget _buildItem({
    required int index,
    required bool isCurrentIndex,
    required ugc.BaseEpisodeItem episode,
  }) {
    late String title;
    num? duration;
    int? pubdate;
    int? view;
    int? danmaku;
    bool? isCharging;

    String? cover;
    bool? cacheWidth;

    switch (episode) {
      case Part part:
        cover = part.firstFrame ?? widget.videoDetail?.pic;
        title = part.part ?? widget.videoDetail!.title!;
        duration = part.duration;
        pubdate = part.ctime;
        cacheWidth = part.dimension?.cacheWidth;
        break;
      case ugc.EpisodeItem item:
        title = item.title!;
        if (item.arc case final arc?) {
          cover = arc.pic;
          duration = arc.duration;
          pubdate = arc.pubdate;
          if (arc.stat case final stat?) {
            view = stat.view;
            danmaku = stat.danmaku;
          }
          cacheWidth = arc.dimension?.cacheWidth;
        }
        if (item.attribute == 8) {
          isCharging = true;
        }
        break;
      case pgc.EpisodeItem item:
        title = item.showTitle ?? item.title!;
        cover = item.cover;
        if (item.from == 'pugv') {
          duration = item.duration;
          view = item.play;
        } else {
          duration = item.duration == null ? null : item.duration! ~/ 1000;
        }
        pubdate = item.pubTime;
        cacheWidth = item.dimension?.cacheWidth;
        break;
    }
    late final primary = colorScheme.primary;
    final isDownloaded = _isEpisodeDownloaded(episode);
    final isSelected = _isEpisodeSelected(episode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: 110,
        child: Material(
          color: isSelected
              ? primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: InkWell(
            onTap: () => _toggleEpisodeSelection(episode),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Style.safeSpace,
                vertical: 5,
              ),
              child: Row(
                spacing: 10,
                children: [
                  if (cover?.isNotEmpty == true)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: cover,
                          width: 160,
                          height: 100,
                          cacheWidth: cacheWidth,
                        ),
                        if (duration != null && duration > 0)
                          PBadge(
                            text: DurationUtils.formatDuration(duration),
                            right: 6.0,
                            bottom: 6.0,
                            type: PBadgeType.gray,
                          ),
                        if (isCharging == true)
                          const PBadge(
                            text: '充电专属',
                            top: 6,
                            right: 6,
                            type: PBadgeType.error,
                          )
                        else if (episode.badge != null)
                          PBadge(
                            text: episode.badge,
                            top: 6,
                            right: 6,
                            type: episode.badgeType,
                          ),
                      ],
                    )
                  else if (isCurrentIndex)
                    Image.asset(
                      Assets.livingStatic,
                      color: primary,
                      height: 12,
                      cacheHeight: 12.cacheSize(context),
                      semanticLabel: '正在播放：',
                    ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              height: 1.42,
                              letterSpacing: 0.3,
                              fontWeight: isCurrentIndex
                                  ? FontWeight.bold
                                  : null,
                              color: isCurrentIndex ? primary : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pubdate != null)
                          Text(
                            DateFormatUtils.format(pubdate),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1,
                              color: colorScheme.outline,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Row(
                          spacing: 8,
                          children: [
                            if (view != null)
                              StatWidget(
                                value: view,
                                type: StatType.play,
                              ),
                            if (danmaku != null)
                              StatWidget(
                                value: danmaku,
                                type: StatType.danmaku,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: isDownloaded
                          ? Icon(
                              size: 16,
                              color: colorScheme.secondary.withValues(
                                alpha: 0.8,
                              ),
                              FontAwesomeIcons.circleDown,
                            )
                          : Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 22,
                              color: isSelected
                                  ? primary
                                  : colorScheme.outline.withValues(alpha: 0.5),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(Color dividerColor) {
    final selectable = _collectSelectableCids();
    final selectedCount = selectable.where(_selectedCids.contains).length;
    final isAllSelected =
        selectable.isNotEmpty && selectedCount == selectable.length;
    return Ink(
      color: Revamp.enabled ? Colors.transparent : colorScheme.surfaceContainer,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Row(
        children: [
          _buildBottomBtn(
            text: isAllSelected ? '取消全选' : '全选',
            onTap: () {
              if (selectable.isEmpty) {
                SmartDialog.showToast('暂无可选视频');
                return;
              }
              setState(() {
                if (isAllSelected) {
                  _selectedCids.removeAll(selectable);
                } else {
                  _selectedCids.addAll(selectable);
                }
              });
            },
          ),
          SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 1,
              color: dividerColor,
            ),
          ),
          _buildBottomBtn(
            text: '缓存所选($selectedCount项)',
            color: selectedCount > 0 ? colorScheme.primary : null,
            fontWeight: selectedCount > 0 ? FontWeight.w600 : null,
            onTap: _downloadSelected,
          ),
          SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 1,
              color: dividerColor,
            ),
          ),
          _buildBottomBtn(
            text: '查看缓存',
            onTap: () => Navigator.of(context).push(
              GetPageRoute(page: () => const DownloadPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBtn({
    required String text,
    required VoidCallback onTap,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color ?? colorScheme.onSurfaceVariant,
                    fontWeight: fontWeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

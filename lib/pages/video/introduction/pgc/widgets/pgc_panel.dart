import 'dart:async' show StreamSubscription;
import 'dart:math';

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/new_ep.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart'
    hide EpisodeItem;
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class PgcPanel extends StatefulWidget {
  const PgcPanel({
    super.key,
    required this.pages,
    this.cid,
    required this.onChangeEpisode,
    required this.showEpisodes,
    required this.heroTag,
    this.newEp,
  });

  final List<EpisodeItem> pages;
  final int? cid;
  final ValueChanged<BaseEpisodeItem> onChangeEpisode;
  final Function showEpisodes;
  final String heroTag;
  final NewEp? newEp;

  @override
  State<PgcPanel> createState() => _PgcPanelState();
}

class _PgcPanelState extends State<PgcPanel> {
  late int currentIndex;
  late final ScrollController listViewScrollCtr;
  // 默认未开通
  late final bool vipStatus;
  late int cid;
  late final VideoDetailController videoDetailCtr;
  late final StreamSubscription<int> _listener;

  void _updateIndex() {
    currentIndex = max(0, widget.pages.indexWhere((e) => e.cid == cid));
  }

  @override
  void initState() {
    super.initState();
    cid = widget.cid!;
    _updateIndex();
    listViewScrollCtr = ScrollController(
      // 140 + 8 in the redesign, 150 before it
      initialScrollOffset: currentIndex * (Revamp.enabled ? 148.0 : 150.0),
    );

    vipStatus = Pref.userInfoCache?.vipStatus != 1;

    videoDetailCtr = Get.find<VideoDetailController>(tag: widget.heroTag);

    _listener = videoDetailCtr.cid.listen((int p0) {
      cid = p0;
      _updateIndex();
      if (!mounted) return;
      setState(() {});
      scrollToIndex();
    });
  }

  @override
  void dispose() {
    _listener.cancel();
    listViewScrollCtr.dispose();
    super.dispose();
  }

  /// The upstream label: how far the show has gone, or 查看全部.
  String _epLabel() {
    final newEp = widget.newEp;
    if (newEp?.desc?.contains('连载') == true) {
      return '连载中，更新至${Utils.isStringNumeric(newEp!.title!) ? '第${newEp.title}话' : '${newEp.title}'}';
    }
    return newEp?.desc ?? '查看全部';
  }

  void scrollToIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      listViewScrollCtr.animateTo(
        currentIndex * 150.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final currEpisode = widget.pages[currentIndex];
    final isPugv = currEpisode.from == 'pugv';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('合集 '),
              Expanded(
                child: Text(
                  ' 正在播放：${currEpisode.longTitle ?? currEpisode.title}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: theme.outline),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 34,
                child: TextButton(
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.zero),
                  ),
                  onPressed: () => widget.showEpisodes(
                    null,
                    null,
                    widget.pages,
                    videoDetailCtr.bvid,
                    videoDetailCtr.aid,
                    cid,
                  ),
                  child: Text(
                    // 已完结 / 连载中 is on the info block above (6.7), so
                    // the button only points at the list
                    Revamp.enabled ? '查看全部' : _epLabel(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            padding: .zero,
            itemExtent: 150,
            scrollDirection: .horizontal,
            controller: listViewScrollCtr,
            itemCount: widget.pages.length,
            key: const PageStorageKey(_PgcPanelState),
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int index) =>
                _buildItem(theme, isPugv, index),
          ),
        ),
      ],
    );
  }

  Widget _buildItem(ColorScheme theme, bool isPugv, int index) {
    final item = widget.pages[index];
    final hasLongTitle = item.longTitle?.isNotEmpty == true;
    final isCurr = index == currentIndex;
    final color = Revamp.enabled
        ? (isCurr ? theme.onSecondaryContainer : theme.onSurface)
        : (isCurr ? theme.primary : theme.onSurface);
    return Container(
      // 140 by 56 in the redesign, the chosen one tonal (6.7)
      width: Revamp.enabled ? 140 : 150,
      height: Revamp.enabled ? 56 : 60,
      margin: index != widget.pages.length - 1
          ? EdgeInsets.only(right: Revamp.enabled ? UiSpace.s8 : 10)
          : null,
      child: Material(
        color: Revamp.enabled
            ? (isCurr ? theme.secondaryContainer : theme.surfaceContainerLow)
            : Revamp.tile(theme),
        shape: Revamp.tileShape,
        child: InkWell(
          customBorder: Revamp.tileShape,
          onTap: () {
            if (item.badge == '会员' && Accounts.mainEqVideo && vipStatus) {
              SmartDialog.showToast('需要大会员');
            }
            widget.onChangeEpisode(item);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: Revamp.enabled ? UiSpace.s8 : 8,
              horizontal: Revamp.enabled ? UiSpace.s12 : 10,
            ),
            child: Column(
              spacing: 3,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        maxLines: hasLongTitle ? 1 : 2,
                        TextSpan(
                          children: [
                            if (index == currentIndex && !Revamp.enabled)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Image.asset(
                                    Assets.livingStatic,
                                    color: theme.primary,
                                    height: 12,
                                    cacheHeight: 12.cacheSize(context),
                                    semanticLabel: "正在播放：",
                                  ),
                                ),
                              ),
                            TextSpan(
                              text: item.title ?? '第${index + 1}话',
                              style: Revamp.enabled
                                  ? UiType.caption.copyWith(
                                      fontSize: 13,
                                      color: color,
                                    )
                                  : TextStyle(
                                      fontSize: 13,
                                      color: color,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (item.badge?.isNotEmpty == true) ...[
                      const SizedBox(width: 2),
                      if (item.badge == '会员')
                        SvgPicture.asset(
                          Assets.vipIcon,
                          height: Revamp.enabled ? 16 : 16,
                          semanticsLabel: "大会员",
                        )
                      else
                        Text(
                          item.badge!,
                          style: TextStyle(
                            fontSize: 11,
                            color: switch (item.badge) {
                              '限免' => theme.freeColor,
                              '预告' => theme.onSurfaceVariant,
                              _ => theme.primary,
                            },
                          ),
                        ),
                    ],
                  ],
                ),
                if (hasLongTitle)
                  Text(
                    isPugv ? item.title! : item.longTitle!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/fab_mixin.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/pages/video/reply/vote/reply_vote_item.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/widgets/ambient_background.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class VideoReplyPanel extends StatefulWidget {
  const VideoReplyPanel({
    super.key,
    this.replyLevel = 1,
    required this.heroTag,
    required this.isNested,
    this.inSheet = false,
  });

  final int replyLevel;
  final String heroTag;
  final bool isNested;

  /// inside the redesign's comment sheet, which has its own header with the
  /// sort button and its own input bar instead of the reply button
  final bool inSheet;

  @override
  State<VideoReplyPanel> createState() => _VideoReplyPanelState();
}

class _VideoReplyPanelState extends State<VideoReplyPanel>
    with
        AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin,
        BaseFabMixin,
        FabMixin {
  late ColorScheme colorScheme;
  late VideoReplyController _videoReplyController;

  String get heroTag => widget.heroTag;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _videoReplyController = Get.find<VideoReplyController>(tag: heroTag);
    if (_videoReplyController.loadingState.value is Loading) {
      _videoReplyController.queryData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _videoReplyController.didChangeDependencies(context);
    colorScheme = ColorScheme.of(context);
    bottom = MediaQuery.viewPaddingOf(context).bottom;
  }

  late double bottom;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return fabAnimWrapper(
      child: refreshIndicator(
        onRefresh: _videoReplyController.onRefresh,
        isClampingScrollPhysics: widget.isNested,
        child: ScaffoldLayout(
          body: CustomScrollView(
            controller: widget.isNested
                ? null
                : _videoReplyController.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            key: const PageStorageKey(_VideoReplyPanelState),
            slivers: [
              if (!widget.inSheet)
                SliverFloatingHeaderWidget(
                  backgroundColor: Revamp.enabled
                      ? Colors.transparent
                      : colorScheme.surface,
                  child: _revampHeader(
                    Padding(
                      padding: const .fromLTRB(12, 2.5, 6, 2.5),
                      child: Obx(() {
                        final sortType = _videoReplyController.sortType.value;
                        return Row(
                          mainAxisAlignment: .spaceBetween,
                          children: [
                            Text(
                              sortType.desc,
                              style: const TextStyle(fontSize: 13),
                            ),
                            TextButton.icon(
                              style: Style.buttonStyle,
                              onPressed: _videoReplyController.queryBySort,
                              icon: Icon(
                                Icons.sort,
                                size: 16,
                                color: colorScheme.secondary,
                              ),
                              label: Text(
                                sortType.descShort,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              Obx(() => _buildBody(_videoReplyController.loadingState.value)),
            ],
          ),
          fab: widget.inSheet
              ? null
              : SlideTransition(
                  position: fabAnimation,
                  child: Padding(
                    padding: .only(
                      right: kFloatingActionButtonMargin,
                      bottom: kFloatingActionButtonMargin + bottom,
                    ),
                    child: FloatingActionButton(
                      heroTag: null,
                      onPressed: () {
                        feedBack();
                        _videoReplyController.onReply(
                          null,
                          oid: _videoReplyController.aid,
                          replyType: _videoReplyController.videoType.replyType,
                          mentionItem: _videoReplyController.mentionItem,
                        );
                      },
                      tooltip: '发表评论',
                      child: const Icon(Icons.reply),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// With the redesign, frosted glass in the ambient tint instead of a
  /// white strip: it blends into the tinted top, and replies scrolling under
  /// it show through softly.
  Widget _revampHeader(Widget child) {
    if (!Revamp.enabled) return child;
    final surface = ColorScheme.of(context).surface;
    final detail = Get.isRegistered<VideoDetailController>(tag: heroTag)
        ? Get.find<VideoDetailController>(tag: heroTag)
        : null;
    Widget glass(Color? tint, Widget child) => ColoredBox(
      color: (tint ?? surface).withValues(alpha: 0.82),
      child: child,
    );
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: detail == null
            ? glass(null, child)
            : AmbientTintBuilder(
                cover: detail.cover,
                builder: (context, tint, child) => glass(tint, child!),
                child: child,
              ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<ReplyInfo>?> loadingState) {
    switch (loadingState) {
      case Loading():
        return const SliverPrototypeExtentList(
          prototypeItem: VideoReplySkeleton(),
          delegate: SliverSingleChildDelegate(
            count: 5,
            child: VideoReplySkeleton(),
          ),
        );
      case Success(:final response):
        if (response != null && response.isNotEmpty) {
          var count = response.length + 1;
          final voteCard = _videoReplyController.voteCard;
          final hasVote = voteCard != null;
          if (hasVote) {
            count++;
          }
          return SliverList.builder(
            itemBuilder: (context, index) {
              if (hasVote) {
                if (index == 0) {
                  return buildVoteCard(context, colorScheme, voteCard);
                } else {
                  index--;
                }
              }
              if (index == response.length) {
                _videoReplyController.onLoadMore();
                return Container(
                  height: 125,
                  alignment: .center,
                  margin: .only(bottom: bottom),
                  child: Text(
                    _videoReplyController.isEnd ? '没有更多了' : '加载中...',
                    textAlign: .center,
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                );
              } else {
                final item = response[index];
                final child = ReplyItemGrpc(
                  replyItem: item,
                  replyLevel: widget.replyLevel,
                  replyReply: _videoReplyController.replyReply,
                  onReply: _videoReplyController.onReply,
                  onDelete: (item, subIndex) =>
                      _videoReplyController.onRemove(index, item, subIndex),
                  upMid: _videoReplyController.upMid,
                  getTag: () => heroTag,
                  onCheckReply: _videoReplyController.onCheckReply,
                  onToggleTop: (item) => _videoReplyController.onToggleTop(
                    item,
                    index,
                    _videoReplyController.aid,
                    _videoReplyController.videoType.replyType,
                  ),
                );
                if (item.id == _videoReplyController.targetRootRpId) {
                  return _videoReplyController.colorAnimWrapper(
                    colorScheme,
                    child,
                  );
                }
                return child;
              }
            },
            itemCount: count,
          );
        }

        final child = HttpError(
          errMsg: '还没有评论',
          onReload: _videoReplyController.onReload,
        );
        if (_videoReplyController.voteCard case final voteCard?) {
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: buildVoteCard(context, colorScheme, voteCard),
              ),
              child,
            ],
          );
        }
        return child;
      case Error(:final errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _videoReplyController.onReload,
        );
    }
  }
}

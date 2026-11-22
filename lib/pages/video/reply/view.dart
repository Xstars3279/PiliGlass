import 'package:PiliPlus/common/widgets/liquid_glass/revamp_fab.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, MainListReply;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/fab_mixin.dart';
import 'package:PiliPlus/pages/common/reply/reply_footer_mixin.dart';
import 'package:PiliPlus/pages/common/reply/vote/reply_vote_item.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
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
        FabMixin,
        ReplyFooterMixin<VideoReplyPanel, MainListReply> {
  @override
  late ColorScheme colorScheme;
  @override
  late VideoReplyController controller;

  String get heroTag => widget.heroTag;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VideoReplyController>(tag: heroTag);
    if (controller.loadingState.value is Loading) {
      controller.queryData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.didChangeDependencies(context);
    colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return fabAnimWrapper(
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        isClampingScrollPhysics: widget.isNested,
        child: ScaffoldLayout(
          body: CustomScrollView(
            controller: widget.isNested ? null : controller.scrollController,
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
                        final sortType = controller.sortType.value;
                        return Row(
                          mainAxisAlignment: .spaceBetween,
                          children: [
                            Text(
                              sortType.desc,
                              style: const TextStyle(fontSize: 13),
                            ),
                            TextButton.icon(
                              style: Style.buttonStyle,
                              onPressed: controller.queryBySort,
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
              Obx(() => _buildBody(controller.loadingState.value)),
            ],
          ),
          fab: widget.inSheet
              ? null
              : SlideTransition(
                  position: fabAnimation,
                  child: Padding(
                    padding: .only(
                      right: kFloatingActionButtonMargin,
                      bottom: kFloatingActionButtonMargin + padding.bottom,
                    ),
                    child: RevampFab(
                      heroTag: null,
                      onPressed: () {
                        feedBack();
                        controller.onReply(
                          null,
                          oid: controller.oid,
                          replyType: controller.replyType,
                          mentionItem: controller.mentionItem,
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

  /// With the redesign, the ambient tint instead of a white strip: it
  /// blends into the tinted top, and replies scrolling under it show
  /// through faintly. Not blurred: this header sits beside the playing
  /// video in landscape, and a live blur there costs frames on every frame
  /// the video draws.
  Widget _revampHeader(Widget child) {
    if (!Revamp.enabled) return child;
    final surface = ColorScheme.of(context).surface;
    final detail = Get.isRegistered<VideoDetailController>(tag: heroTag)
        ? Get.find<VideoDetailController>(tag: heroTag)
        : null;
    Widget tinted(Color? tint, Widget child) => ColoredBox(
      color: Color.lerp(surface, tint ?? surface, 0.6)!.withValues(
        alpha: 0.94,
      ),
      child: child,
    );
    return detail == null
        ? tinted(null, child)
        : AmbientTintBuilder(
            cover: detail.cover,
            builder: (context, tint, child) => tinted(tint, child!),
            child: child,
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
          final voteCard = controller.voteCard;
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
                return buildFooter();
              } else {
                final item = response[index];
                final child = ReplyItemGrpc(
                  replyItem: item,
                  replyLevel: widget.replyLevel,
                  replyReply: controller.replyReply,
                  onReply: controller.onReply,
                  onDelete: (item, subIndex) =>
                      controller.onRemove(index, item, subIndex),
                  upMid: controller.upMid,
                  getTag: () => heroTag,
                  onCheckReply: controller.onCheckReply,
                  onToggleTop: (item) => controller.onToggleTop(
                    item,
                    index,
                    controller.oid,
                    controller.replyType,
                  ),
                );
                if (item.id == controller.targetRootRpId) {
                  return controller.colorAnimWrapper(
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

        final child = emptyWidget();
        if (controller.voteCard case final voteCard?) {
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
          onReload: controller.onReload,
        );
    }
  }
}

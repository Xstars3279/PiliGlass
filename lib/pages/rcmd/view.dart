import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    final child = Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        key: controller.refreshKey,
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            RevampTopInset.sliver(context),
            SliverPadding(
              padding: .only(
                top: Style.cardSpace,
                bottom: Revamp.enabled ? UiSpace.underDock(context) : 100,
              ),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
    if (PlatformUtils.isDesktop && Pref.showRefreshFAB) {
      return ScaffoldLayout(
        body: child,
        fab: Padding(
          padding: const .only(
            right: kFloatingActionButtonMargin,
            bottom: 80 + kFloatingActionButtonMargin,
          ),
          child: FloatingActionButton(
            tooltip: '刷新',
            onPressed: controller.toTopAndRefresh,
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    return child;
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Revamp.enabled ? UiSpace.gridRow : Style.cardSpace,
    crossAxisSpacing: Revamp.enabled ? UiSpace.gridColumn : Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    // text below the cover: 8, two title lines, 4 and the UP row, and no
    // more; the row can carry a badge 20 high, so 74 rather than the 70 the
    // bare lines need, or the two-line cards overflow by a pixel
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(
      Revamp.enabled ? 74 : 76,
    ),
  );

  /// when the current list arrived, so its cards can animate in
  Object? _shownList;
  DateTime? _shownAt;

  Widget _appear(int index, Widget card) => Revamp.enabled
      ? AppearIn(index: index, since: _shownAt, child: card)
      : card;

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    if (loadingState case Success(:final response)
        when !identical(response, _shownList)) {
      _shownList = response;
      _shownAt = DateTime.now();
    }
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    controller.onLoadMore();
                  }
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    return _appear(
                      index,
                      VideoCardV(
                        videoItem: response[actualIndex],
                        onRemove: () {
                          if (controller.lastRefreshAt != null &&
                              actualIndex < controller.lastRefreshAt!) {
                            controller.lastRefreshAt =
                                controller.lastRefreshAt! - 1;
                          }
                          controller.loadingState
                            ..value.data!.removeAt(actualIndex)
                            ..refresh();
                        },
                      ),
                    );
                  } else {
                    return _appear(
                      index,
                      VideoCardV(
                        videoItem: response[index],
                        onRemove: () => controller.loadingState
                          ..value.data!.removeAt(index)
                          ..refresh(),
                      ),
                    );
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: VideoCardVSkeleton(),
    ),
  );
}

import 'dart:async';

import 'package:PiliPlus/common/motion/appear_in.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DynamicsTabPage extends StatefulWidget {
  const DynamicsTabPage({super.key, required this.dynamicsType});

  final DynamicsTabType dynamicsType;

  @override
  State<DynamicsTabPage> createState() => _DynamicsTabPageState();
}

class _DynamicsTabPageState extends State<DynamicsTabPage>
    with AutomaticKeepAliveClientMixin, DynMixin {
  final dynamicsController = Get.putOrFind(DynamicsController.new);
  late final DynamicsTabController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    controller = Get.putOrFind(
      () => DynamicsTabController(dynamicsType: widget.dynamicsType),
      tag: widget.dynamicsType.name,
    );
    super.initState();
  }

  Future<void> onRefresh() {
    dynamicsController.singleRefresh();
    return controller.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: controller.scrollController,
        slivers: [
          RevampTopInset.sliver(context),
          SliverPadding(
            padding: EdgeInsets.only(top: Revamp.enabled ? 8 : 0, bottom: 100),
            sliver: buildPage(
              Obx(() => _buildBody(controller.loadingState.value)),
            ),
          ),
        ],
      ),
    );
  }

  /// when the current list arrived, so its posts can rise in
  Object? _shownList;
  DateTime? _shownAt;

  Widget _buildBody(LoadingState<List<DynamicItemModel>?> loadingState) {
    if (loadingState case Success(:final response)
        when !identical(response, _shownList)) {
      _shownList = response;
      _shownAt = DateTime.now();
    }
    return switch (loadingState) {
      Loading() => dynSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? GlobalData().dynamicsWaterfallFlow
                  ? SliverMasonryGrid(
                      crossAxisSpacing: 4,
                      gridDelegate: dynGridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _itemBuilder(response, index),
                        childCount: response.length,
                      ),
                    )
                  : SliverList.builder(
                      itemBuilder: (context, index) =>
                          _itemBuilder(response, index),
                      itemCount: response.length,
                    )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _itemBuilder(List<DynamicItemModel> list, int index) {
    if (index == list.length - 1) {
      controller.onLoadMore();
    }
    final item = list[index];
    final panel = DynamicPanel(
      item: item,
      onRemove: (idStr) => controller.onRemove(index, idStr),
      onBlock: () => controller.onBlock(index),
      onUnfold: () => controller.onUnfold(item, index),
    );
    return Revamp.enabled
        ? AppearIn(index: index, since: _shownAt, child: panel)
        : panel;
  }
}

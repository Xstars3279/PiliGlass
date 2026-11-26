import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_icon_button.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_menu.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_strip.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/revamp_fab.dart';
import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show tabBarScrollPhysics;
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/models/common/later_view_type.dart';
import 'package:PiliPlus/models_new/later/list.dart';
import 'package:PiliPlus/pages/later/base_controller.dart';
import 'package:PiliPlus/pages/later/controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LaterPage extends StatefulWidget {
  const LaterPage({super.key});

  @override
  State<LaterPage> createState() => _LaterPageState();
}

class _LaterPageState extends State<LaterPage>
    with SingleTickerProviderStateMixin {
  final LaterBaseController _baseCtr = Get.put(LaterBaseController());
  late final TabController _tabController;

  LaterController currCtr([int? index]) {
    final type = LaterViewType.values[index ?? _tabController.index];
    return Get.putOrFind(
      () => LaterController(type),
      tag: type.type.toString(),
    );
  }

  final _sortKey = GlobalKey();
  void listener() {
    (_sortKey.currentContext as Element?)?.markNeedsBuild();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: LaterViewType.values.length,
      vsync: this,
    )..addListener(listener);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(listener)
      ..dispose();
    Get.delete<LaterBaseController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Obx(
      () {
        final enableMultiSelect = _baseCtr.enableMultiSelect.value;
        return popScope(
          canPop: !enableMultiSelect,
          onPopInvokedWithResult: (didPop, result) {
            if (enableMultiSelect) {
              currCtr().handleSelect();
            }
          },
          child: SimpleScaffold(
            appBar: _buildAppbar(enableMultiSelect),
            fab: Padding(
              padding: .only(
                right: kFloatingActionButtonMargin + padding.right,
                bottom: kFloatingActionButtonMargin + padding.bottom,
              ),
              child: Obx(
                () => currCtr().loadingState.value.isSuccess
                    ? AnimatedSlide(
                        offset: _baseCtr.isPlayAll.value
                            ? Offset.zero
                            : const Offset(0.75, 0),
                        duration: const Duration(milliseconds: 120),
                        child: GestureDetector(
                          onHorizontalDragDown: (details) =>
                              _baseCtr.dx = details.localPosition.dx,
                          onHorizontalDragStart: (details) =>
                              _baseCtr.setIsPlayAll(
                                details.localPosition.dx < _baseCtr.dx,
                              ),
                          child: RevampFab.extended(
                            onPressed: () {
                              if (_baseCtr.isPlayAll.value) {
                                currCtr().toViewPlayAll();
                              } else {
                                _baseCtr.setIsPlayAll(true);
                              }
                            },
                            label: const Text('播放全部'),
                            icon: const Icon(Icons.playlist_play),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            body: ViewSafeArea(
              child: Column(
                children: [
                  if (Revamp.enabled)
                    GlassTabStrip(
                      items: [
                        for (final item in LaterViewType.values)
                          GlassTabItem(
                            '${item.title}'
                            '${_baseCtr.counts[item.index] != -1 ? '(${_baseCtr.counts[item.index]})' : ''}',
                          ),
                      ],
                      controller: _tabController,
                      capsule: true,
                      refraction: false,
                      centered: true,
                      drag: GlassTabDrag.scrub,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      onSelected: (index) {
                        // as the old bar's onTap: a tap on the tab already
                        // shown goes back to the top; a tap on another one
                        // while selecting ends the selection in the tab left
                        if (index == _tabController.index) {
                          currCtr().scrollController.animToTop();
                        } else if (enableMultiSelect) {
                          currCtr().handleSelect();
                        }
                      },
                    )
                  else
                    TabBar(
                      // isScrollable: true,
                      // tabAlignment: TabAlignment.start,
                      controller: _tabController,
                      tabs: LaterViewType.values.map((item) {
                        final count = _baseCtr.counts[item.index];
                        return Tab(
                          text: '${item.title}${count != -1 ? '($count)' : ''}',
                        );
                      }).toList(),
                      onTap: (_) {
                        if (!_tabController.indexIsChanging) {
                          currCtr().scrollController.animToTop();
                        } else if (enableMultiSelect) {
                          currCtr(_tabController.previousIndex).handleSelect();
                        }
                      },
                    ),
                  Expanded(
                    child: TabBarView(
                      physics: enableMultiSelect
                          ? const NeverScrollableScrollPhysics()
                          : tabBarScrollPhysics,
                      controller: _tabController,
                      horizontalDragGestureRecognizer:
                          CustomHorizontalDragGestureRecognizer.new,
                      children: LaterViewType.values
                          .map((item) => item.page)
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppbar(bool enableMultiSelect) {
    final theme = Theme.of(context);
    final btnStyle = TextButton.styleFrom(visualDensity: .compact);
    final textStyle = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return MultiSelectAppBarWidget(
      visible: enableMultiSelect,
      ctr: currCtr(),
      actions: [
        TextButton(
          style: btnStyle,
          onPressed: () {
            final ctr = currCtr();
            RequestUtils.onCopyOrMove<LaterItemModel>(
              context: context,
              isCopy: true,
              ctr: ctr,
              mediaId: null,
              mid: ctr.mid,
            );
          },
          child: Text('复制', style: textStyle),
        ),
        TextButton(
          style: btnStyle,
          onPressed: () {
            final ctr = currCtr();
            RequestUtils.onCopyOrMove<LaterItemModel>(
              context: context,
              isCopy: false,
              ctr: ctr,
              mediaId: null,
              mid: ctr.mid,
            );
          },
          child: Text('移动', style: textStyle),
        ),
      ],
      child: AppBar(
        title: const Text('稍后再看'),
        actions: [
          GlassIconButton(
            tapSize: 44,
            tooltip: '搜索',
            onTap: () {
              final mid = Accounts.main.mid;
              Get.toNamed(
                '/laterSearch',
                arguments: {
                  'type': 0,
                  'mediaId': mid,
                  'mid': mid,
                  'title': '稍后再看',
                  'count': _baseCtr.counts[LaterViewType.all.index],
                },
              );
            },
            icon: const Icon(Icons.search),
          ),
          const SizedBox(width: 2),
          Builder(
            key: _sortKey,
            builder: (context) {
              final value = currCtr().asc.value;
              return GlassPopupAnchor<bool>(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: false,
                    onTap: () => currCtr()
                      ..asc.value = false
                      ..onReload(),
                    child: Row(
                      children: [
                        const Text('最近添加'),
                        const Spacer(),
                        if (!value) const Icon(Icons.done, size: 18),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: true,
                    onTap: () => currCtr()
                      ..asc.value = true
                      ..onReload(),
                    child: Row(
                      children: [
                        const Text('最早添加'),
                        const Spacer(),
                        if (value) const Icon(Icons.done, size: 18),
                      ],
                    ),
                  ),
                ],
                targetBuilder: (open) => GlassIconButton(
                  tapSize: 44,
                  tooltip: '排序',
                  onTap: open,
                  icon: const Icon(Icons.sort),
                ),
              );
            },
          ),
          const SizedBox(width: 2),
          GlassPopupAnchor<Object?>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => currCtr().toViewClear(context, 1),
                child: const Text('清空失效'),
              ),
              PopupMenuItem(
                onTap: () => currCtr().toViewClear(context, 2),
                child: const Text('清空看完'),
              ),
              PopupMenuItem(
                onTap: () => currCtr().toViewClear(context),
                child: const Text('清空全部'),
              ),
            ],
            targetBuilder: (open) => GlassIconButton(
              tapSize: 44,
              tooltip: '清空',
              onTap: open,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

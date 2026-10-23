import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide DraggableScrollableSheet;

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  UpPanelPosition get upPanelPosition => _dynamicsController.upPanelPosition;
  late final MainController _mainController = Get.find<MainController>();

  @override
  bool get wantKeepAlive => true;

  Widget _createDynamicBtn(ColorScheme colorScheme, {bool isRight = true}) =>
      Container(
        width: 34,
        height: 34,
        margin: isRight ? const .only(right: 16) : const .only(left: 16),
        child: IconButton(
          tooltip: '发布动态',
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            backgroundColor: WidgetStatePropertyAll(
              colorScheme.secondaryContainer,
            ),
          ),
          onPressed: () => CreateDynPanel.onCreateDyn(context),
          icon: Icon(
            Icons.add,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      );

  /// The tabs on a capsule of the dock's glass, as on the home page; the
  /// app's pill tabs from the theme.
  Widget _glassTabs(Widget? leading, Widget actions) => Padding(
    // the same bar as the home tabs: size, margins and glass
    padding: const .fromLTRB(12, 6, 12, 4),
    child: SizedBox(
      height: 48,
      child: Row(
        spacing: 8,
        children: [
          ?leading,
          Expanded(
            child: GlassCapsule(
              refraction: true,
              // five tabs fit: spread them evenly over the bar
              child: TabBar(
                padding: EdgeInsets.zero,
                labelPadding: EdgeInsets.zero,
                controller: _dynamicsController.tabController,
                tabs: DynamicsTabType.values
                    .map((e) => Tab(text: e.label))
                    .toList(),
                onTap: (index) {
                  if (!_dynamicsController.tabController.indexIsChanging) {
                    _dynamicsController.animateToTop();
                  }
                },
              ),
            ),
          ),
          if (actions is! SizedBox) actions,
        ],
      ),
    ),
  );

  /// the room the floating tabs take, as on the home page
  static const _barHeight = 6.0 + 48 + 4;

  Widget upPanelPart(ColorScheme colorScheme) {
    final isTop = upPanelPosition == .top;
    final needBg = upPanelPosition.index > 2;
    // the redesign sets the strip above the posts off as a group
    if (Revamp.enabled && (isTop || !needBg)) {
      return RevampGroup(
        // below the floating tabs
        margin: isTop
            ? const .fromLTRB(12, _barHeight, 12, 4)
            : upPanelPosition == .leftFixed
            ? const .only(left: 8, top: _barHeight)
            : const .only(right: 8, top: _barHeight),
        child: SizedBox(
          width: isTop ? null : 64,
          height: isTop ? 84 : null,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              final metrics = notification.metrics;
              if (metrics.pixels >= metrics.maxScrollExtent - 300) {
                _dynamicsController.onLoadMore();
              }
              return false;
            },
            child: Obx(
              () => _buildUpPanel(_dynamicsController.loadingState.value),
            ),
          ),
        ),
      );
    }
    return Material(
      type: needBg ? .canvas : .transparency,
      color: needBg ? colorScheme.surface : null,
      child: SizedBox(
        width: isTop ? null : 64,
        height: isTop ? 76 : null,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 300) {
              _dynamicsController.onLoadMore();
            }
            return false;
          },
          child: Obx(
            () => _buildUpPanel(_dynamicsController.loadingState.value),
          ),
        ),
      ),
    );
  }

  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get checkPage =>
      _mainController.navigationBars[0] != .dynamics &&
      _mainController.selectedIndex.value == 0;

  @override
  bool onNotificationType1(UserScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType1(notification);
  }

  @override
  bool onNotificationType2(ScrollNotification notification) {
    if (checkPage) {
      return false;
    }
    return super.onNotificationType2(notification);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);

    Widget? drawer;
    Widget? endDrawer;

    Widget? leading;
    Widget actions;

    Widget child = tabBarView(
      controller: _dynamicsController.tabController,
      children: DynamicsTabType.values
          .map((e) => DynamicsTabPage(dynamicsType: e))
          .toList(),
    );

    switch (upPanelPosition) {
      case .top:
        child = Column(
          children: [
            upPanelPart(colorScheme),
            Expanded(child: child),
          ],
        );
        actions = _createDynamicBtn(colorScheme);
      case .leftFixed:
        child = Row(
          children: [
            upPanelPart(colorScheme),
            Expanded(child: child),
          ],
        );
        actions = _createDynamicBtn(colorScheme);
      case .rightFixed:
        child = Row(
          children: [
            Expanded(child: child),
            upPanelPart(colorScheme),
          ],
        );
        actions = _createDynamicBtn(colorScheme);
      case .leftDrawer:
        drawer = upPanelPart(colorScheme);
        actions = _createDynamicBtn(colorScheme);
        leading = const DrawerButton();
      case .rightDrawer:
        endDrawer = upPanelPart(colorScheme);
        leading = _createDynamicBtn(colorScheme, isRight: false);
        actions = const EndDrawerButton();
    }
    // the redesign posts from the round button of the dock
    if (Revamp.enabled) {
      if (upPanelPosition == .rightDrawer) {
        leading = null;
      } else {
        actions = const SizedBox.shrink();
      }
    }

    // the redesign: the posts run on under the tabs, which float on glass
    if (Revamp.enabled) {
      child = RevampTopInset(inset: _barHeight, child: child);
    }
    return Scaffold(
      primary: false,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: Revamp.enabled,
      appBar: PreferredSize(
        preferredSize: .fromHeight(Revamp.enabled ? _barHeight : 50),
        child: Revamp.enabled
            ? _glassTabs(leading, actions)
            : Row(
                children: [
                  ?leading,
                  Expanded(
                    child: TabBar(
                      dividerHeight: 0,
                      isScrollable: true,
                      tabAlignment: .start,
                      dividerColor: Colors.transparent,
                      labelColor: colorScheme.primary,
                      indicatorColor: colorScheme.primary,
                      controller: _dynamicsController.tabController,
                      unselectedLabelColor: colorScheme.onSurface,
                      labelStyle:
                          TabBarTheme.of(context).labelStyle
                              ?.copyWith(fontSize: 13) ??
                          const TextStyle(fontSize: 13),
                      tabs: DynamicsTabType.values
                          .map((e) => Tab(text: e.label))
                          .toList(),
                      onTap: (index) {
                        if (!_dynamicsController
                            .tabController
                            .indexIsChanging) {
                          _dynamicsController.animateToTop();
                        }
                      },
                    ),
                  ),
                  actions,
                ],
              ),
      ),
      drawer: drawer,
      endDrawer: endDrawer,
      body: onBuild(child),
    );
  }
}

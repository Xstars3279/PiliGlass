import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/ui_icons.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/centered_glass_tabs.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget tabBar;
    final dockSearch = _mainController.dockSearch;
    if (dockSearch) {
      tabBar = _glassTabBar();
    } else if (_homeController.tabs.length > 1) {
      tabBar = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SizedBox(
          height: 42,
          width: double.infinity,
          child: TabBar(
            controller: _homeController.tabController,
            tabs: _homeController.tabs.map((e) => Tab(text: e.label)).toList(),
            isScrollable: true,
            dividerColor: Colors.transparent,
            dividerHeight: 0,
            splashBorderRadius: Style.mdRadius,
            tabAlignment: TabAlignment.center,
            onTap: (_) {
              feedBack();
              if (!_homeController.tabController.indexIsChanging) {
                _homeController.animateToTop();
              }
            },
          ),
        ),
      );
      if (_homeController.hideTopBar &&
          _mainController.barHideType == .instant) {
        tabBar = Material(
          color: _colorScheme.surface,
          child: tabBar,
        );
      }
    } else {
      tabBar = const SizedBox(height: 6);
    }
    if (dockSearch) return _floatingTabs(tabBar);
    return Column(
      children: [
        if (_mainController.bottomNavFor(MediaQuery.sizeOf(context)) &&
            !dockSearch)
          customAppBar(),
        tabBar,
        Expanded(
          child: onBuild(
            tabBarView(
              controller: _homeController.tabController,
              children: _homeController.tabs.map((e) => e.page).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// The feed fills the page and runs on under the tabs, which float on
  /// glass at the top.
  ///
  /// The bar is the page's appBar, not a layer of the body's stack: with the
  /// feed in the same layer, the glass beside it lost its blur in a strip at
  /// its left end while the feed scrolled. 动态 keeps its bar on the appBar
  /// too, and never loses it.
  Widget _floatingTabs(Widget tabBar) => Scaffold(
    primary: false,
    resizeToAvoidBottomInset: false,
    backgroundColor: Colors.transparent,
    extendBodyBehindAppBar: true,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(_floatingTabsHeight),
      child: tabBar,
    ),
    body: Stack(
      children: [
        Positioned.fill(
          child: RevampTopInset(
            // with a single tab no bar floats there
            inset: _homeController.tabs.length > 1 ? _floatingTabsHeight : 6,
            child: onBuild(
              tabBarView(
                controller: _homeController.tabController,
                children: _homeController.tabs.map((e) => e.page).toList(),
              ),
            ),
          ),
        ),
        // the feed fades out behind the tabs when solid: the page's color at
        // the top, nothing 24 below them; transparent glass shows the feed
        if (_homeController.tabs.length > 1 && !UiGlass.clear)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _floatingTabsHeight + UiSpace.s24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: .topCenter,
                    end: .bottomCenter,
                    colors: [
                      _colorScheme.surface,
                      _colorScheme.surface.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// the room the floating tabs take: their bar and its margins
  static const _floatingTabsHeight = GlassTabBar.extent;

  /// One row of text tabs; the selected one sits on a raised pill.
  /// Used when search lives in the bottom dock, so the top bar is just this.
  /// The tabs are centred between the account's face and the bell; a page
  /// with a single tab still gets a capsule around it.
  Widget _glassTabBar() {
    return Padding(
      // the main page already pads the body below the status bar
      padding: GlassTabBar.margin,
      child: SizedBox(
        height: GlassTabBar.height,
        child: Row(
          spacing: 8,
          children: [
            // the account's face at the left, on the same glass as the tabs:
            // a tap goes to 我的, as the avatar on the old top bar did. Only
            // where the dock is the bar's nav: the side rail already holds
            // the account on a wide screen, and the face there is enough
            if (_mainController.bottomNavFor(MediaQuery.sizeOf(context)))
              _homeAvatar(),
            Expanded(
              // the row keeps to what it holds and sits in the middle of
              // the room between the avatar and the bell, unless the switch
              // in 设置 › PiliGlass 特性 says to start at the left; a page
              // with a single tab gets a small capsule with that one tab
              child: Obx(
                () => CenteredGlassTabs(
                  controller: _homeController.tabController,
                  labels: _homeController.tabs.map((e) => e.label).toList(),
                  centered: GlassFeatures.centerTabs.value,
                  onTap: (_) {
                    if (!_homeController.tabController.indexIsChanging) {
                      _homeController.animateToTop();
                    }
                  },
                ),
              ),
            ),
            // on a wide screen the messages are on the rail's glass block,
            // unless the window is too short for them there
            Obx(
              () =>
                  _mainController.accountService.isLogin.value &&
                      (_mainController.bottomNavFor(
                            MediaQuery.sizeOf(context),
                          ) ||
                          !_mainController.railMessages.value)
                  ? GlassCapsule(
                      refraction: true,
                      padding: EdgeInsets.zero,
                      child: SizedBox.square(
                        dimension: GlassTabBar.height,
                        child: Center(child: msgBadge(_mainController)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// The account's face at the top left of the feed, on the same glass as
  /// the tabs and the bell, 32 round in a 44 block; a tap goes to 我的.
  Widget _homeAvatar() => Semantics(
    label: '我的',
    button: true,
    child: GlassCapsule(
      refraction: true,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: GlassTabBar.height,
        child: Center(
          child: Obx(() {
            final account = _mainController.accountService;
            final face = account.isLogin.value ? account.face.value : null;
            return GestureDetector(
              behavior: .opaque,
              // signed in it goes to 我的, signed out it asks to sign in
              onTap: () {
                if (account.isLogin.value) {
                  _mainController.toMinePage();
                } else {
                  Get.toNamed('/loginPage');
                }
              },
              child: SizedBox.square(
                dimension: 32,
                child: ClipOval(
                  child: face == null || face.isEmpty
                      ? Image.asset(
                          Assets.avatarPlaceHolder,
                          fit: BoxFit.cover,
                        )
                      : NetworkImgLayer(
                          type: .avatar,
                          width: 32,
                          height: 32,
                          src: face,
                        ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );

  Widget customAppBar() {
    const padding = EdgeInsets.fromLTRB(14, 6, 14, 0);
    final child = Row(
      children: [
        searchBar(),
        const SizedBox(width: 4),
        msgBadge(_mainController),
        const SizedBox(width: 8),
        userAvatar(colorScheme: _colorScheme, mainController: _mainController),
      ],
    );
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return CustomHeightWidget(
              offset: Offset(0, -offset),
              height: Style.topBarHeight - offset,
              child: Padding(
                padding: padding,
                child: child,
              ),
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return AnimatedOpacity(
            opacity: showSearchBar ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedContainer(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              height: showSearchBar ? Style.topBarHeight : 0,
              padding: padding,
              child: child,
            ),
          );
        });
      }
    }
    return Container(
      height: Style.topBarHeight,
      padding: padding,
      child: child,
    );
  }

  Widget searchBar() {
    const borderRadius = BorderRadius.all(Radius.circular(25));
    return Expanded(
      child: SizedBox(
        height: 44,
        child: Material(
          borderRadius: borderRadius,
          color: _colorScheme.onSecondaryContainer.withValues(alpha: 0.05),
          child: InkWell(
            borderRadius: borderRadius,
            splashColor: _colorScheme.primaryContainer.withValues(
              alpha: 0.3,
            ),
            onTap: () => Get.toNamed(
              '/search',
              parameters: _homeController.enableSearchWord
                  ? {'hintText': _homeController.defaultSearch.value}
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_outlined,
                  color: _colorScheme.onSecondaryContainer,
                  semanticLabel: '搜索',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () => Text(
                      _homeController.defaultSearch.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _colorScheme.outline),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: 34,
                height: 34,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Obx(
                  () => MineController.anonymity.value
                      ? IgnorePointer(
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              size: 14,
                              MdiIcons.incognito,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          onPressed: () {
            mainController
              ..clearUnreadMsg()
              ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
            Get.toNamed('/whisper');
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count != null,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count != null ? Text(count) : null,
            child: Icon(
              Revamp.enabled
                  ? UiIcons.of(Icons.notifications_none)
                  : Icons.notifications_none,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}

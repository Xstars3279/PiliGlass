import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/mine_tab_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/mine/widgets/fav_item.dart';
import 'package:PiliPlus/pages/mine/widgets/history_item.dart';
import 'package:PiliPlus/pages/mine/widgets/later_item.dart';
import 'package:PiliPlus/pages/mine/widgets/sub_item.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class MinePage extends StatefulWidget {
  const MinePage({super.key, this.showBackBtn = false});

  final bool showBackBtn;

  @override
  State<MinePage> createState() => _MediaPageState();
}

class _MediaPageState extends CommonPageState<MinePage>
    with AutomaticKeepAliveClientMixin {
  final MineController controller = Get.putOrFind(MineController.new);
  late final MainController _mainController = Get.find<MainController>();
  late ThemeData theme;

  @override
  bool get wantKeepAlive => true;

  bool get checkPage =>
      _mainController.navigationBars[0] != NavigationBarType.mine &&
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  /// the redesigned page, together with the liquid glass dock
  bool get _modern => _mainController.dockSearch;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_modern) return _buildModern();
    final secondary = theme.colorScheme.secondary;
    return Column(
      children: [
        Padding(
          padding: const .symmetric(vertical: 10),
          child: _buildHeaderActions,
        ),
        Expanded(
          child: Material(
            type: .transparency,
            child: refreshIndicator(
              onRefresh: controller.onRefresh,
              child: onBuild(
                ListView(
                  padding: const .only(bottom: 150),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildUserInfo(theme, secondary),
                    _buildActions(secondary),
                    for (final tab in controller.mineTabs)
                      switch (tab) {
                        .favorite => Obx(_buildFav),
                        .history => Obx(_buildHistory),
                        .later => Obx(_buildLater),
                        .sub => Obx(_buildSub),
                      },
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Color primary) {
    return Row(
      mainAxisAlignment: .spaceEvenly,
      children: controller.list
          .map(
            (e) => Flexible(
              child: InkWell(
                onTap: e.onTap,
                borderRadius: Style.mdRadius,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Column(
                      spacing: 6,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      children: [
                        Icon(e.icon, color: primary),
                        Text(
                          e.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget get _buildHeaderActions {
    const iconSize = 22.0;
    const padding = EdgeInsets.all(8);
    const style = ButtonStyle(tapTargetSize: .shrinkWrap);
    return PlayerBar(
      left: widget.showBackBtn
          ? const Padding(
              padding: EdgeInsets.only(left: 8),
              child: BackButton(),
            )
          : const SizedBox.shrink(),
      right: Row(
        spacing: 5,
        mainAxisSize: .min,
        children: [
          if (!_mainController.hasHome) ...[
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '搜索',
              onPressed: () => Get.toNamed('/search'),
              icon: const Icon(Icons.search),
            ),
            msgBadge(_mainController),
          ],
          if (GStorage.reply != null)
            IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '评论记录',
              onPressed: () => Get.toNamed('/myReply'),
              icon: const Icon(Icons.message_outlined),
            ),
          Obx(
            () {
              final anonymity = MineController.anonymity.value;
              return IconButton(
                iconSize: iconSize,
                padding: padding,
                style: style,
                tooltip: "${anonymity ? '退出' : '进入'}无痕模式",
                onPressed: MineController.onChangeAnonymity,
                icon: anonymity
                    ? const Icon(MdiIcons.incognito)
                    : const Icon(MdiIcons.incognitoOff),
              );
            },
          ),
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '切换账号',
            onPressed: () => LoginPageController.switchAccountDialog(context),
            icon: const Icon(Icons.switch_account_outlined),
          ),
          Obx(
            () => IconButton(
              iconSize: iconSize,
              padding: padding,
              style: style,
              tooltip: '切换至${controller.nextThemeType.label}主题',
              onPressed: controller.onChangeTheme,
              icon: controller.themeType.value.icon,
            ),
          ),
          IconButton(
            iconSize: iconSize,
            padding: padding,
            style: style,
            tooltip: '设置',
            onPressed: () => Get.toNamed('/setting', preventDuplicates: false),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildUserInfo(ThemeData theme, Color secondary) {
    final style = TextStyle(
      fontSize: theme.textTheme.titleMedium!.fontSize,
      fontWeight: FontWeight.bold,
    );
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final coinLabelStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      color: theme.colorScheme.outline,
    );
    final coinValStyle = TextStyle(
      fontSize: theme.textTheme.labelMedium!.fontSize,
      fontWeight: FontWeight.bold,
      color: secondary,
    );
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final hasLevel = levelInfo != null;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      final userStat = controller.userStat.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: controller.onLogin,
            onLongPress: () {
              Feedback.forLongPress(context);
              controller.onLogin(true);
            },
            onSecondaryTap: PlatformUtils.isMobile
                ? null
                : () => controller.onLogin(true),
            child: Row(
              mainAxisSize: .min,
              children: [
                const SizedBox(width: 20),
                userInfo.face != null
                    ? Stack(
                        clipBehavior: .none,
                        children: [
                          NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: 55,
                            height: 55,
                          ),
                          if (isVip)
                            Positioned(
                              right: -1,
                              bottom: -2,
                              child: SvgPicture.asset(
                                Assets.vipIcon,
                                height: 19,
                                semanticsLabel: "大会员",
                              ),
                            ),
                        ],
                      )
                    : ClipOval(
                        child: Image.asset(
                          width: 55,
                          height: 55,
                          cacheHeight: 55.cacheSize(context),
                          Assets.avatarPlaceHolder,
                          semanticLabel: "默认头像",
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              userInfo.uname ?? '点击登录',
                              style: theme.textTheme.titleMedium!.copyWith(
                                height: 1,
                                color: isVip && userInfo.vipType == 2
                                    ? theme.colorScheme.vipColor
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          BiliUtils.levelPicture(
                            levelInfo?.currentLevel ?? 0,
                            isSeniorMember: userInfo.isSeniorMember == 1,
                            height: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '硬币 ',
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: userInfo.money?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "      经验 ",
                              style: coinLabelStyle,
                            ),
                            TextSpan(
                              text: levelInfo?.currentExp?.toString() ?? '-',
                              style: coinValStyle,
                            ),
                            TextSpan(
                              text: "/${levelInfo?.nextExp ?? '-'}",
                              style: coinLabelStyle,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 225),
                        child: LinearProgressIndicator(
                          minHeight: 2.25,
                          value: hasLevel
                              ? levelInfo.currentExp! / levelInfo.nextExp!
                              : 0,
                          backgroundColor: theme.colorScheme.outline.withValues(
                            alpha: 0.4,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(secondary),
                          stopIndicatorColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: .spaceEvenly,
            children: [
              _btn(
                count: userStat.dynamicCount,
                countStyle: style,
                name: '动态',
                labelStyle: labelStyle,
                onTap: () => controller.push('memberDynamics'),
              ),
              _btn(
                count: userStat.following,
                countStyle: style,
                name: '关注',
                labelStyle: labelStyle,
                onTap: () => controller.push('follow'),
              ),
              _btn(
                count: userStat.follower,
                countStyle: style,
                name: '粉丝',
                labelStyle: labelStyle,
                onTap: () => controller.push('fan'),
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _btn({
    required int? count,
    required TextStyle countStyle,
    required String name,
    required TextStyle? labelStyle,
    required VoidCallback onTap,
  }) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: Style.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 80),
          child: AspectRatio(
            aspectRatio: 1,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: countStyle,
                ),
                Text(
                  name,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _autoRefresh(MineRefreshMixin tabCtr) => Timer(
    const Duration(milliseconds: 150),
    () => tabCtr.onRefresh(isManual: false),
  );

  Widget _buildFav({bool previewOnly = false}) {
    return _buildTab(
      previewOnly: previewOnly,
      .favorite,
      controller.favCtr!,
      itemBuilder: (element) => FavFolderItem(
        item: element,
        onPop: () => _autoRefresh(controller.favCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/fav',
      )?.whenComplete(() => _autoRefresh(controller.favCtr!)),
    );
  }

  Widget _buildHistory({bool previewOnly = false}) {
    return _buildTab(
      previewOnly: previewOnly,
      .history,
      controller.historyCtr!,
      itemBuilder: (element) => MineHistoryItem(
        item: element,
        onPop: () => _autoRefresh(controller.historyCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/history',
      )?.whenComplete(() => _autoRefresh(controller.historyCtr!)),
    );
  }

  Widget _buildLater({bool previewOnly = false}) {
    return _buildTab(
      previewOnly: previewOnly,
      .later,
      controller.laterCtr!,
      itemBuilder: (element) => MineLaterItem(
        item: element,
        onPop: () => _autoRefresh(controller.laterCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/later',
      )?.whenComplete(() => _autoRefresh(controller.laterCtr!)),
    );
  }

  Widget _buildSub({bool previewOnly = false}) {
    return _buildTab(
      previewOnly: previewOnly,
      .sub,
      controller.subCtr!,
      itemBuilder: (element) => MineSubItem(
        item: element,
        onPop: () => _autoRefresh(controller.subCtr!),
      ),
      onPushDetail: () => Get.toNamed(
        '/subscription',
      )?.whenComplete(() => _autoRefresh(controller.subCtr!)),
    );
  }

  Widget _buildTab<R, T>(
    MineTabType tab,
    MineRefreshMixin<R, T> tabCtr, {
    required Widget Function(T element) itemBuilder,
    required VoidCallback onPushDetail,
    bool previewOnly = false,
  }) {
    final Widget child;
    switch (tabCtr.loadingState.value) {
      case Loading():
        return const SizedBox.shrink();
      case Success(:final response):
        if (response == null || response.isEmpty) {
          return const SizedBox.shrink();
        }
        child = SizedBox(
          height: 180,
          child: ListView.separated(
            itemCount: response.length,
            controller: tabCtr.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const .only(left: 20, top: 10, right: 20),
            itemBuilder: (context, index) {
              if (index == response.length - 1) {
                tabCtr.onLoadMore();
              }
              return SizedBox(width: 180, child: itemBuilder(response[index]));
            },
            scrollDirection: .horizontal,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
          ),
        );
      case Error(:final errMsg):
        if (errMsg == null) return const SizedBox.shrink();
        child = SizedBox(
          height: 160,
          child: Center(child: Text(errMsg, textAlign: .center)),
        );
    }
    // the redesigned page shows this list inside an expandable row
    if (previewOnly) return child;
    final secondary = theme.colorScheme.secondary;
    final section = Column(
      children: [
        if (!_modern)
          Divider(
            height: 20,
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ListTile(
          dense: true,
          onTap: onPushDetail,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${tab.label}  ',
                    style: const TextStyle(fontSize: 16, fontWeight: .bold),
                  ),
                  if (tabCtr.count != null)
                    TextSpan(
                      text: '${tabCtr.count}  ',
                      style: TextStyle(color: secondary),
                    ),
                  WidgetSpan(
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: tabCtr.onRefresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        child,
      ],
    );
    if (!_modern) return section;
    return _group(
      child: Padding(padding: const .only(bottom: 14), child: section),
    );
  }

  /// A rounded group on the page, the way the redesign sets off sections.
  Widget _group({required Widget child}) => Padding(
    padding: const .fromLTRB(12, 0, 12, 12),
    // a Material, so the ink ripples inside are drawn on top of the color
    child: Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: const .all(.circular(24)),
      clipBehavior: .antiAlias,
      child: child,
    ),
  );

  Widget _buildModern() {
    return Stack(
      children: [
        // a banner made from the avatar, blurred, fading into the page
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 280,
          child: Obx(
            () => _ProfileBanner(face: controller.userInfo.value.face),
          ),
        ),
        Column(
          children: [
            Padding(
              padding: const .symmetric(vertical: 10),
              child: _buildHeaderActions,
            ),
            Expanded(
              child: Material(
                type: .transparency,
                child: refreshIndicator(
                  onRefresh: controller.onRefresh,
                  child: onBuild(
                    ListView(
                      padding: const .only(bottom: 150),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildProfile(),
                        const SizedBox(height: 18),
                        _buildStatChips(),
                        const SizedBox(height: 12),
                        _buildMenu(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// the rows whose list preview is unfolded
  final Set<MineTabType> _expanded = {};

  /// The shortcuts and the sections as one list of rows, each with its own
  /// colored icon. Rows that had a preview section (favorites, history...)
  /// unfold it in place; the others open their page.
  Widget _buildMenu() {
    final outline = theme.colorScheme.outline;
    VoidCallback? shortcut(String title) {
      for (final e in controller.list) {
        if (e.title == title) return e.onTap;
      }
      return null;
    }

    Widget? preview(MineTabType tab) => switch (tab) {
      .favorite => _buildFav(previewOnly: true),
      .history => _buildHistory(previewOnly: true),
      .later => _buildLater(previewOnly: true),
      .sub => _buildSub(previewOnly: true),
    };

    Widget row({
      required IconData icon,
      required Color color,
      required String title,
      required VoidCallback? onOpen,
      MineTabType? tab,
      int? count,
    }) {
      final expandable = tab != null && controller.mineTabs.contains(tab);
      final expanded = expandable && _expanded.contains(tab);
      final tile = ListTile(
        leading: RevampIconTile(icon: Icon(icon), color: color),
        title: Text(title),
        trailing: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [
            if (count != null)
              Text(
                '$count',
                style: TextStyle(
                  color: outline,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (expandable)
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: Icon(Icons.expand_more_rounded, color: outline),
              )
            else
              Icon(Icons.chevron_right_rounded, color: outline),
          ],
        ),
        onTap: expandable
            ? () => setState(
                () => expanded ? _expanded.remove(tab) : _expanded.add(tab),
              )
            : onOpen,
      );
      if (!expandable) return tile;
      return Column(
        children: [
          tile,
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: .topCenter,
            child: expanded
                ? Column(
                    children: [
                      ?preview(tab),
                      Align(
                        alignment: .centerRight,
                        child: TextButton(
                          onPressed: onOpen,
                          child: const Text('查看全部'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
    }

    return Column(
      children: [
        // counts arrive with the sections' data
        Obx(() {
          controller.favCtr?.loadingState.value;
          controller.historyCtr?.loadingState.value;
          controller.laterCtr?.loadingState.value;
          controller.subCtr?.loadingState.value;
          return _group(
            child: Column(
              children: [
                row(
                  icon: Icons.download_rounded,
                  color: const Color(0xFFFF6F91),
                  title: '离线缓存',
                  onOpen: shortcut('离线缓存'),
                ),
                row(
                  icon: Icons.history_rounded,
                  color: const Color(0xFF7B8CFF),
                  title: '观看记录',
                  tab: .history,
                  onOpen: shortcut('观看记录'),
                ),
                row(
                  icon: Icons.star_rounded,
                  color: const Color(0xFF3FB6E8),
                  title: '我的收藏',
                  tab: .favorite,
                  count: controller.favCtr?.count,
                  onOpen: () => Get.toNamed('/fav'),
                ),
                row(
                  icon: Icons.watch_later_rounded,
                  color: const Color(0xFFF2A73B),
                  title: '稍后再看',
                  tab: .later,
                  count: controller.laterCtr?.count,
                  onOpen: shortcut('稍后再看'),
                ),
                row(
                  icon: Icons.subscriptions_rounded,
                  color: const Color(0xFF55B97A),
                  title: '我的订阅',
                  tab: .sub,
                  count: controller.subCtr?.count,
                  onOpen: shortcut('我的订阅'),
                ),
              ],
            ),
          );
        }),
        _group(
          child: Column(
            children: [
              row(
                icon: Icons.settings_rounded,
                color: const Color(0xFF8A8296),
                title: '设置',
                onOpen: () => Get.toNamed('/setting', preventDuplicates: false),
              ),
              ListTile(
                leading: const RevampIconTile(
                  icon: Icon(Icons.info_rounded),
                  color: Color(0xFFE0457B),
                ),
                title: const Text('关于 PiliPlus'),
                trailing: Row(
                  mainAxisSize: .min,
                  spacing: 6,
                  children: [
                    Text(
                      BuildConfig.versionName,
                      style: TextStyle(color: outline),
                    ),
                    Icon(Icons.chevron_right_rounded, color: outline),
                  ],
                ),
                onTap: () => Get.to(() => const AboutPage()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    final colorScheme = theme.colorScheme;
    return Obx(() {
      final userInfo = controller.userInfo.value;
      final levelInfo = userInfo.levelInfo;
      final isVip = userInfo.vipStatus != null && userInfo.vipStatus! > 0;
      const size = 76.0;
      return GestureDetector(
        behavior: .opaque,
        onTap: controller.onLogin,
        onLongPress: () {
          Feedback.forLongPress(context);
          controller.onLogin(true);
        },
        onSecondaryTap: PlatformUtils.isMobile
            ? null
            : () => controller.onLogin(true),
        child: Padding(
          padding: const .symmetric(horizontal: 20),
          child: Row(
            spacing: 16,
            children: [
              Stack(
                clipBehavior: .none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: .circle,
                      border: Border.all(color: colorScheme.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: userInfo.face != null
                        ? NetworkImgLayer(
                            src: userInfo.face,
                            type: .avatar,
                            width: size,
                            height: size,
                          )
                        : ClipOval(
                            child: Image.asset(
                              Assets.avatarPlaceHolder,
                              width: size,
                              height: size,
                              cacheHeight: size.cacheSize(context),
                              semanticLabel: '默认头像',
                            ),
                          ),
                  ),
                  if (isVip)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SvgPicture.asset(
                        Assets.vipIcon,
                        height: 22,
                        semanticsLabel: '大会员',
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Flexible(
                          child: Text(
                            userInfo.uname ?? '点击登录',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: theme.textTheme.titleLarge!.copyWith(
                              fontWeight: .w900,
                              color: isVip && userInfo.vipType == 2
                                  ? colorScheme.vipColor
                                  : null,
                            ),
                          ),
                        ),
                        BiliUtils.levelPicture(
                          levelInfo?.currentLevel ?? 0,
                          isSeniorMember: userInfo.isSeniorMember == 1,
                          height: 11,
                        ),
                      ],
                    ),
                    Text(
                      '硬币 ${userInfo.money?.toString() ?? '-'}   ·   '
                      '经验 ${levelInfo?.currentExp ?? '-'}/${levelInfo?.nextExp ?? '-'}',
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    ClipRRect(
                      borderRadius: const .all(.circular(3)),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: levelInfo != null
                            ? levelInfo.currentExp! / levelInfo.nextExp!
                            : 0,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        stopIndicatorColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildStatChips() {
    final colorScheme = theme.colorScheme;
    Widget chip(int? count, String label, VoidCallback onTap) => Expanded(
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const .all(.circular(20)),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const .symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: [
                Text(
                  count?.toString() ?? '-',
                  style: theme.textTheme.titleLarge!.copyWith(
                    fontWeight: .w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Obx(() {
      final stat = controller.userStat.value;
      return Padding(
        padding: const .symmetric(horizontal: 12),
        child: Row(
          spacing: 10,
          children: [
            chip(
              stat.dynamicCount,
              '动态',
              () => controller.push('memberDynamics'),
            ),
            chip(stat.following, '关注', () => controller.push('follow')),
            chip(stat.follower, '粉丝', () => controller.push('fan')),
          ],
        ),
      );
    });
  }
}

/// The page's top, tinted by the user's avatar: blurred far past
/// recognition, then fading into the page.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.face});

  final String? face;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final Widget base = face == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: .topLeft,
                end: .bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer,
                ],
              ),
            ),
          )
        // a strong blur spreads well past its box; clip it, or the spread
        // shows as a band below the banner that the fade does not cover
        : LayoutBuilder(
            builder: (context, constraints) => ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: 36,
                  sigmaY: 36,
                  tileMode: .clamp,
                ),
                child: NetworkImgLayer(
                  src: face,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          );
    // fade the banner itself out instead of painting the page color over
    // it, so it meets whatever the page's background is without a seam
    return ShaderMask(
      blendMode: .dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: .topCenter,
        end: .bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [0.3, 1],
      ).createShader(rect),
      child: Opacity(opacity: 0.55, child: base),
    );
  }
}

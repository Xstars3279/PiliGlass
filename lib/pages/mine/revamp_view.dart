part of 'view.dart';

/// The redesigned 「我的」 page, shown together with the liquid glass dock.
/// Kept apart from view.dart so that file stays close to upstream.
extension _MineRevamp on _MediaPageState {
  /// the redesigned page, together with the liquid glass dock
  bool get _modern => _mainController.dockSearch;

  /// the header's buttons on one capsule of the dock's glass
  Widget _headerGroup(Widget row) => _modern
      ? Padding(
          padding: const .only(right: 12),
          child: LiquidPress(
            maxGrowth: 8,
            child: GlassCapsule(
              padding: const .symmetric(horizontal: 4, vertical: 2),
              child: row,
            ),
          ),
        )
      : row;

  Widget _buildModern() {
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
                  padding: .only(bottom: UiSpace.underDock(context)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // who and their numbers straight on the page
                    Padding(
                      padding: const .only(
                        top: UiSpace.s8,
                        bottom: UiSpace.s24,
                      ),
                      child: Column(
                        children: [_buildProfile(), _buildStatRow()],
                      ),
                    ),
                    _MineMenu(
                      controller: controller,
                      preview: (tab) => switch (tab) {
                        .favorite => _buildFav(previewOnly: true),
                        .history => _buildHistory(previewOnly: true),
                        .later => _buildLater(previewOnly: true),
                        .sub => _buildSub(previewOnly: true),
                      },
                    ),
                  ],
                ),
              ),
            ),
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
      const size = 64.0;
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
          padding: const .symmetric(horizontal: UiSpace.page),
          child: Row(
            spacing: UiSpace.s16,
            children: [
              Stack(
                clipBehavior: .none,
                children: [
                  SizedBox(
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
                    // the name in the text's color, vip or not: the pink is
                    // the badge's alone; all the width beside the avatar
                    Text(
                      userInfo.uname ?? '点击登录',
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    // the level at the end of the coins and experience
                    Row(
                      spacing: UiSpace.s8,
                      children: [
                        Flexible(
                          child: Text(
                            '硬币 ${userInfo.money?.toString() ?? '-'}  ·  '
                            '经验 ${levelInfo?.currentExp ?? '-'}/${levelInfo?.nextExp ?? '-'}',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: UiType.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
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
                    // one continuous bar, 4 high, round at the ends
                    ClipRRect(
                      borderRadius: const .all(.circular(2)),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: levelInfo != null
                            ? levelInfo.currentExp! / levelInfo.nextExp!
                            : 0,
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        color: colorScheme.primary,
                        stopIndicatorColor: Colors.transparent,
                        trackGap: 0,
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

  /// 动态, 关注, 粉丝 as one row of the profile card, split by thin rules
  Widget _buildStatRow() {
    final colorScheme = theme.colorScheme;
    Widget stat(int? count, String label, VoidCallback onTap) => Expanded(
      child: InkWell(
        customBorder: Revamp.tileShape,
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(vertical: 10),
          child: Column(
            spacing: 2,
            children: [
              Text(
                count?.toString() ?? '-',
                style: theme.textTheme.titleLarge!.copyWith(
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
    );
    return Obx(() {
      final stat0 = controller.userStat.value;
      return Padding(
        padding: const .fromLTRB(UiSpace.s8, UiSpace.s16, UiSpace.s8, 0),
        child: Row(
          children: [
            stat(
              stat0.dynamicCount,
              '动态',
              () => controller.push('memberDynamics'),
            ),
            stat(stat0.following, '关注', () => controller.push('follow')),
            stat(stat0.follower, '粉丝', () => controller.push('fan')),
          ],
        ),
      );
    });
  }
}

/// The shortcuts and the sections as one list of rows, each with its own
/// colored icon. Rows that had a preview section (favorites, history...)
/// unfold it in place; the others open their page.
class _MineMenu extends StatefulWidget {
  const _MineMenu({required this.controller, required this.preview});

  final MineController controller;

  /// the section's list, shown when its row is unfolded
  final Widget Function(MineTabType tab) preview;

  @override
  State<_MineMenu> createState() => _MineMenuState();
}

class _MineMenuState extends State<_MineMenu> {
  /// the rows whose list preview is unfolded by their arrow
  final Set<MineTabType> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final outline = ColorScheme.of(context).onSurfaceVariant;
    // each row ends in a 40 square holding its arrow, so the arrows line up
    Widget end(Widget icon) =>
        SizedBox.square(dimension: 40, child: Center(child: icon));
    final countStyle = UiType.caption.copyWith(
      color: outline,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    VoidCallback? shortcut(String title) {
      for (final e in controller.list) {
        if (e.title == title) return e.onTap;
      }
      return null;
    }

    Widget row({
      required IconData icon,
      required String title,
      required VoidCallback? onOpen,
      MineTabType? tab,
      int? count,
    }) {
      final expandable = tab != null && controller.mineTabs.contains(tab);
      final expanded = expandable && _expanded.contains(tab);
      final tile = ListTile(
        leading: RevampIconTile(icon: Icon(icon)),
        title: Text(title),
        contentPadding: const .only(left: UiSpace.card, right: UiSpace.s8),
        trailing: Row(
          mainAxisSize: .min,
          spacing: UiSpace.s4,
          children: [
            if (count != null) Text('$count', style: countStyle),
            // only the arrow unfolds the preview; the rest of the row
            // opens the whole list
            if (expandable)
              IconButton(
                tooltip: expanded ? '收起' : '展开',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: () => setState(
                  () => expanded ? _expanded.remove(tab) : _expanded.add(tab),
                ),
                icon: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  // long enough for the spring to settle
                  duration: const Duration(milliseconds: 700),
                  curve: SpringCurve(
                    Springs.bouncy,
                    const Duration(milliseconds: 700),
                  ),
                  child: Icon(
                    UiIcons.of(Icons.expand_more_rounded),
                    size: 20,
                    color: outline,
                  ),
                ),
              )
            else
              end(
                Icon(
                  UiIcons.of(Icons.chevron_right_rounded),
                  size: 20,
                  color: outline,
                ),
              ),
          ],
        ),
        onTap: onOpen,
      );
      if (!expandable) return tile;
      return Column(
        children: [
          tile,
          AnimatedSize(
            duration: const Duration(milliseconds: 560),
            curve: SpringCurve(
              Springs.smooth,
              const Duration(milliseconds: 560),
            ),
            alignment: .topCenter,
            child: expanded
                ? Column(
                    children: [
                      widget.preview(tab),
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

    Widget section(MineTabType tab) => switch (tab) {
      .history => row(
        icon: Icons.history_rounded,
        title: '观看记录',
        tab: .history,
        onOpen: shortcut('观看记录'),
      ),
      .favorite => row(
        icon: Icons.star_rounded,
        title: '我的收藏',
        tab: .favorite,
        count: controller.favCtr?.count,
        onOpen: () => Get.toNamed('/fav'),
      ),
      .later => row(
        icon: Icons.watch_later_rounded,
        title: '稍后再看',
        tab: .later,
        count: controller.laterCtr?.count,
        onOpen: shortcut('稍后再看'),
      ),
      .sub => row(
        icon: Icons.subscriptions_rounded,
        title: '我的订阅',
        tab: .sub,
        count: controller.subCtr?.count,
        onOpen: shortcut('我的订阅'),
      ),
    };

    return Column(
      children: [
        // counts arrive with the sections' data
        Obx(() {
          controller.favCtr?.loadingState.value;
          controller.historyCtr?.loadingState.value;
          controller.laterCtr?.loadingState.value;
          controller.subCtr?.loadingState.value;
          return RevampGroup(
            // 16 to the group of 设置 and 关于
            margin: const .fromLTRB(
              UiSpace.page,
              0,
              UiSpace.page,
              UiSpace.s16,
            ),
            child: Column(
              children: revampDivided([
                row(
                  icon: Icons.download_rounded,
                  title: '离线缓存',
                  onOpen: shortcut('离线缓存'),
                ),
                // only the cards chosen in the settings, in their order
                for (final tab in controller.mineTabs) section(tab),
              ]),
            ),
          );
        }),
        RevampGroup(
          child: Column(
            children: revampDivided([
              row(
                icon: Icons.settings_rounded,
                title: '设置',
                onOpen: () => Get.toNamed('/setting', preventDuplicates: false),
              ),
              ListTile(
                leading: const RevampIconTile(icon: Icon(Icons.info_rounded)),
                title: const Text('关于 PiliGlass'),
                contentPadding: const .only(
                  left: UiSpace.card,
                  right: UiSpace.s8,
                ),
                trailing: Row(
                  mainAxisSize: .min,
                  spacing: UiSpace.s4,
                  children: [
                    Text(BuildConfig.versionName, style: countStyle),
                    end(
                      Icon(
                        UiIcons.of(Icons.chevron_right_rounded),
                        size: 20,
                        color: outline,
                      ),
                    ),
                  ],
                ),
                onTap: () => Get.to(() => const AboutPage()),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

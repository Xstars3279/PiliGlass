part of 'view.dart';

/// The redesigned 「我的」 page, shown together with the liquid glass dock.
/// Kept apart from view.dart so that file stays close to upstream.
extension _MineRevamp on _MediaPageState {
  /// the redesigned page, together with the liquid glass dock
  bool get _modern => _mainController.dockSearch;

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
  /// the rows whose list preview is unfolded
  final Set<MineTabType> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final outline = ColorScheme.of(context).outline;
    VoidCallback? shortcut(String title) {
      for (final e in controller.list) {
        if (e.title == title) return e.onTap;
      }
      return null;
    }

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

    return Column(
      children: [
        // counts arrive with the sections' data
        Obx(() {
          controller.favCtr?.loadingState.value;
          controller.historyCtr?.loadingState.value;
          controller.laterCtr?.loadingState.value;
          controller.subCtr?.loadingState.value;
          return RevampGroup(
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
        RevampGroup(
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

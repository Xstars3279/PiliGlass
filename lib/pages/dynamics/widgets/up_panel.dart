import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/live_follow/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class UpPanel extends StatefulWidget {
  const UpPanel({
    super.key,
    required this.upData,
    required this.dynamicsController,
  });

  final FollowUpModel upData;
  final DynamicsController dynamicsController;

  @override
  State<UpPanel> createState() => _UpPanelState();
}

class _UpPanelState extends State<UpPanel> {
  late final controller = widget.dynamicsController;
  late final isTop = controller.upPanelPosition == UpPanelPosition.top;

  void toFollowPage() => Get.to(const LiveFollowPage());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upData = widget.upData;
    final upList = upData.upList;
    final liveList = upData.liveUsers?.items;
    return CustomScrollView(
      scrollDirection: isTop ? .horizontal : .vertical,
      physics: const AlwaysScrollableScrollPhysics(),
      controller: controller.scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: InkWell(
            onTap: () => setState(() {
              controller.showLiveUp = !controller.showLiveUp;
            }),
            onLongPress: toFollowPage,
            onSecondaryTap: PlatformUtils.isMobile ? null : toFollowPage,
            child: Container(
              alignment: .center,
              height: isTop ? 76 : 60,
              padding: isTop ? const .only(left: 12, right: 6) : null,
              child: Text.rich(
                textAlign: .center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Live(${upData.liveUsers?.count ?? 0})',
                    ),
                    if (!isTop) ...[
                      const TextSpan(text: '\n'),
                      WidgetSpan(
                        alignment: .middle,
                        child: Icon(
                          controller.showLiveUp
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ] else
                      WidgetSpan(
                        alignment: .middle,
                        child: Icon(
                          controller.showLiveUp
                              ? Icons.keyboard_arrow_right
                              : Icons.keyboard_arrow_left,
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (controller.showLiveUp && liveList != null && liveList.isNotEmpty)
          SliverList.builder(
            itemCount: liveList.length,
            itemBuilder: (context, index) {
              return upItemBuild(theme, liveList[index]);
            },
          ),
        SliverToBoxAdapter(
          child: upItemBuild(theme, UpItem(face: '', uname: '全部动态', mid: -1)),
        ),
        SliverToBoxAdapter(
          child: Obx(
            () => upItemBuild(
              theme,
              UpItem(
                uname: '我',
                face: controller.accountService.face.value,
                mid: Accounts.main.mid,
              ),
            ),
          ),
        ),
        if (upList != null && upList.isNotEmpty)
          SliverList.builder(
            itemCount: upList.length,
            itemBuilder: (context, index) {
              return upItemBuild(theme, upList[index]);
            },
          ),
        if (!isTop) const SliverToBoxAdapter(child: SizedBox(height: 200)),
      ],
    );
  }

  void _onSelect(UpItem item) {
    item.hasUpdate = false;
    controller.onSelectUp(item.mid);
    setState(() {});
  }

  Widget upItemBuild(ThemeData theme, UpItem item) {
    final currentMid = controller.currentMid;
    final isLive = item is LiveUserItem;
    final isCurrent = isLive || currentMid == item.mid || currentMid == -1;

    final isAll = item.mid == -1;
    void toMemberPage() => Get.toNamed('/member?mid=${item.mid}');

    Widget avatar;
    if (isAll) {
      avatar = DecoratedBox(
        decoration: const BoxDecoration(
          shape: .circle,
          color: Color(0xFF5CB67B),
        ),
        child: Image.asset(
          width: 38,
          height: 38,
          cacheWidth: 38.cacheSize(context),
          Assets.logo2,
          color: Colors.white,
        ),
      );
    } else {
      avatar = Padding(
        padding: EdgeInsets.symmetric(horizontal: Revamp.enabled ? 0 : 4),
        child: NetworkImgLayer(
          width: Revamp.enabled ? 44 : 38,
          height: Revamp.enabled ? 44 : 38,
          src: item.face,
          type: .avatar,
        ),
      );
      if (isLive) {
        avatar = Stack(
          clipBehavior: .none,
          children: [
            avatar,
            Positioned(
              top: isLive && !isTop ? -5 : 0,
              right: -6,
              child: Badge(
                label: const Text(' Live '),
                textColor: theme.colorScheme.onSecondaryContainer,
                backgroundColor: theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.75),
              ),
            ),
          ],
        );
      } else if (Revamp.enabled) {
        // the chosen UP gets a 2 wide accent ring; one with something new a
        // dot at the avatar's top right. No story gradients (5.1)
        final chosen = currentMid == item.mid;
        final fresh = item.hasUpdate ?? false;
        avatar = Stack(
          clipBehavior: .none,
          children: [
            Container(
              padding: EdgeInsets.all(chosen ? 2 : 0),
              decoration: BoxDecoration(
                shape: .circle,
                color: chosen ? theme.colorScheme.primary : null,
              ),
              child: NetworkImgLayer(
                width: Revamp.enabled ? 44 : 38,
                height: Revamp.enabled ? 44 : 38,
                src: item.face,
                type: .avatar,
              ),
            ),
            if (fresh)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: .circle,
                    color: theme.colorScheme.primary,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      } else if (item.hasUpdate ?? false) {
        avatar = Stack(
          clipBehavior: .none,
          children: [
            avatar,
            Positioned(
              top: 0,
              right: 4,
              child: Badge(
                smallSize: 8,
                backgroundColor: theme.colorScheme.primary,
              ),
            ),
          ],
        );
      }
    }

    return SizedBox(
      height: Revamp.enabled ? 84 : 76,
      width: isTop ? (Revamp.enabled ? 64 : 70) : null,
      child: Revamp.pressable(
        InkWell(
          customBorder: Revamp.enabled ? Revamp.tileShape : null,
          onTap: () {
            feedBack();
            if (isLive) {
              PageUtils.toLiveRoom(item.roomId);
            } else {
              _onSelect(item);
            }
          },
          // onDoubleTap: isLive ? () => _onSelect(data) : null,
          onLongPress: !isAll ? toMemberPage : null,
          onSecondaryTap: !isAll && !PlatformUtils.isMobile
              ? toMemberPage
              : null,
          child: Opacity(
            opacity: isCurrent ? 1 : 0.6,
            child: Column(
              spacing: 4,
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                avatar,
                Padding(
                  padding: const .symmetric(horizontal: 2),
                  child: Text(
                    isTop ? '${item.uname}\n' : item.uname!,
                    maxLines: Revamp.enabled ? 1 : 2,
                    overflow: .ellipsis,
                    textAlign: .center,
                    style: TextStyle(
                      color: currentMid == item.mid
                          ? (Revamp.enabled
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.primary)
                          : theme.colorScheme.onSurfaceVariant,
                      height: 1.1,
                      fontSize: Revamp.enabled ? 11 : 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// The middle of the full screen controls in the redesign: a field to send
/// a danmaku, as in the official app, the switch to show them, and their
/// settings, all on the smoked glass of the other buttons over the video.
class RevampDanmakuBar extends StatelessWidget {
  const RevampDanmakuBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSettings,
  });

  final PlPlayerController controller;
  final VoidCallback onSend;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        spacing: 6,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: Revamp.overlayCapsuleDecoration,
                child: Material(
                  type: MaterialType.transparency,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onSend,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        spacing: 8,
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: white),
                          Flexible(
                            child: Text(
                              '发个友善的弹幕见证当下',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xCCFFFFFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Obx(() {
            final on = controller.enableShowDanmaku.value;
            return IconButton(
              tooltip: '${on ? '关闭' : '开启'}弹幕',
              style: Revamp.overlayButtonStyle,
              onPressed: () {
                controller.enableShowDanmaku.value = !on;
                if (!controller.tempPlayerConf) {
                  GStorage.setting.put(SettingBoxKey.enableShowDanmaku, !on);
                }
              },
              icon: Icon(
                on ? CustomIcons.dm_on : CustomIcons.dm_off,
                size: 19,
                color: white,
              ),
            );
          }),
          IconButton(
            tooltip: '弹幕设置',
            style: Revamp.overlayButtonStyle,
            onPressed: onSettings,
            icon: const Icon(CustomIcons.dm_settings, size: 19, color: white),
          ),
        ],
      ),
    );
  }
}

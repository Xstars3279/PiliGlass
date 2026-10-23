part of 'view.dart';

/// The redesigned video page. Kept apart from view.dart so that file stays
/// close to upstream.
extension _VideoRevamp on _VideoDetailPageVState {
  /// the buttons on the video before it plays, like those while it plays
  ButtonStyle? get _overlayBtnStyle =>
      Revamp.enabled ? Revamp.overlayButtonStyle : null;

  /// In portrait the comments are a sheet over the intro instead of a tab,
  /// raised from a preview card below the actions.
  bool get _replyInSheet => Revamp.enabled && videoDetailController.showReply;

  /// Shows [panel] in the comment sheet, e.g. 合集; false if there is no
  /// sheet to show it in.
  bool _showInSheet(Widget Function(VoidCallback close) panel) =>
      _replyInSheet && CommentSheet.showPanel(_videoReplyController, panel);

  /// In place of a tab bar with just 简介: a field to send a danmaku, as
  /// in the official app, and the switch to show them.
  Widget _danmakuBar() {
    final ctr = videoDetailController.plPlayerController;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const .fromLTRB(12, 6, 8, 6),
        child: Row(
          spacing: 6,
          children: [
            Expanded(
              child: Material(
                color: Revamp.tile(colorScheme),
                shape: const StadiumBorder(),
                clipBehavior: .antiAlias,
                child: InkWell(
                  onTap: videoDetailController.showShootDanmakuSheet,
                  child: Padding(
                    padding: const .symmetric(horizontal: 14),
                    child: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        Text(
                          '发个友善的弹幕见证当下',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Obx(() {
              final on = ctr.enableShowDanmaku.value;
              return IconButton(
                tooltip: '${on ? '关闭' : '开启'}弹幕',
                onPressed: () {
                  ctr.enableShowDanmaku.value = !on;
                  if (!ctr.tempPlayerConf) {
                    GStorage.setting.put(SettingBoxKey.enableShowDanmaku, !on);
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: on
                      ? colorScheme.secondaryContainer
                      : Revamp.tile(colorScheme),
                ),
                icon: Icon(
                  on ? CustomIcons.dm_on : CustomIcons.dm_off,
                  size: 21,
                  color: on
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.outline,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _withCommentSheet(Widget page) {
    if (!_replyInSheet) return page;
    return CommentSheet(
      heroTag: heroTag,
      cover: videoDetailController.cover,
      // what used to open on the comments tab
      openAtStart:
          Pref.defaultShowComment ||
          videoDetailController.args.containsKey(rootRpIdKey),
      child: page,
    );
  }
}

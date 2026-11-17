part of 'view.dart';

/// The redesigned video page. Kept apart from view.dart so that file stays
/// close to upstream.
extension _VideoRevamp on _VideoDetailPageVState {
  /// the buttons on the video before it plays, like those while it plays
  ButtonStyle? get _overlayBtnStyle =>
      Revamp.enabled ? Revamp.overlayButtonStyle : null;

  /// In portrait the comments are a sheet over the intro instead of a tab,
  /// raised from a preview card below the actions.
  bool get _replyInSheet =>
      Revamp.enabled &&
      GlassFeatures.commentSheet &&
      videoDetailController.showReply;

  /// Shows [panel] in the comment sheet, e.g. 合集; false if there is no
  /// sheet to show it in.
  bool _showInSheet(SheetPanelBuilder panel) =>
      _replyInSheet && CommentSheet.showPanel(_videoReplyController, panel);

  /// The sheet covers the player: pause, and play again once it leaves, if
  /// the sheet was what paused it.
  void _onCoverPlayer(bool covering) {
    final player = plPlayerController;
    if (player == null) return;
    if (covering) {
      // set afresh each time: a sheet gone while a dialog was over the page
      // could not hand the player back, and must not play a video the user
      // paused since
      _pausedBySheet = player.playerStatus.isPlaying;
      if (_pausedBySheet) player.pause();
    } else if (_pausedBySheet) {
      _pausedBySheet = false;
      player.play();
    }
  }

  /// In place of a tab bar with just 简介: a field to send a danmaku, as
  /// in the official app, and the switch to show them (6.2).
  Widget _danmakuBar() {
    final ctr = videoDetailController.plPlayerController;
    const capsule = StadiumBorder();
    return SizedBox(
      height: 36 + UiSpace.s8 * 2,
      child: Padding(
        padding: const .symmetric(
          horizontal: UiSpace.page,
          vertical: UiSpace.s8,
        ),
        child: Row(
          spacing: UiSpace.s8,
          children: [
            Expanded(
              child: Material(
                // the same white as a field straight on the page
                color: Revamp.onPage(colorScheme),
                shape: capsule,
                clipBehavior: .antiAlias,
                child: InkWell(
                  onTap: videoDetailController.showShootDanmakuSheet,
                  child: Padding(
                    padding: const .symmetric(horizontal: UiSpace.s12),
                    child: Row(
                      spacing: UiSpace.s8,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        Expanded(
                          child: Text(
                            '发个友善的弹幕见证当下',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: UiType.caption.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                onPressed: ctr.toggleDanmaku,
                style: IconButton.styleFrom(
                  // a 36 round of the field's own white; the icon alone
                  // carries the state
                  backgroundColor: Revamp.onPage(colorScheme),
                  fixedSize: const Size.square(36),
                  minimumSize: const Size.square(36),
                  padding: EdgeInsets.zero,
                ),
                icon: Icon(
                  on ? CustomIcons.dm_on : CustomIcons.dm_off,
                  size: 20,
                  color: on
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// The comment sheet over the whole portrait page, so it can rise over
  /// the player; it stays away while the video is full screen.
  Widget _withCommentSheet(Widget page) {
    if (!_replyInSheet) return page;
    return Obx(() => _commentSheet(isFullScreen, page));
  }

  Widget _commentSheet(bool isFullScreen, Widget page) {
    return CommentSheet(
      heroTag: heroTag,
      cover: videoDetailController.cover,
      hidden: isFullScreen,
      // the intro starts where the player ends
      playerBottom: () {
        final box =
            videoDetailController.childKey.currentContext?.findRenderObject()
                as RenderBox?;
        return box != null && box.hasSize
            ? box.localToGlobal(Offset.zero).dy
            : MediaQuery.sizeOf(context).height * 0.4;
      },
      onCoverPlayer: _onCoverPlayer,
      playerPaused: () =>
          !(plPlayerController?.playerStatus.isPlaying ?? false),
      // what used to open on the comments tab
      openAtStart:
          Pref.defaultShowComment ||
          videoDetailController.args.containsKey(rootRpIdKey),
      child: page,
    );
  }
}

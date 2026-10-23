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

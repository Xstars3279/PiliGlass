part of 'view.dart';

/// The redesigned video page. Kept apart from view.dart so that file stays
/// close to upstream.
extension _VideoRevamp on _VideoDetailPageVState {
  /// In portrait the comments are a sheet over the intro instead of a tab,
  /// raised from a preview card below the actions.
  bool get _replyInSheet => Revamp.enabled && videoDetailController.showReply;

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

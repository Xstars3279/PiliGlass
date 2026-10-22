part of 'view.dart';

/// The reply panel's look in the redesign. Kept apart from view.dart so that
/// file stays close to upstream.
extension _ReplyRevamp on _ReplyPageState {
  /// a taller rounded top, on the tinted surface sheets use
  BoxDecoration get _revampSheet => BoxDecoration(
    borderRadius: const .vertical(top: .circular(28)),
    color: theme.colorScheme.surfaceContainerLow,
  );

  /// the text sits in a rounded field of its own, so no divider is needed
  Widget _revampField(Widget field) => Padding(
    padding: const .fromLTRB(12, 14, 12, 4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const .all(.circular(20)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16),
        child: field,
      ),
    ),
  );

  Widget get _revampSend => Obx(
    () => PressableScale(
      pressedScale: 0.9,
      // as wide as the tonal button it replaces: the toolbar has no room
      child: FilledButton(
        onPressed: enablePublish.value ? onPublishThrottle : null,
        style: FilledButton.styleFrom(
          tapTargetSize: .shrinkWrap,
          visualDensity: .compact,
          padding: const .symmetric(horizontal: 20, vertical: 10),
        ),
        child: const Text('发送'),
      ),
    ),
  );
}

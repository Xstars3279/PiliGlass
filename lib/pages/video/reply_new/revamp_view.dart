part of 'view.dart';

/// The reply panel's look in the redesign: a capsule of glass floating over
/// the keyboard, with the text and the tools inside. Opened from the glass
/// input bar, it grows out of the bar. Kept apart from view.dart so that
/// file stays close to upstream.
extension _ReplyRevamp on _ReplyPageState {
  static const _radius = Revamp.fieldRadius;

  Widget _revampBody() {
    final colorScheme = theme.colorScheme;
    Widget box = GlassBox(
      radius: _radius,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [...buildInputView(), buildImagePreview()],
      ),
    );
    final route = ModalRoute.of(context);
    if (route is PublishRoute && route.morphFrom != null) {
      box = GrowFromBottom(
        from: route.morphFrom!,
        animation: route.animation!,
        radius: _radius,
        child: box,
      );
    }
    return ViewSafeArea(
      child: Align(
        alignment: .bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              Padding(padding: const .fromLTRB(12, 0, 12, 8), child: box),
              // the keyboard's place, or the emotes when they replace it
              Flexible(
                child: buildPanelContainer(colorScheme.surfaceContainerLow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// the text right on the glass, above the tools
  Widget _revampField(Widget field) =>
      Padding(padding: const .fromLTRB(16, 12, 16, 0), child: field);

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

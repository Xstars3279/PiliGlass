part of 'view.dart';

/// The chat's look in the redesign: the input on a capsule of glass that
/// floats over the end of the chat, as the reply panel floats over a
/// video's comments. Kept apart from view.dart so that file stays close to
/// upstream.
extension _WhisperDetailRevamp on _WhisperDetailPageState {
  /// the room the floating input takes over the end of the chat, so the
  /// last message can scroll clear of it
  static const barRoom = 72.0;

  Widget _revampBody(EdgeInsets padding) {
    final hasInput = _whisperDetailController.mid != null;
    return Padding(
      padding: EdgeInsets.only(left: padding.left, right: padding.right),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: hidePanel,
                    behavior: .opaque,
                    child: Obx(
                      () => _buildBody(
                        _whisperDetailController.loadingState.value,
                      ),
                    ),
                  ),
                ),
                if (hasInput)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Align(
                      alignment: .bottomCenter,
                      heightFactor: 1,
                      child: ConstrainedBox(
                        constraints: _kConstraints,
                        child: Padding(
                          padding: const .fromLTRB(12, 0, 12, 8),
                          child: GlassBox(
                            radius: Revamp.fieldRadius,
                            child: _buildInputView(Colors.transparent),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasInput)
            ConstrainedBox(
              constraints: _kConstraints,
              // the keyboard's place, or the emotes, in the page's color
              child: buildPanelContainer(theme.colorScheme.surface),
            )
          else
            SizedBox(height: padding.bottom),
        ],
      ),
    );
  }
}

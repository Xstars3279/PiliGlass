import 'package:PiliPlus/pages/common/publish/publish_route.dart';
import 'package:PiliPlus/common/motion/springs.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_painters.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/pages/video/reply/view.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:PiliPlus/pages/video/widgets/ambient_background.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Whether a video's comment sheet is up, one per reply controller, so the
/// preview card in the intro can raise the sheet that wraps the page.
final _sheetOpen = Expando<ValueNotifier<bool>>();

ValueNotifier<bool> _openOf(VideoReplyController controller) =>
    _sheetOpen[controller] ??= ValueNotifier(false);

/// Opens another panel in a video's sheet, see [CommentSheet.showPanel].
final _panelOpeners = Expando<void Function(SheetPanelBuilder)>();

/// builds a panel for the sheet, given the way to close the sheet
typedef SheetPanelBuilder = Widget Function(VoidCallback close);

/// The comments of the redesigned video page: a sheet of liquid glass that
/// rises over the intro, below the player.
///
/// Docked nowhere: it comes up from the bottom to [_halfOf] the space when
/// the preview card is tapped, drags up to the player's edge, and drags down
/// to close. The list inside scrolls once the sheet is all the way up, and
/// pulling the list down past its top lowers the sheet again.
class CommentSheet extends StatefulWidget {
  const CommentSheet({
    super.key,
    required this.heroTag,
    required this.cover,
    required this.child,
    this.openAtStart = false,
  });

  final String heroTag;

  /// tints the glass like the rest of the page
  final RxString cover;

  /// the page below the sheet
  final Widget child;

  /// for 默认显示评论 and links to a comment
  final bool openAtStart;

  static void open(VideoReplyController controller) =>
      _openOf(controller).value = true;

  /// Brings up the sheet with [panel] in place of the comments, e.g. 合集,
  /// so it slides and bounces like them. False if the page has no sheet.
  static bool showPanel(
    VideoReplyController controller,
    SheetPanelBuilder panel,
  ) {
    final open = _panelOpeners[controller];
    if (open == null) return false;
    open(panel);
    return true;
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet>
    with TickerProviderStateMixin {
  late final VideoReplyController _replyCtr = Get.find(tag: widget.heroTag);
  late final ValueNotifier<bool> _isOpen = _openOf(_replyCtr);
  final _sheetCtr = DraggableScrollableController();

  /// The sheet as drawn. It follows the sheet's own position with a spring,
  /// so the snaps of [DraggableScrollableSheet] land with a little bounce.
  late final _shown = SpringFollower(
    vsync: this,
    value: 0,
    spring: Springs.sheet,
  );

  /// a finger is on the sheet: draw it exactly where it is
  bool _pressed = false;
  double _lastSize = 0;
  Duration _lastStamp = Duration.zero;
  double _sizeVelocity = 0;

  LocalHistoryEntry? _history;

  /// a panel shown in place of the comments, see [CommentSheet.showPanel]
  Widget? _panel;

  /// The thread (评论详情) shown in the sheet in place of the list. It slides
  /// in over the same glass, so the page below is blurred only once.
  ({ReplyInfo item, int? id})? _thread;
  late final _threadIn = AnimationController.unbounded(vsync: this);
  LocalHistoryEntry? _threadHistory;
  VoidCallback? _replyInThread;

  /// opened, waiting for the layout to know where half-way is
  bool _rising = false;
  double _half = 0.6;
  List<double> _snapSizes = const [];
  double _height = 1;

  static const _headerHeight = 60.0;
  static const _barHeight = 48.0;

  @override
  void initState() {
    super.initState();
    // left open by a previous layout of the page
    _isOpen.value = false;
    _isOpen.addListener(_onOpenChanged);
    _sheetCtr.addListener(_onSize);
    _shown.addListener(_onShown);
    _replyCtr.onShowReplies = _openThread;
    _panelOpeners[_replyCtr] = _openPanel;
    if (widget.openAtStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _isOpen.value = true;
      });
    }
  }

  @override
  void dispose() {
    _isOpen
      ..removeListener(_onOpenChanged)
      ..value = false;
    _sheetCtr
      ..removeListener(_onSize)
      ..dispose();
    _shown.dispose();
    if (_replyCtr.onShowReplies == _openThread) _replyCtr.onShowReplies = null;
    if (_panelOpeners[_replyCtr] == _openPanel) _panelOpeners[_replyCtr] = null;
    _threadIn.dispose();
    _history?.remove();
    _threadHistory?.remove();
    super.dispose();
  }

  void _onOpenChanged() {
    if (_isOpen.value) {
      _shown.jumpTo(0);
      _rising = true;
      _history = LocalHistoryEntry(onRemove: _onBack);
      ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    }
    setState(() {});
  }

  void _onSize() {
    final size = _sheetCtr.size;
    if (_pressed) {
      final stamp = SchedulerBinding.instance.currentSystemFrameTimeStamp;
      final dt =
          (stamp - _lastStamp).inMicroseconds / Duration.microsecondsPerSecond;
      if (dt > 0) _sizeVelocity = (size - _lastSize) / dt;
      _lastStamp = stamp;
      _shown.jumpTo(size, velocity: _sizeVelocity);
    } else {
      _shown.animateTo(size);
    }
    _lastSize = size;
  }

  void _onPointerUp(PointerEvent e) {
    _pressed = false;
    if (_sheetCtr.isAttached) _shown.animateTo(_sheetCtr.size);
  }

  /// Closed once the sheet as drawn is gone too: it trails the sheet's own
  /// position, and removing it earlier would make it vanish mid-way.
  void _onShown() {
    if (_isOpen.value &&
        !_pressed &&
        _sheetCtr.isAttached &&
        _sheetCtr.size <= 0.001 &&
        _shown.value <= 0.01) {
      _finishClose();
    }
  }

  /// the back button closes the sheet before leaving the page
  void _onBack() {
    _history = null;
    _close();
  }

  void _close() {
    if (_sheetCtr.isAttached && _sheetCtr.size > 0.001) {
      _sheetCtr.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInCubic,
      );
    } else {
      _finishClose();
    }
  }

  void _finishClose() {
    if (!_isOpen.value) return;
    _panel = null;
    _thread = null;
    _threadIn.value = 0;
    final threadHistory = _threadHistory;
    _threadHistory = null;
    threadHistory?.remove();
    final history = _history;
    _history = null;
    history?.remove();
    _isOpen.value = false;
    _shown.jumpTo(0);
  }

  void _openPanel(SheetPanelBuilder panel) {
    setState(() => _panel = panel(_close));
    if (!_isOpen.value) _isOpen.value = true;
  }

  void _openThread(ReplyInfo item, int? id) {
    setState(() {
      _thread = (item: item, id: id);
      _replyInThread = null;
    });
    if (!_isOpen.value) {
      _isOpen.value = true;
    } else if (_sheetCtr.isAttached && _sheetCtr.size < 1) {
      // a thread reads better with the room of the whole sheet
      _sheetCtr.animateTo(
        1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    _threadIn
      ..value = 0
      ..springTo(1, Springs.bouncy);
    if (_threadHistory == null) {
      _threadHistory = LocalHistoryEntry(onRemove: _onThreadBack);
      ModalRoute.of(context)?.addLocalHistoryEntry(_threadHistory!);
    }
  }

  /// the back button leaves the thread before closing the sheet
  void _onThreadBack() {
    _threadHistory = null;
    if (_thread == null) return;
    _threadIn.springTo(0, Springs.smooth).whenCompleteOrCancel(() {
      if (mounted && _threadIn.value <= 0.001) setState(() => _thread = null);
    });
  }

  void _closeThread() {
    if (_threadHistory case final history?) {
      history.remove();
    } else {
      _onThreadBack();
    }
  }

  /// Snaps the sheet after its handle was dragged: a flick goes on to the
  /// next stop, a slow release to the nearest one.
  void _settle(double velocity) {
    if (!_sheetCtr.isAttached) return;
    final size = _sheetCtr.size;
    final stops = [0.0, _half, 1.0];
    final double target;
    if (velocity.abs() > 700) {
      target = velocity < 0
          ? stops.firstWhere((s) => s > size + 0.01, orElse: () => 1)
          : stops.lastWhere((s) => s < size - 0.01, orElse: () => 0);
    } else {
      target = stops.reduce(
        (a, b) => (a - size).abs() < (b - size).abs() ? a : b,
      );
    }
    _sheetCtr.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// the part of the way from closed to the half-way stop, 0..1
  double get _progress => (_shown.value / _half).clamp(0.0, 1.0);

  void _reply() => _replyCtr.onReply(
    null,
    oid: _replyCtr.aid,
    replyType: _replyCtr.videoType.replyType,
    mentionItem: _replyCtr.mentionItem,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOpen.value)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _height = constraints.maxHeight;
                final half =
                    (MediaQuery.sizeOf(context).height * 0.56 / _height).clamp(
                      0.4,
                      0.85,
                    );
                // A new list of snap sizes makes the sheet snap at once, even
                // in the middle of a drag, and the page rebuilds often while
                // the player runs: keep the list unless the stop moved.
                if (_snapSizes.isEmpty || (half - _half).abs() > 0.001) {
                  _half = half;
                  _snapSizes = [half];
                }
                if (_rising) {
                  _rising = false;
                  // rise from below the screen to the half-way stop
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _shown.animateTo(_half);
                  });
                }
                return _buildSheet(context);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSheet(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      children: [
        // the page below dims as the sheet comes up; tapping it closes
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _shown,
            builder: (context, _) {
              final t = _progress;
              return IgnorePointer(
                ignoring: t < 0.05,
                child: GestureDetector(
                  onTap: _close,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.22 * t),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) {
              _pressed = true;
              _lastStamp =
                  SchedulerBinding.instance.currentSystemFrameTimeStamp;
              _sizeVelocity = 0;
            },
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerUp,
            child: ListenableBuilder(
              // both: when the sheet snaps, its new position is laid out in
              // the same frame, before the spring takes a step, and drawing
              // it with the previous offset would jump it for that frame
              listenable: Listenable.merge([_shown, _sheetCtr]),
              builder: (context, child) {
                final size = _sheetCtr.isAttached ? _sheetCtr.size : _half;
                return Transform.translate(
                  offset: Offset(0, (size - _shown.value) * _height),
                  child: child,
                );
              },
              child: DraggableScrollableSheet(
                controller: _sheetCtr,
                initialChildSize: _half,
                minChildSize: 0,
                snap: true,
                snapSizes: _snapSizes,
                builder: _buildBody,
              ),
            ),
          ),
        ),
        // the input bar floats over the bottom of the open sheet
        if (_panel == null)
          ListenableBuilder(
            listenable: _shown,
            builder: (context, child) => Positioned(
              left: 12,
              right: 12,
              // moved by layout, not a transform, so the lens follows it
              bottom:
                  bottom + 10 - (1 - _progress) * (_barHeight + 30 + bottom),
              height: _barHeight,
              child: child!,
            ),
            child: _InputBar(
              label: switch (_thread) {
                final thread? => '回复 @${thread.item.member.name}',
                null => '发条友善的评论',
              },
              onTap: () => _thread != null ? _replyInThread?.call() : _reply(),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, ScrollController scrollController) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const radius = Radius.circular(28);
    return Stack(
      clipBehavior: .none,
      fit: .expand,
      children: [
        // reaches below the screen, so only the top corners are rounded
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -80,
          child: CustomPaint(
            painter: GlassShadowPainter(
              radius: radius,
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            ),
            foregroundPainter: GlassRimPainter(
              radius: radius,
              opacity: 0.8,
              isDark: isDark,
            ),
            child: AmbientTintBuilder(
              cover: widget.cover,
              builder: (context, tint, _) => LiquidGlass(
                radius: 28,
                blurSigma: 24,
                saturation: 1.7,
                color: Color.lerp(
                  colorScheme.surface,
                  tint,
                  0.35,
                )!.withValues(alpha: isDark ? 0.6 : 0.64),
              ),
            ),
          ),
        ),
        // laid out at the full height and clipped, so the list does not
        // lay out again on every frame of a drag
        ClipRRect(
          borderRadius: const .vertical(top: radius),
          child: OverflowBox(
            alignment: .topCenter,
            minHeight: _height,
            maxHeight: _height,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(child: _buildContent(scrollController)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The list, and the thread sliding in over it from the right: the list
  /// drifts left and fades, like a page pushed in a navigation stack.
  Widget _buildContent(ScrollController scrollController) {
    if (_panel case final panel?) return panel;
    // made once per build, so the animation below does not rebuild them
    final list = PrimaryScrollController(
      controller: scrollController,
      child: VideoReplyPanel(
        heroTag: widget.heroTag,
        isNested: true,
        inSheet: true,
      ),
    );
    final thread = _thread;
    final threadPanel = thread == null
        ? null
        : VideoReplyReplyPanel(
            key: ValueKey(thread.item.id),
            enableSlide: false,
            id: thread.id,
            oid: thread.item.oid.toInt(),
            rpid: thread.item.id.toInt(),
            firstFloor: thread.item.replyControl.isNote ? null : thread.item,
            replyType: _replyCtr.videoType.replyType,
            isVideoDetail: true,
            upMid: _replyCtr.upMid,
            inSheet: true,
            onReplyReady: (reply) => _replyInThread = reply,
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _threadIn,
          builder: (context, _) {
            final t = _threadIn.value;
            return Stack(
              children: [
                IgnorePointer(
                  ignoring: thread != null,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(-0.3 * width * t, 0),
                      child: list,
                    ),
                  ),
                ),
                if (threadPanel != null)
                  Transform.translate(
                    offset: Offset(width * (1 - t), 0),
                    child: threadPanel,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return GestureDetector(
      behavior: .opaque,
      onVerticalDragUpdate: (details) {
        if (!_sheetCtr.isAttached) return;
        _sheetCtr.jumpTo(
          (_sheetCtr.size - details.delta.dy / _height).clamp(0.0, 1.0),
        );
      },
      onVerticalDragEnd: (details) =>
          _settle(details.velocity.pixelsPerSecond.dy),
      onTap: () => _sheetCtr.animateTo(
        _sheetCtr.size < (_half + 1) / 2 ? 1 : _half,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
      child: SizedBox(
        // a panel brings its own title bar: only the handle to drag by
        height: _panel != null ? 20 : _headerHeight,
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const .only(top: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: const .all(.circular(2)),
              ),
            ),
            if (_panel == null)
              Expanded(
                child: Padding(
                  padding: .only(left: _thread != null ? 6 : 20, right: 6),
                  child: _thread != null
                      ? Row(
                          children: [
                            IconButton(
                              tooltip: '返回',
                              onPressed: _closeThread,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const Text(
                              '评论详情',
                              style: TextStyle(fontSize: 17, fontWeight: .w800),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '关闭',
                              onPressed: _close,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: .center,
                          children: [
                            const Text(
                              '评论',
                              style: TextStyle(fontSize: 17, fontWeight: .w800),
                            ),
                            const SizedBox(width: 8),
                            Obx(() {
                              final count = _replyCtr.count.value;
                              return Text(
                                count == -1 ? '' : NumUtils.numFormat(count),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              );
                            }),
                            const Spacer(),
                            Obx(
                              () => TextButton.icon(
                                onPressed: _replyCtr.queryBySort,
                                icon: const Icon(Icons.sort_rounded, size: 18),
                                label: Text(_replyCtr.sortType.value.descShort),
                              ),
                            ),
                            IconButton(
                              tooltip: '关闭',
                              onPressed: _close,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 发条友善的评论: a capsule of liquid glass over the bottom of the sheet.
class _InputBar extends StatelessWidget {
  const _InputBar({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == .dark;
    const radius = Radius.circular(24);
    return Semantics(
      button: true,
      label: '发表评论',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          // the reply panel grows out of the bar
          final box = context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            PublishRoute.pendingMorph =
                box.localToGlobal(Offset.zero) & box.size;
          }
          onTap();
          // nothing was opened, e.g. replies are closed: forget the bar
          Future.microtask(() => PublishRoute.pendingMorph = null);
        },
        child: CustomPaint(
          painter: GlassShadowPainter(
            radius: radius,
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
          ),
          foregroundPainter: GlassRimPainter(
            radius: radius,
            opacity: 0.75,
            isDark: isDark,
          ),
          child: LiquidGlass(
            blurSigma: 3,
            refractionHeight: 16,
            refractionAmount: 18,
            saturation: 1.5,
            color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
            child: Padding(
              padding: const .symmetric(horizontal: 18),
              child: Row(
                spacing: 10,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    size: 22,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The comments in the intro, below the actions: the count and the top
/// comment. Tapping it brings up the [CommentSheet].
class CommentPreviewCard extends StatefulWidget {
  const CommentPreviewCard({super.key, required this.heroTag});

  final String heroTag;

  @override
  State<CommentPreviewCard> createState() => _CommentPreviewCardState();
}

class _CommentPreviewCardState extends State<CommentPreviewCard> {
  late final VideoReplyController _replyCtr = Get.find(tag: widget.heroTag);

  @override
  void initState() {
    super.initState();
    // the comments used to load when their tab was first shown
    if (_replyCtr.loadingState.value is Loading) _replyCtr.queryData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final muted = colorScheme.onSurfaceVariant;
    return Padding(
      padding: const .fromLTRB(12, 12, 12, 0),
      child: Material(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.75),
        borderRadius: const .all(.circular(20)),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: () => CommentSheet.open(_replyCtr),
          child: Padding(
            padding: const .fromLTRB(16, 12, 12, 14),
            child: Column(
              crossAxisAlignment: .start,
              spacing: 10,
              children: [
                Row(
                  children: [
                    const Text(
                      '评论',
                      style: TextStyle(fontSize: 15, fontWeight: .w800),
                    ),
                    const SizedBox(width: 6),
                    Obx(() {
                      final count = _replyCtr.count.value;
                      return Text(
                        count == -1 ? '' : NumUtils.numFormat(count),
                        style: TextStyle(
                          fontSize: 13,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      );
                    }),
                    const Spacer(),
                    Icon(Icons.unfold_more_rounded, size: 20, color: muted),
                  ],
                ),
                Obx(
                  () => switch (_replyCtr.loadingState.value) {
                    Success(:final response?) when response.isNotEmpty =>
                      _topComment(response.first, colorScheme),
                    Loading() => _placeholder(colorScheme),
                    Success() => _note('还没有评论，来抢沙发吧', muted),
                    Error() => _note('评论没加载出来，点开重试', muted),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topComment(ReplyInfo reply, ColorScheme colorScheme) => Row(
    crossAxisAlignment: .start,
    spacing: 10,
    children: [
      NetworkImgLayer(
        src: reply.member.face,
        type: .avatar,
        width: 26,
        height: 26,
      ),
      Expanded(
        child: Text(
          reply.content.message,
          maxLines: 2,
          overflow: .ellipsis,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ),
    ],
  );

  Widget _note(String text, Color color) =>
      Text(text, style: TextStyle(fontSize: 14, color: color));

  Widget _placeholder(ColorScheme colorScheme) {
    Widget line(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
          borderRadius: const .all(.circular(6)),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [line(0.9), line(0.6)],
    );
  }
}

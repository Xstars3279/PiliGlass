import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:material_ui/material_ui.dart';

/// A page's tabs on the shell's glass, sized to what they hold: a short row
/// sits in the middle of the room it is given instead of hugging the left, and
/// a long one takes the whole width and scrolls. The pill under the chosen tab
/// follows the page as it is swiped, in step with the page itself, and whenever
/// the chosen tab has something on both of its sides the row is scrolled to put
/// it in the middle, as far as the row's ends allow.
///
/// With [centered] off the row keeps the whole width and its tabs start at the
/// left, as upstream's own bar does.
///
/// One label is enough to size it: a page with a single tab gets a small
/// capsule with that one tab in it.
class CenteredGlassTabs extends StatefulWidget {
  const CenteredGlassTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.onTap,
    this.refraction = true,
    this.height = 44,
    this.labelPadding = 14,
    this.centered = true,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int>? onTap;

  /// whether a feed passes under it, so the glass may bend at its rim
  final bool refraction;

  /// the capsule's own height, the room of its padding included
  final double height;

  /// the room each label keeps on either side
  final double labelPadding;

  /// whether the row sits in the middle of the room it is given
  final bool centered;

  @override
  State<CenteredGlassTabs> createState() => _CenteredGlassTabsState();
}

class _CenteredGlassTabsState extends State<CenteredGlassTabs> {
  final _scroll = ScrollController();

  /// the width of each label with its padding, measured once per build
  List<double> _widths = const [];

  /// the tab last scrolled into the middle, so the frames of a scroll
  /// animation do not send it there again
  int? _centeredIndex;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
    // the first tab may already be a scrolled-into-place one
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerChosen());
  }

  @override
  void didUpdateWidget(covariant CenteredGlassTabs old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
    }
    // turned to centring while shown: bring the chosen tab to the middle
    if (!old.centered && widget.centered) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerChosen());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.controller.index == _centeredIndex) return;
    // the label's weight and colour follow the new tab
    setState(() {});
    _centerChosen();
  }

  /// Scrolls the chosen tab to the middle, as long as both of its sides hold
  /// something: at the two ends of the row it stops at the edge instead.
  void _centerChosen() {
    _centeredIndex = widget.controller.index;
    if (!widget.centered || !_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final index = widget.controller.index;
    if (index < 0 || index >= _widths.length) return;
    final target =
        _start(index) + _widths[index] / 2 - position.viewportDimension / 2;
    _scroll.animateTo(
      target.clamp(0.0, max),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int index) {
    feedBack();
    widget.onTap?.call(index);
    if (widget.controller.index != index) {
      widget.controller.animateTo(index);
    }
  }

  /// how wide the labels before [index] are together
  double _start(int index) {
    var start = 0.0;
    for (var i = 0; i < index && i < _widths.length; i++) {
      start += _widths[i];
    }
    return start;
  }

  /// Every label's width, the wider of the two styles, so the pill does not
  /// shift when the weights swap.
  List<double> _measure(BuildContext context, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    return widget.labels
        .map(
          (label) => (TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout()).width +
              widget.labelPadding * 2,
        )
        .toList();
  }

  /// A label's style at [near]: 1 when its tab is the chosen one, 0 when it
  /// is not. The colour slides with the page; the weight swaps at half way,
  /// as a weight cannot be drawn in between.
  TextStyle? _labelStyle(
    double near,
    TextStyle? selected,
    TextStyle? unselected,
    ColorScheme colorScheme,
  ) => (near >= 0.5 ? selected : unselected)?.copyWith(
    color: Color.lerp(
      colorScheme.onSurfaceVariant,
      colorScheme.onSecondaryContainer,
      near,
    ),
  );

  /// The row, with the pill under [position]: a tab index as a fraction, so
  /// that while a page is swiped the pill slides between the two tabs.
  Widget _row(
    ColorScheme colorScheme,
    TextStyle? selected,
    TextStyle? unselected,
    double position,
  ) {
    final count = _widths.length;
    final at = count == 0
        ? 0.0
        : position.clamp(0.0, (count - 1).toDouble());
    final from = at.floor();
    final to = count == 0 ? 0 : math.min(from + 1, count - 1);
    final t = at - from;
    final left = count == 0 ? 0.0 : lerpDouble(_start(from), _start(to), t)!;
    final width = count == 0
        ? 0.0
        : lerpDouble(_widths[from], _widths[to], t)!;
    return SizedBox(
      // the row fills the capsule, so its labels sit on the capsule's own
      // middle line rather than 4 above it
      width: _widths.fold<double>(0, (sum, e) => sum + e),
      height: widget.height,
      child: Stack(
        children: [
          Positioned(
            // 8 in from the capsule and the tab's edge, as the old bar's
            // 4 of capsule padding and 4 of indicator inset came to
            left: left + 8,
            width: math.max(0, width - 16),
            top: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.secondaryContainer,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < widget.labels.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(i),
                  child: SizedBox(
                    width: _widths[i],
                    // the whole strip is a target, not just the glyphs
                    height: widget.height,
                    child: Center(
                      child: Text(
                        widget.labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // the colour follows the page with the pill; the
                        // weight swaps at the half way point
                        style: _labelStyle(
                          (1 - (at - i).abs()).clamp(0.0, 1.0),
                          selected,
                          unselected,
                          colorScheme,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tabTheme = theme.tabBarTheme;
    final selected = tabTheme.labelStyle ?? theme.textTheme.titleSmall;
    final unselected =
        tabTheme.unselectedLabelStyle ?? theme.textTheme.titleSmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        _widths = _measure(
          context,
          selected!.copyWith(fontWeight: FontWeight.w600),
        );
        final total = _widths.fold<double>(0, (sum, e) => sum + e);
        final fits = total <= available;
        final width = widget.centered ? math.min(total, available) : available;

        // the pill keeps step with the page, frame by frame
        final animation = widget.controller.animation;
        final index = widget.controller.index.toDouble();
        final body = animation == null
            ? _row(colorScheme, selected, unselected, index)
            : AnimatedBuilder(
                animation: animation,
                builder: (context, _) =>
                    _row(colorScheme, selected, unselected, animation.value),
              );

        final content = SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: fits
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: body,
        );

        return Align(
          alignment: widget.centered ? Alignment.center : Alignment.centerLeft,
          child: SizedBox(
            width: width,
            child: GlassCapsule(
              refraction: widget.refraction,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                // the capsule's own round, so a scrolled tab is cut cleanly
                borderRadius: BorderRadius.circular(widget.height / 2),
                child: SizedBox(
                  height: widget.height,
                  child: fits
                      ? content
                      // a tab running out of room fades instead of being cut
                      : ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (bounds) => LinearGradient(
                            colors: const [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [
                              0,
                              ((bounds.width - 24) / bounds.width).clamp(
                                0.0,
                                1.0,
                              ),
                              1,
                            ],
                          ).createShader(Offset.zero & bounds.size),
                          child: content,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

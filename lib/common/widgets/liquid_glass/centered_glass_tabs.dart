import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:material_ui/material_ui.dart';

/// A page's tabs on the shell's glass, sized to what they hold and centred
/// in the room they are given: a short row sits in the middle of the bar
/// instead of hugging the left, and a long one takes the whole width and
/// scrolls. Whenever the chosen tab has something on both of its sides, it
/// is scrolled to the middle as well, as far as the row's ends allow.
///
/// One label is enough to size it: a page with a single tab gets a small
/// capsule with that one tab centred.
class CenteredGlassTabs extends StatefulWidget {
  const CenteredGlassTabs({
    super.key,
    required this.controller,
    required this.labels,
    this.onTap,
    this.refraction = true,
    this.height = 44,
    this.labelPadding = 14,
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
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (widget.controller.index == _centeredIndex) return;
    // the pill and the label's weight follow the new tab
    setState(() {});
    _centerChosen();
  }

  /// Scrolls the chosen tab to the middle, as long as both of its sides hold
  /// something: at the two ends of the row it stops at the edge instead.
  void _centerChosen() {
    _centeredIndex = widget.controller.index;
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final index = widget.controller.index;
    if (index < 0 || index >= _widths.length) return;
    var start = 0.0;
    for (var i = 0; i < index; i++) {
      start += _widths[i];
    }
    final target = start + _widths[index] / 2 - position.viewportDimension / 2;
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

  /// Every label's width, the wider of the two styles, so the pill does not
  /// shift when the weights swap.
  List<double> _measure(BuildContext context, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    return widget.labels
        .map(
          (label) =>
              (TextPainter(
                text: TextSpan(text: label, style: style),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
                maxLines: 1,
              )..layout()).width +
              widget.labelPadding * 2,
        )
        .toList();
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
        final width = math.min(total, available);
        final rawIndex = widget.controller.index;
        final index = _widths.isEmpty
            ? 0
            : rawIndex.clamp(0, _widths.length - 1).toInt();
        var pillLeft = 0.0;
        for (var i = 0; i < index; i++) {
          pillLeft += _widths[i];
        }

        final row = SizedBox(
          width: total,
          height: widget.height - 8,
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: pillLeft + 4,
                width: math.max(0, _widths[index] - 8),
                top: 4,
                bottom: 4,
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
                        height: widget.height - 8,
                        child: Center(
                          child: Text(
                            widget.labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: i == index
                                ? selected.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  )
                                : unselected?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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

        final content = SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: fits
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: row,
        );

        return Align(
          alignment: Alignment.center,
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

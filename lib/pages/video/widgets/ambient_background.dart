import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/widgets/cover_palette.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Builds with the cover's ambient tint, cross-fading when the cover
/// changes; null until the color is known.
class AmbientTintBuilder extends StatefulWidget {
  const AmbientTintBuilder({
    super.key,
    required this.cover,
    required this.builder,
    this.child,
  });

  final RxString cover;
  final Widget Function(BuildContext context, Color? tint, Widget? child)
  builder;
  final Widget? child;

  @override
  State<AmbientTintBuilder> createState() => _AmbientTintBuilderState();
}

class _AmbientTintBuilderState extends State<AmbientTintBuilder> {
  int? _seed;
  late final Worker _worker;

  @override
  void initState() {
    super.initState();
    _load(widget.cover.value);
    _worker = ever(widget.cover, _load);
  }

  Future<void> _load(String url) async {
    if (!GlassFeatures.ambient) return;
    final seed = await CoverPalette.seed(url);
    if (mounted && seed != null && seed != _seed) {
      setState(() => _seed = seed);
    }
  }

  @override
  void dispose() {
    _worker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed;
    if (seed == null) return widget.builder(context, null, widget.child);
    final target = CoverPalette.ambient(
      seed,
      ColorScheme.of(context).brightness,
    );
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: widget.builder,
      child: widget.child,
    );
  }
}

/// Tints the top of the video page with the cover's color, fading into the
/// normal background, like YouTube's ambient mode.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.cover,
    required this.child,
  });

  final RxString cover;
  final Widget child;

  /// how far down the tint reaches
  static const _height = 320.0;

  @override
  Widget build(BuildContext context) {
    if (!GlassFeatures.ambient) return child;
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _height,
          child: AmbientTintBuilder(
            cover: cover,
            builder: (context, tint, _) {
              if (tint == null) return const SizedBox.shrink();
              final colorScheme = ColorScheme.of(context);
              // the redesign: a 12% wash over the page (20% in the dark),
              // not a gradient of the color itself (6.1)
              final wash = Revamp.enabled
                  ? Color.alphaBlend(
                      tint.withValues(
                        alpha: colorScheme.brightness == Brightness.dark
                            ? 0.2
                            : 0.12,
                      ),
                      colorScheme.surface,
                    )
                  : tint;
              // fade to the same hue, not to grey
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: .topCenter,
                    end: .bottomCenter,
                    colors: [wash, wash.withValues(alpha: 0)],
                  ),
                ),
              );
            },
          ),
        ),
        child,
      ],
    );
  }
}

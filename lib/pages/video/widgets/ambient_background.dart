import 'package:PiliPlus/common/widgets/cover_palette.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// Tints the top of the video page with the cover's color, fading into the
/// normal background, like YouTube's ambient mode.
class AmbientBackground extends StatefulWidget {
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
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> {
  int? _seed;
  late final Worker _worker;

  @override
  void initState() {
    super.initState();
    _load(widget.cover.value);
    _worker = ever(widget.cover, _load);
  }

  Future<void> _load(String url) async {
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
    final colorScheme = ColorScheme.of(context);
    final surface = colorScheme.surface;
    final target = _seed == null
        ? surface
        : CoverPalette.ambient(_seed!, colorScheme.brightness);
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AmbientBackground._height,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: target),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, color, _) {
              final tint = color ?? surface;
              // fade to the same hue, not to grey
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: .topCenter,
                    end: .bottomCenter,
                    colors: [tint, tint.withValues(alpha: 0)],
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

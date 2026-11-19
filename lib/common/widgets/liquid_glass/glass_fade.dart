import 'package:flutter/material.dart';

/// A white haze over the feed behind a bar: solid at the screen's edge, fading
/// to nothing at the bar's middle line, so the feed softens into the bar.
class GlassFade extends StatelessWidget {
  const GlassFade({super.key, required this.height, required this.fromTop});

  /// the room from the edge to the bar's middle line
  final double height;

  /// whether the edge is the top of the screen, else the bottom
  final bool fromTop;

  static const _alpha = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // the feed fades into the page: white in the light theme, the page's own
    // background in the dark, so the haze never stays white there
    final color = theme.brightness == Brightness.dark
        ? theme.scaffoldBackgroundColor
        : Colors.white;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
              end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                color.withValues(alpha: _alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

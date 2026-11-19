import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Loads `shaders/fade_blur.frag` once.
abstract final class FadeBlurShader {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  static ui.FragmentProgram? get program => _program;

  /// [ui.ImageFilter.shader] only works on Impeller; without it the blur is
  /// still there, it just stops at the band's edge instead of fading.
  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  static Future<void> ensureLoaded() =>
      _loading ??= ui.FragmentProgram.fromAsset('shaders/fade_blur.frag')
          .then<void>((program) => _program = program, onError: (_) {});
}

/// A blur of what is behind it that fades to nothing over [fade], starting
/// [hold] in from the band's [fromTop] edge. Behind a bar it softens the
/// content where the two meet and lets it sharpen again a little further
/// away, so the bar does not sit on a hard picture.
class FadeBlur extends LeafRenderObjectWidget {
  const FadeBlur({
    super.key,
    this.sigma = 10,
    this.hold = 0,
    required this.fade,
    this.fromTop = true,
  });

  final double sigma;
  final double hold;
  final double fade;
  final bool fromTop;

  @override
  RenderFadeBlur createRenderObject(BuildContext context) {
    final renderObject = RenderFadeBlur(
      sigma: sigma,
      hold: hold,
      fade: fade,
      fromTop: fromTop,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    // the shader may arrive after the first paint
    FadeBlurShader.ensureLoaded().then((_) {
      if (renderObject.attached) renderObject.markNeedsPaint();
    });
    return renderObject;
  }

  @override
  void updateRenderObject(BuildContext context, RenderFadeBlur renderObject) {
    renderObject
      ..sigma = sigma
      ..hold = hold
      ..fade = fade
      ..fromTop = fromTop
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderFadeBlur extends RenderBox {
  RenderFadeBlur({
    required double sigma,
    required double hold,
    required double fade,
    required bool fromTop,
    required double devicePixelRatio,
  }) : _sigma = sigma,
       _hold = hold,
       _fade = fade,
       _fromTop = fromTop,
       _devicePixelRatio = devicePixelRatio;

  double _sigma;
  double _hold;
  double _fade;
  bool _fromTop;
  double _devicePixelRatio;

  set sigma(double value) {
    if (value == _sigma) return;
    _sigma = value;
    markNeedsPaint();
  }

  set hold(double value) {
    if (value == _hold) return;
    _hold = value;
    markNeedsPaint();
  }

  set fade(double value) {
    if (value == _fade) return;
    _fade = value;
    markNeedsPaint();
  }

  set fromTop(bool value) {
    if (value == _fromTop) return;
    _fromTop = value;
    markNeedsPaint();
  }

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void performLayout() {
    size = constraints.biggest;
  }

  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  ui.ImageFilter? _buildFilter() {
    final blur = ui.ImageFilter.blur(
      sigmaX: _sigma,
      sigmaY: _sigma,
      tileMode: TileMode.clamp,
    );
    final program = FadeBlurShader.isSupported ? FadeBlurShader.program : null;
    if (program == null) return blur;
    if (!identical(program, _program)) {
      _program = program;
      _shader?.dispose();
      _shader = program.fragmentShader();
    }

    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    final scale = rect.width / size.width * _devicePixelRatio;
    final shader = _shader!
      ..setFloat(0, 0) // uSize, set by the engine
      ..setFloat(1, 0)
      ..setFloat(2, rect.left * _devicePixelRatio)
      ..setFloat(3, rect.top * _devicePixelRatio)
      ..setFloat(4, rect.width * _devicePixelRatio)
      ..setFloat(5, rect.height * _devicePixelRatio)
      ..setFloat(6, _hold * scale)
      ..setFloat(7, _fade * scale)
      ..setFloat(8, _fromTop ? 1 : 0);
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: blur,
    );
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final filter = _buildFilter();
    if (filter == null) return;
    context.pushLayer(
      BackdropFilterLayer(filter: filter),
      (context, offset) {},
      offset,
    );
  }

}

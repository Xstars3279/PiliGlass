import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Loads `shaders/liquid_glass_lens.frag` once.
abstract final class LiquidGlassShader {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  static ui.FragmentProgram? get program => _program;

  /// [ui.ImageFilter.shader] only works on Impeller.
  static bool get isSupported => ui.ImageFilter.isShaderFilterSupported;

  static Future<void> ensureLoaded() =>
      _loading ??= ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass_lens.frag',
      ).then<void>((program) => _program = program, onError: (_) {});
}

/// The saturation matrix used when the lens shader is unavailable.
List<double> _saturationMatrix(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final ir = (1 - s) * r, ig = (1 - s) * g, ib = (1 - s) * b;
  return [
    ir + s, ig, ib, 0, 0, //
    ir, ig + s, ib, 0, 0, //
    ir, ig, ib + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// A rounded rect of liquid glass: the content behind it is blurred, made
/// more vivid, and refracted near the edges, then [color] and [child] are
/// painted on top.
///
/// The refraction needs Impeller; elsewhere it falls back to blur only.
/// Sizes are logical pixels and follow the widget's transform (scale).
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    this.radius,
    this.blurSigma = 0,
    this.refractionHeight = 0,
    this.refractionAmount = 0,
    this.depthEffect = false,
    this.chromaticAberration = 0,
    this.saturation = 1,
    this.color,
    this.child,
  });

  /// corner radius, null for a stadium (fully rounded ends)
  final double? radius;
  final double blurSigma;
  final double refractionHeight;
  final double refractionAmount;
  final bool depthEffect;
  final double chromaticAberration;
  final double saturation;
  final Color? color;
  final Widget? child;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  @override
  void initState() {
    super.initState();
    if (LiquidGlassShader.program == null && LiquidGlassShader.isSupported) {
      LiquidGlassShader.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LiquidGlass(
      program: LiquidGlassShader.isSupported ? LiquidGlassShader.program : null,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      radius: widget.radius,
      blurSigma: widget.blurSigma,
      refractionHeight: widget.refractionHeight,
      refractionAmount: widget.refractionAmount,
      depthEffect: widget.depthEffect,
      chromaticAberration: widget.chromaticAberration,
      saturation: widget.saturation,
      color: widget.color,
      child: widget.child,
    );
  }
}

class _LiquidGlass extends SingleChildRenderObjectWidget {
  const _LiquidGlass({
    required this.program,
    required this.devicePixelRatio,
    required this.radius,
    required this.blurSigma,
    required this.refractionHeight,
    required this.refractionAmount,
    required this.depthEffect,
    required this.chromaticAberration,
    required this.saturation,
    required this.color,
    super.child,
  });

  final ui.FragmentProgram? program;
  final double devicePixelRatio;
  final double? radius;
  final double blurSigma;
  final double refractionHeight;
  final double refractionAmount;
  final bool depthEffect;
  final double chromaticAberration;
  final double saturation;
  final Color? color;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) =>
      RenderLiquidGlass().._update(this);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidGlass renderObject,
  ) => renderObject._update(this);
}

class RenderLiquidGlass extends RenderProxyBox {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  double _devicePixelRatio = 1;
  double? _radius;
  double _blurSigma = 0;
  double _refractionHeight = 0;
  double _refractionAmount = 0;
  bool _depthEffect = false;
  double _chromaticAberration = 0;
  double _saturation = 1;
  Color? _color;

  void _update(_LiquidGlass widget) {
    if (!identical(widget.program, _program)) {
      _program = widget.program;
      _shader?.dispose();
      _shader = _program?.fragmentShader();
    }
    _devicePixelRatio = widget.devicePixelRatio;
    _radius = widget.radius;
    _blurSigma = widget.blurSigma;
    _refractionHeight = widget.refractionHeight;
    _refractionAmount = widget.refractionAmount;
    _depthEffect = widget.depthEffect;
    _chromaticAberration = widget.chromaticAberration;
    _saturation = widget.saturation;
    _color = widget.color;
    markNeedsPaint();
  }

  final _clipHandle = LayerHandle<ClipRRectLayer>();
  final _backdropHandle = LayerHandle<BackdropFilterLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  double get _effectiveRadius {
    final max = size.shortestSide / 2;
    return math.min(_radius ?? max, max);
  }

  bool get _hasLens =>
      _shader != null && _refractionHeight > 0 && _refractionAmount > 0;

  ui.ImageFilter? _buildFilter() {
    final blur = _blurSigma > 0
        ? ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.clamp,
          )
        : null;

    if (!_hasLens) {
      if (_saturation == 1) return blur;
      final vibrancy = ui.ColorFilter.matrix(_saturationMatrix(_saturation));
      return blur == null
          ? vibrancy
          : ui.ImageFilter.compose(outer: vibrancy, inner: blur);
    }

    // The shader sees physical pixels of the render pass, i.e. the screen.
    // getTransformTo(null) stops below the RenderView, so it is logical
    // pixels and the device pixel ratio has to be applied here.
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    final scale = rect.width / size.width * _devicePixelRatio;
    final radius = _effectiveRadius * scale;
    final shader = _shader!
      ..setFloat(0, 0) // uSize, set by the engine
      ..setFloat(1, 0)
      ..setFloat(2, rect.left * _devicePixelRatio)
      ..setFloat(3, rect.top * _devicePixelRatio)
      ..setFloat(4, rect.width * _devicePixelRatio)
      ..setFloat(5, rect.height * _devicePixelRatio)
      ..setFloat(6, radius)
      ..setFloat(7, radius)
      ..setFloat(8, radius)
      ..setFloat(9, radius)
      ..setFloat(10, _refractionHeight * scale)
      ..setFloat(11, _refractionAmount * scale)
      ..setFloat(12, _depthEffect ? 1 : 0)
      ..setFloat(13, _chromaticAberration)
      ..setFloat(14, _saturation);
    final lens = ui.ImageFilter.shader(shader);
    return blur == null
        ? lens
        : ui.ImageFilter.compose(outer: lens, inner: blur);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(_effectiveRadius),
    );
    _clipHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      rrect,
      (context, offset) {
        void paintContent(PaintingContext context, Offset offset) {
          if (_color case final color?) {
            context.canvas.drawRRect(
              rrect.shift(offset),
              Paint()..color = color,
            );
          }
          super.paint(context, offset);
        }

        final filter = _buildFilter();
        if (filter == null) {
          _backdropHandle.layer = null;
          paintContent(context, offset);
          return;
        }
        final layer = (_backdropHandle.layer ??= BackdropFilterLayer())
          ..filter = filter;
        context.pushLayer(layer, paintContent, offset);
      },
      oldLayer: _clipHandle.layer,
    );
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    _backdropHandle.layer = null;
    _shader?.dispose();
    super.dispose();
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:PiliPlus/common/glass_features.dart';

/// Loads `shaders/liquid_glass_lens.frag` once.
abstract final class LiquidGlassShader {
  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  static ui.FragmentProgram? get program => _program;

  /// [ui.ImageFilter.shader] only works on Impeller.
  /// Off with its switch too, leaving the blur (PiliGlass 特性 › 液态玻璃折射).
  static bool get isSupported =>
      GlassFeatures.refraction && ui.ImageFilter.isShaderFilterSupported;

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
  ScrollPosition? _scrollPosition;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _scrollPosition)) {
      _scrollPosition?.removeListener(_onAncestorScroll);
      _scrollPosition = position;
      _scrollPosition?.addListener(_onAncestorScroll);
    }
  }

  void _onAncestorScroll() {
    context.findRenderObject()?.markNeedsPaint();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_onAncestorScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LiquidGlass(
      program: LiquidGlassShader.isSupported ? LiquidGlassShader.program : null,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      backdropKey: BackdropGroup.of(context)?.backdropKey,
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
    required this.backdropKey,
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
  final BackdropKey? backdropKey;
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
  BackdropKey? _backdropKey;
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
    _backdropKey = widget.backdropKey;
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

  @override
  bool get alwaysNeedsCompositing => true;

  double get _effectiveRadius {
    final max = size.shortestSide / 2;
    return math.min(_radius ?? max, max);
  }

  bool get _hasLens =>
      _shader != null && _refractionHeight > 0 && _refractionAmount > 0;

  (ui.ImageFilter?, ui.ImageFilter?) _buildFilters() {
    final blur = _blurSigma > 0
        ? ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.clamp,
          )
        : null;

    if (!_hasLens) {
      // Avoid an extra offscreen ImageFilter.compose pass when blurring without
      // the lens shader: sharing one blur pass cuts Vulkan render targets.
      if (blur != null) return (blur, null);
      if (_saturation == 1) return (null, null);
      return (ui.ColorFilter.matrix(_saturationMatrix(_saturation)), null);
    }

    // The shader sees physical pixels of the render pass, i.e. the screen.
    // getTransformTo(null) stops below the RenderView, so it is logical
    // pixels and the device pixel ratio has to be applied here.
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    if (!rect.isFinite || size.width <= 0) {
      return (blur, null);
    }
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
    // Blur first, then refract in a second BackdropFilterLayer instead of
    // ImageFilter.compose: composing blur inside lens shifts Impeller's
    // sub-pass origin after PageView jumps (leaving the left strip sharp),
    // while composing blur outside lens smears out the edge refraction.
    return blur == null ? (lens, null) : (blur, lens);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(_effectiveRadius),
    );
    // Both layers are made anew for each paint rather than carried over from
    // the last one: a reused clip or backdrop layer could leave part of the
    // glass unfiltered, e.g. a strip at its left end that stayed sharp.
    context.pushClipRRect(needsCompositing, offset, Offset.zero & size, rrect, (
      context,
      offset,
    ) {
      void paintContent(PaintingContext context, Offset offset) {
        if (_color case final color?) {
          context.canvas.drawRRect(rrect.shift(offset), Paint()..color = color);
        }
        super.paint(context, offset);
      }

      final (first, second) = _buildFilters();
      if (first == null) {
        paintContent(context, offset);
        return;
      }
      final canShareFirst = _blurSigma > 0 && (_hasLens || _saturation == 1);
      if (second == null) {
        context.pushLayer(
          BackdropFilterLayer(filter: first)
            ..backdropKey = canShareFirst ? _backdropKey : null,
          paintContent,
          offset,
        );
        return;
      }
      // Sibling BackdropFilterLayers so [second] (lens) stays in the render
      // pass instead of inside [first]'s saveLayer, keeping FlutterFragCoord
      // aligned with uRect.
      context
        ..pushLayer(
          BackdropFilterLayer(filter: first)
            ..backdropKey = canShareFirst ? _backdropKey : null,
          (context, offset) {
            context.canvas.drawRect(
              offset & size,
              Paint()..color = const Color(0x00000000),
            );
          },
          offset,
        )
        ..pushLayer(
          BackdropFilterLayer(filter: second),
          paintContent,
          offset,
        );
    });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }
}

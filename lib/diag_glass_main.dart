import 'dart:io';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_capsule.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/liquid_glass.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await Directory.systemTemp.createTemp('piliglass_diag_');
  Hive.init(dir.path);
  GStorage.setting = await Hive.openBox('setting');
  await GStorage.setting.put(UiGlass.key, UiGlassLevel.extreme.index);
  await LiquidGlassShader.ensureLoaded();
  runApp(const _DiagApp());
}

class _DiagApp extends StatelessWidget {
  const _DiagApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const _DiagPage(),
    );
  }
}

class _DiagPage extends StatefulWidget {
  const _DiagPage();

  @override
  State<_DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<_DiagPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _GridBgPainter()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  SizedBox(
                    height: 44,
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: GlassTabBar(
                            controller: _tabController,
                            labels: const ['直播', '推荐', '热门', '分区', '番剧', '影视', '更多'],
                          ),
                        ),
                        const GlassCapsule(
                          refraction: true,
                          padding: EdgeInsets.zero,
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(Icons.notifications_none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _rowLabel(
                    'A: inner=blur(6), outer=lens(16,18) w=0.75 [CURRENT]',
                    _LensBox(blur: 6, h: 16, a: 18, w: 0.75, blurOuter: false, depth: false, ca: 0),
                  ),
                  _rowLabel(
                    'B: inner=lens(20,28), outer=blur(6) depth ca=0.4 w=0.75',
                    _LensBox(blur: 6, h: 20, a: 28, w: 0.75, blurOuter: true, depth: true, ca: 0.4),
                  ),
                  _rowLabel(
                    'C: inner=blur(2.5), outer=lens(20,26) depth ca=0.4 w=0.75',
                    _LensBox(blur: 2.5, h: 20, a: 26, w: 0.75, blurOuter: false, depth: true, ca: 0.4),
                  ),
                  _rowLabel(
                    'D: inner=lens(20,26), outer=blur(3.0) depth ca=0.4 w=0.75',
                    _LensBox(blur: 3.0, h: 20, a: 26, w: 0.75, blurOuter: true, depth: true, ca: 0.4),
                  ),
                  _rowLabel(
                    'E: inner=blur(3.0), outer=lens(20,26) depth ca=0.4 w=0.60',
                    _LensBox(blur: 3.0, h: 20, a: 26, w: 0.60, blurOuter: false, depth: true, ca: 0.4),
                  ),
                  _rowLabel(
                    'F: inner=lens(20,26), outer=blur(3.5) depth ca=0.4 w=0.65',
                    _LensBox(blur: 3.5, h: 20, a: 26, w: 0.65, blurOuter: true, depth: true, ca: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 3,
      children: [
        Text(
          label,
          style: const TextStyle(
            backgroundColor: Color(0xDDFFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 52, child: child),
      ],
    );
  }
}

class _LensBox extends StatelessWidget {
  const _LensBox({
    required this.blur,
    required this.h,
    required this.a,
    required this.w,
    required this.blurOuter,
    required this.depth,
    required this.ca,
  });

  final double blur;
  final double h;
  final double a;
  final double w;
  final bool blurOuter;
  final bool depth;
  final double ca;

  @override
  Widget build(BuildContext context) {
    return _CustomOrderGlass(
      blur: blur,
      h: h,
      a: a,
      w: w,
      blurOuter: blurOuter,
      depth: depth,
      ca: ca,
    );
  }
}

class _CustomOrderGlass extends SingleChildRenderObjectWidget {
  const _CustomOrderGlass({
    required this.blur,
    required this.h,
    required this.a,
    required this.w,
    required this.blurOuter,
    required this.depth,
    required this.ca,
  });

  final double blur, h, a, w, ca;
  final bool blurOuter, depth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCustomGlass(MediaQuery.devicePixelRatioOf(context), this);

  @override
  void updateRenderObject(BuildContext context, _RenderCustomGlass renderObject) {
    renderObject.update(MediaQuery.devicePixelRatioOf(context), this);
  }
}

class _RenderCustomGlass extends RenderProxyBox {
  _RenderCustomGlass(this.dpr, this.w);
  double dpr;
  _CustomOrderGlass w;
  final ui.FragmentShader shader = LiquidGlassShader.program!.fragmentShader();

  void update(double d, _CustomOrderGlass widget) {
    dpr = d;
    w = widget;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final radius = size.shortestSide / 2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final blurFilter = w.blur > 0
        ? ui.ImageFilter.blur(sigmaX: w.blur, sigmaY: w.blur, tileMode: TileMode.clamp)
        : null;
    final rect = MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    final scale = rect.width / size.width * dpr;
    final sr = radius * scale;
    shader
      ..setFloat(0, 0)
      ..setFloat(1, 0)
      ..setFloat(2, rect.left * dpr)
      ..setFloat(3, rect.top * dpr)
      ..setFloat(4, rect.width * dpr)
      ..setFloat(5, rect.height * dpr)
      ..setFloat(6, sr)
      ..setFloat(7, sr)
      ..setFloat(8, sr)
      ..setFloat(9, sr)
      ..setFloat(10, w.h * scale)
      ..setFloat(11, w.a * scale)
      ..setFloat(12, w.depth ? 1.0 : 0.0)
      ..setFloat(13, w.ca)
      ..setFloat(14, 1.5);
    final lens = ui.ImageFilter.shader(shader);
    final filter = blurFilter == null
        ? lens
        : (w.blurOuter
            ? ui.ImageFilter.compose(outer: blurFilter, inner: lens)
            : ui.ImageFilter.compose(outer: lens, inner: blurFilter));

    context.pushClipRRect(needsCompositing, offset, Offset.zero & size, rrect, (context, offset) {
      context.pushLayer(
        BackdropFilterLayer(filter: filter),
        (context, offset) {
          context.canvas.drawRRect(
            rrect.shift(offset),
            Paint()..color = Colors.white.withValues(alpha: w.w),
          );
          context.canvas.drawRRect(
            rrect.shift(offset).deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.45),
          );
        },
        offset,
      );
    });
  }
}

class _GridBgPainter extends CustomPainter {
  const _GridBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF5E6));
    const stripeW = 36.0;
    const colors = [
      Color(0xFFE53935),
      Color(0xFF1E88E5),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF8E24AA),
    ];
    int idx = 0;
    for (double x = 0; x < size.width; x += stripeW) {
      if (idx % 2 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 12, size.height),
          Paint()..color = colors[(idx ~/ 2) % colors.length],
        );
      }
      idx++;
    }
    const rowH = 36.0;
    int rIdx = 0;
    for (double y = 0; y < size.height; y += rowH) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 6),
        Paint()..color = rIdx % 2 == 0 ? Colors.black : const Color(0xFF00ACC1),
      );
      rIdx++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

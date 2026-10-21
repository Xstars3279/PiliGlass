import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

/// The most representative color of a video cover, the way Material You
/// picks a seed color from a wallpaper: quantize, then score.
abstract final class CoverPalette {
  static final _cache = <String, Future<int?>>{};

  /// A tiny thumbnail is enough and quick to decode.
  static String _thumb(String url) =>
      url.contains('@') ? url : '${url.http2https}@96w.webp';

  static Future<int?> seed(String url) {
    if (url.isEmpty) return Future.value();
    return _cache[url] ??= _extract(_thumb(url));
  }

  static Future<int?> _extract(String url) async {
    try {
      final image = await _load(CachedNetworkImageProvider(url));
      final bytes = await image.toByteData(format: .rawRgba);
      final width = image.width, height = image.height;
      image.dispose();
      if (bytes == null) return null;
      final pixels = <int>[];
      for (var i = 0; i < width * height; i++) {
        final r = bytes.getUint8(i * 4);
        final g = bytes.getUint8(i * 4 + 1);
        final b = bytes.getUint8(i * 4 + 2);
        final a = bytes.getUint8(i * 4 + 3);
        if (a < 255) continue;
        pixels.add(0xFF000000 | (r << 16) | (g << 8) | b);
      }
      final result = await QuantizerCelebi().quantize(pixels, 64);
      return Score.score(result.colorToCount, desired: 1).first;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _load(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        completer.complete(info.image.clone());
        info.dispose();
        stream.removeListener(listener);
      },
      onError: (error, stack) {
        completer.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  /// The seed turned into a background tint: soft and light in a light
  /// theme, deep and dim in a dark one, never loud.
  static Color ambient(int seed, Brightness brightness) {
    final hct = Hct.fromInt(seed);
    final dark = brightness == .dark;
    return Color(
      Hct.from(
        hct.hue,
        math.min(hct.chroma, dark ? 28 : 36),
        dark ? 20 : 90,
      ).toInt(),
    );
  }
}

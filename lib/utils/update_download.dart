import 'dart:async';
import 'dart:convert' show base64Url;
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/common/glass_features.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';

/// PiliGlass: an update downloaded inside the app, from GitHub directly.
///
/// - GitHub's hosts are looked up over DNS over HTTPS when that is on
///   (PiliGlass 特性 › 更新下载使用安全 DNS), around poisoned answers; the
///   connection still checks GitHub's own certificate. If no address comes
///   back or none connects, the system's DNS is used as before.
/// - The file comes in a few ranges at once: one connection to GitHub is
///   slow from here, several together much less so. github.com is asked
///   once, for where the file is, so the download counts once.
/// - It is checked against the SHA-256 GitHub publishes for it.
class UpdateDownload {
  UpdateDownload({
    required this.url,
    required this.size,
    required this.name,
    this.digest,
  });

  /// the asset's browser_download_url
  final String url;

  /// its size in bytes, as GitHub lists it
  final int size;

  /// the file's name
  final String name;

  /// GitHub's digest of it, e.g. sha256:2e6b…
  final String? digest;

  /// bytes downloaded so far
  final received = ValueNotifier<int>(0);

  /// whether the hosts were looked up over DoH; for the dialog to say
  bool viaDoh = false;

  static const _parts = 4;
  static const _attempts = 5;

  HttpClient? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  /// Downloads and checks the file; throws with a message to show if it
  /// cannot.
  Future<File> start() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/update');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final client = _client = _createClient();
    try {
      var location = await _locate(client);
      // the signed link expires after a while; ask again for a new one
      Future<String>? relocating;
      Future<String> relocate() =>
          relocating ??= _locate(client).whenComplete(() => relocating = null);

      final parts = size < (4 << 20) ? 1 : _parts;
      final step = (size / parts).ceil();
      final files = [
        for (var i = 0; i < parts; i++) File('${dir.path}/$name.part$i'),
      ];
      final done = List.filled(parts, 0);
      void report() => received.value = done.reduce((a, b) => a + b);

      Future<void> part(int i) async {
        final from = i * step;
        final to = i == parts - 1 ? size - 1 : (i + 1) * step - 1;
        final file = files[i];
        for (var attempt = 0; ; attempt++) {
          if (_cancelled) throw const _Cancelled();
          final have = file.existsSync() ? file.lengthSync() : 0;
          done[i] = have;
          if (from + have > to) return;
          try {
            final request = await client.getUrl(Uri.parse(location));
            request.headers.set(
              HttpHeaders.rangeHeader,
              'bytes=${from + have}-$to',
            );
            final response = await request.close();
            if (response.statusCode == 403 ||
                response.statusCode == 404 ||
                response.statusCode == 410) {
              await response.drain<void>();
              location = await relocate();
              throw HttpException('HTTP ${response.statusCode}');
            }
            if (response.statusCode != 206 &&
                !(response.statusCode == 200 && from + have == 0)) {
              await response.drain<void>();
              throw HttpException('HTTP ${response.statusCode}');
            }
            final sink = file.openWrite(mode: FileMode.append);
            try {
              await for (final chunk in response) {
                if (_cancelled) throw const _Cancelled();
                sink.add(chunk);
                done[i] += chunk.length;
                report();
              }
            } finally {
              await sink.close();
            }
          } on _Cancelled {
            rethrow;
          } catch (e) {
            if (_cancelled) throw const _Cancelled();
            if (attempt + 1 >= _attempts) rethrow;
            debugPrint('update part $i: $e, again');
            await Future<void>.delayed(Duration(seconds: attempt + 1));
          }
        }
      }

      await Future.wait([for (var i = 0; i < parts; i++) part(i)]);

      final apk = File('${dir.path}/$name');
      final sink = apk.openWrite();
      for (final file in files) {
        await sink.addStream(file.openRead());
      }
      await sink.close();
      for (final file in files) {
        file.deleteSync();
      }
      if (apk.lengthSync() != size) {
        throw const UpdateError('下载的文件大小不对，请重试');
      }
      await _verify(apk);
      return apk;
    } on _Cancelled {
      throw const UpdateError('已取消');
    } on UpdateError {
      rethrow;
    } catch (e) {
      throw UpdateError('下载失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  /// where github.com sends the download: asked once and not followed, so
  /// GitHub counts it once however many ranges follow
  Future<String> _locate(HttpClient client) async {
    final request = await client.getUrl(Uri.parse(url))
      ..followRedirects = false;
    final response = await request.close();
    await response.drain<void>();
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null) return Uri.parse(url).resolve(location).toString();
    }
    if (response.statusCode == 200) return url;
    throw HttpException('HTTP ${response.statusCode}');
  }

  Future<void> _verify(File apk) async {
    final want = digest;
    if (want == null || !want.startsWith('sha256:')) return;
    final got = (await sha256.bind(apk.openRead()).first).toString();
    if (got != want.substring(7).toLowerCase()) {
      apk.deleteSync();
      throw const UpdateError('文件校验失败（SHA-256 不一致），请重试');
    }
  }

  HttpClient _createClient() {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 15)
      ..userAgent = 'PiliGlass';
    // the app's own proxy, if one is set in 其它设置
    final proxyHost = Pref.systemProxyHost;
    final proxyPort = int.tryParse(Pref.systemProxyPort);
    final proxied =
        Pref.enableSystemProxy && proxyHost.isNotEmpty && proxyPort != null;
    if (proxied) {
      client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
    } else if (GlassFeatures.updateDoh) {
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        final address = await _Doh.address(uri.host);
        if (address == null) {
          return SecureSocket.startConnect(uri.host, uri.port);
        }
        viaDoh = true;
        // to the address found, with GitHub's name for the certificate
        return ConnectionTask.fromSocket(
          Socket.connect(
            address,
            uri.port,
            timeout: const Duration(seconds: 10),
          ).then((socket) => SecureSocket.secure(socket, host: uri.host)),
          () {},
        );
      };
    }
    return client;
  }

  static const _channel = MethodChannel('piliglass/update');

  /// whether the system lets the app install packages; it asks the user
  /// in its settings, see [openInstallSettings]
  static Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  static Future<void> openInstallSettings() =>
      _channel.invokeMethod('openInstallSettings');

  static Future<void> install(File apk) =>
      _channel.invokeMethod('install', {'path': apk.path});
}

/// a message for the dialog
class UpdateError implements Exception {
  const UpdateError(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// DNS over HTTPS: a few public resolvers asked at once by their addresses,
/// so no lookup comes before them; the answers are encrypted on the way,
/// out of reach of poisoning. The address that connects first is kept for
/// the session.
abstract final class _Doh {
  static const _resolvers = [
    'https://223.5.5.5/dns-query', // AliDNS
    'https://1.12.12.12/dns-query', // DNSPod
    'https://1.1.1.1/dns-query', // Cloudflare
    'https://8.8.8.8/dns-query', // Google
  ];

  static final _best = <String, Future<InternetAddress?>>{};

  static Future<InternetAddress?> address(String host) =>
      _best[host] ??= _pick(host).then((address) {
        // look again next time if nothing was found
        if (address == null) _best.remove(host);
        return address;
      });

  static Future<InternetAddress?> _pick(String host) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    final Set<String> ips;
    try {
      final answers = await Future.wait([
        for (final resolver in _resolvers)
          _query(client, resolver, host).catchError((_) => <String>[]),
      ]);
      ips = answers.expand((e) => e).toSet();
    } finally {
      client.close(force: true);
    }
    if (ips.isEmpty) return null;
    // the one that connects first
    final winner = Completer<InternetAddress?>();
    var pending = ips.length;
    for (final ip in ips) {
      Socket.connect(ip, 443, timeout: const Duration(seconds: 4)).then(
        (socket) {
          socket.destroy();
          if (!winner.isCompleted) winner.complete(InternetAddress(ip));
        },
        onError: (_) {
          if (--pending == 0 && !winner.isCompleted) winner.complete(null);
        },
      );
    }
    return winner.future;
  }

  /// the A records for [host], asked in DNS's wire format (RFC 8484)
  static Future<List<String>> _query(
    HttpClient client,
    String resolver,
    String host,
  ) async {
    final query = BytesBuilder()
      // id 0, recursion desired, one question
      ..add(const [0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
    for (final label in host.split('.')) {
      query
        ..addByte(label.length)
        ..add(label.codeUnits);
    }
    query.add(const [0, 0, 1, 0, 1]); // root, type A, class IN
    final dns = base64Url.encode(query.toBytes()).replaceAll('=', '');
    final request = await client.getUrl(Uri.parse('$resolver?dns=$dns'));
    request.headers.set(HttpHeaders.acceptHeader, 'application/dns-message');
    final response = await request.close().timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      await response.drain<void>();
      return const [];
    }
    final bytes = BytesBuilder();
    await response.forEach(bytes.add);
    return _parse(bytes.toBytes());
  }

  static List<String> _parse(Uint8List b) {
    int u16(int i) => b[i] << 8 | b[i + 1];
    int skipName(int i) {
      while (true) {
        final len = b[i];
        if (len == 0) return i + 1;
        if (len & 0xC0 == 0xC0) return i + 2; // a pointer ends the name
        i += len + 1;
      }
    }

    final answers = u16(6);
    var i = skipName(12) + 4; // past the question
    final ips = <String>[];
    for (var n = 0; n < answers && i < b.length; n++) {
      i = skipName(i);
      final type = u16(i);
      final length = u16(i + 8);
      i += 10;
      if (type == 1 && length == 4) {
        ips.add(b.sublist(i, i + 4).join('.'));
      }
      i += length;
    }
    return ips;
  }
}

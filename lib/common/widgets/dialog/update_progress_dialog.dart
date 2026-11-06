import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/utils/update_download.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// PiliGlass: downloading an update inside the app, with its progress and
/// speed, then handing it to the installer. See [UpdateDownload].
class UpdateProgressDialog extends StatefulWidget {
  const UpdateProgressDialog({
    super.key,
    required this.tag,
    required this.asset,
    required this.onBrowser,
  });

  /// the release, e.g. v0.1.2
  final String tag;

  /// the asset from GitHub's API
  final Map asset;

  /// the old way, in the browser, if this one fails
  final VoidCallback onBrowser;

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  late UpdateDownload _download;
  File? _apk;
  String? _error;

  /// bytes a second, smoothed
  double _speed = 0;
  int _lastReceived = 0;
  Timer? _timer;

  int get _size => widget.asset['size'] as int;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _download = UpdateDownload(
      url: widget.asset['browser_download_url'],
      size: _size,
      name: widget.asset['name'],
      digest: widget.asset['digest'],
    );
    _apk = null;
    _error = null;
    _speed = 0;
    _lastReceived = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = _download.received.value;
      final last = (now - _lastReceived).toDouble();
      _lastReceived = now;
      setState(() => _speed = _speed == 0 ? last : _speed * 0.6 + last * 0.4);
    });
    _download.start().then(
      (apk) {
        _timer?.cancel();
        if (!mounted) return;
        setState(() => _apk = apk);
        _install();
      },
      onError: (Object e) {
        _timer?.cancel();
        if (mounted) setState(() => _error = e.toString());
      },
    );
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    if (!await UpdateDownload.canInstall()) {
      if (mounted) setState(() => _error = 'needInstallPermission');
      return;
    }
    try {
      await UpdateDownload.install(apk);
    } catch (e) {
      if (mounted) setState(() => _error = '无法打开安装程序：$e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _download.cancel();
    super.dispose();
  }

  static String _mb(num bytes) => (bytes / (1 << 20)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outline = TextStyle(color: colorScheme.outline);
    final needPermission = _error == 'needInstallPermission';

    final Widget content;
    final List<Widget> actions;
    if (needPermission) {
      content = const Text('下载完成。系统需要你允许 PiliGlass 安装应用，开启后回来点「安装」。');
      actions = [
        TextButton(
          onPressed: SmartDialog.dismiss,
          child: Text('取消', style: outline),
        ),
        const TextButton(
          onPressed: UpdateDownload.openInstallSettings,
          child: Text('去开启'),
        ),
        TextButton(
          onPressed: () {
            setState(() => _error = null);
            _install();
          },
          child: const Text('安装'),
        ),
      ];
    } else if (_error != null) {
      content = Text(_error!);
      actions = [
        TextButton(
          onPressed: SmartDialog.dismiss,
          child: Text('关闭', style: outline),
        ),
        TextButton(
          onPressed: () {
            SmartDialog.dismiss();
            widget.onBrowser();
          },
          child: const Text('浏览器下载'),
        ),
        TextButton(
          onPressed: () => setState(_start),
          child: const Text('重试'),
        ),
      ];
    } else if (_apk != null) {
      content = const Text('下载完成，已通过 SHA-256 校验。');
      actions = [
        TextButton(
          onPressed: SmartDialog.dismiss,
          child: Text('关闭', style: outline),
        ),
        TextButton(onPressed: _install, child: const Text('安装')),
      ];
    } else {
      content = ValueListenableBuilder<int>(
        valueListenable: _download.received,
        builder: (context, received, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: received == 0 ? null : received / _size,
                stopIndicatorColor: Colors.transparent,
              ),
            ),
            Row(
              children: [
                Text(
                  '${_mb(received)} / ${_mb(_size)} MB',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  received == 0 ? '连接中…' : '${_mb(_speed)} MB/s',
                  style: outline.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Text(
              _download.viaDoh ? '多线程下载 · 安全 DNS' : '多线程下载',
              style: theme.textTheme.labelMedium!.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
      actions = [
        TextButton(
          onPressed: SmartDialog.dismiss,
          child: Text('取消', style: outline),
        ),
      ];
    }
    return AlertDialog(
      title: Text('更新到 ${widget.tag}'),
      content: content,
      actions: actions,
    );
  }
}

import 'dart:io';

import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:PiliPlus/utils/update_download.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// PiliGlass: an update downloading inside the app, its progress and speed,
/// then the installer. Closing it with 后台下载 leaves the download going,
/// with its notification; opening it again shows the same one.
/// See [UpdateDownload].
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

  /// without notifications the system may stop the download once the app
  /// is left; asked for here, see [_askNotification]
  bool _notify = true;

  int get _size => widget.asset['size'] as int;

  @override
  void initState() {
    super.initState();
    _attach();
    _checkNotification();
  }

  Future<void> _checkNotification() async {
    final granted = await Permission.notification.isGranted;
    if (mounted && granted != _notify) setState(() => _notify = granted);
  }

  /// asked once by the system; after a no, only its settings can turn it on
  Future<void> _askNotification() async {
    if (await Permission.notification.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Permission.notification.request();
    }
    await _checkNotification();
  }

  /// to the download going on for this file, or a new one
  void _attach() {
    final url = widget.asset['browser_download_url'] as String;
    var download = UpdateDownload.current;
    if (download == null || download.url != url) {
      download?.cancel();
      download = UpdateDownload.current = UpdateDownload(
        tag: widget.tag,
        url: url,
        apiUrl: widget.asset['url'],
        size: _size,
        name: widget.asset['name'],
        digest: widget.asset['digest'],
      );
    }
    _download = download..shown = true;
    _apk = null;
    _error = null;
    download.result.then(
      (apk) {
        if (!mounted || !identical(download, _download)) return;
        setState(() => _apk = apk);
        _install();
      },
      onError: (Object e) {
        if (mounted && identical(download, _download)) {
          setState(() => _error = e.toString());
        }
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
    // the download goes on; the notification tells when it is done
    _download.shown = false;
    super.dispose();
  }

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
          child: const Text('Github'),
        ),
        TextButton(
          onPressed: () => setState(_attach),
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
      const tabular = [FontFeature.tabularFigures()];
      content = ListenableBuilder(
        listenable: Listenable.merge([
          _download.received,
          _download.speed,
          _download.stage,
        ]),
        builder: (context, _) {
          final received = _download.received.value;
          return Column(
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
                    '${UpdateDownload.mb(received)} / '
                    '${UpdateDownload.mb(_size)} MB',
                    style: const TextStyle(fontFeatures: tabular),
                  ),
                  const Spacer(),
                  Text(
                    received == 0
                        ? _download.stage.value
                        : UpdateDownload.rate(_download.speed.value),
                    style: outline.copyWith(fontFeatures: tabular),
                  ),
                ],
              ),
              Text(
                '${UpdateDownload.label}'
                '${_download.viaDoh ? ' · 安全 DNS' : ''}',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              if (!_notify)
                GestureDetector(
                  onTap: _askNotification,
                  child: Text(
                    '开启通知后可在后台继续下载，点此开启 ›',
                    style: theme.textTheme.labelMedium!.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          );
        },
      );
      actions = [
        TextButton(
          onPressed: () {
            _download.cancel();
            SmartDialog.dismiss();
          },
          child: Text('取消', style: outline),
        ),
        TextButton(
          onPressed: () async {
            if (!_notify) await _askNotification();
            SmartDialog.dismiss();
          },
          child: const Text('后台下载'),
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

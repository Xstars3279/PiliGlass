import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/pages/download/mp4_download_page.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/services/download/mp4_download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

List<SettingsModel> get downloadSettings => [
  NormalModel(
    title: '设置默认下载路径',
    leading: const Icon(Icons.folder_open_outlined),
    getSubtitle: () => Mp4DownloadService.currentDownloadDirLabel,
    onTap: _showLocalDownloadDirDialog,
  ),
  NormalModel(
    title: '设置默认下载画质',
    leading: const Icon(Icons.high_quality_outlined),
    getSubtitle: () =>
        '当前画质：${VideoQuality.fromCode(Pref.localVideoDownloadQa).desc}',
    onTap: _showDownloadVideoQaDialog,
  ),
  NormalModel(
    title: '设置默认下载音质',
    leading: const Icon(Icons.music_note_outlined),
    getSubtitle: () =>
        '当前音质：${AudioQuality.fromCode(Pref.localAudioDownloadQa).desc}',
    onTap: _showDownloadAudioQaDialog,
  ),
  NormalModel(
    title: '我的下载',
    leading: const Icon(Icons.download_done_rounded),
    subtitle: '查看本地合并导出 MP4 的进度与记录',
    onTap: (_, _) => Get.to(() => const Mp4DownloadPage()),
  ),
  const NormalModel(
    title: 'MP4 合并兼容说明',
    leading: Icon(Icons.info_outline_rounded),
    subtitle:
        '使用 Android 原生 MediaMuxer 无损封装：支持 AVC/HEVC 及 Android 10+ AV1 与 AAC(64K~192K)；杜比视界与 Hi-Res/杜比音轨将自动选用兼容流导出，如需原轨请使用「离线缓存」。',
  ),
];

Future<void> _showDownloadVideoQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认下载画质',
      value: Pref.localVideoDownloadQa,
      values: VideoQuality.values
          .map(
            (e) => (
              e.code,
              e == VideoQuality.dolbyVision ? '${e.desc} (将兼容导出)' : e.desc,
            ),
          )
          .toList(),
    ),
  );
  if (res != null) {
    if (res == VideoQuality.dolbyVision.code) {
      SmartDialog.showToast('MP4 封装不支持杜比视界，下载时将自动转为最高兼容 HDR/HEVC');
    }
    await GStorage.setting.put(SettingBoxKey.localVideoDownloadQa, res);
    setState();
  }
}

Future<void> _showDownloadAudioQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认下载音质',
      value: Pref.localAudioDownloadQa,
      values: AudioQuality.values
          .map(
            (e) => (
              e.code,
              (e == AudioQuality.hiRes ||
                      e == AudioQuality.dolby_30255 ||
                      e == AudioQuality.dolby_30250)
                  ? '${e.desc} (将转192K)'
                  : e.desc,
            ),
          )
          .toList(),
    ),
  );
  if (res != null) {
    if (res == AudioQuality.hiRes.code ||
        res == AudioQuality.dolby_30255.code ||
        res == AudioQuality.dolby_30250.code) {
      SmartDialog.showToast('MP4 封装不支持 Hi-Res/杜比音轨，下载时将自动采用 192K AAC');
    }
    await GStorage.setting.put(SettingBoxKey.localAudioDownloadQa, res);
    setState();
  }
}

void _showLocalDownloadDirDialog(BuildContext context, VoidCallback setState) {
  showDialog(
    context: context,
    builder: (context) => SimpleDialog(
      clipBehavior: Clip.hardEdge,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        DialogOption(
          onPressed: () async {
            Get.back();
            final ok = await Mp4DownloadService.pickDownloadDirectory();
            if (ok) {
              setState();
              SmartDialog.showToast(
                '已设置下载路径：${Mp4DownloadService.currentDownloadDirLabel}',
              );
            }
          },
          child: const Text('选择新文件夹', style: TextStyle(fontSize: 14)),
        ),
        DialogOption(
          onPressed: () async {
            Get.back();
            await Mp4DownloadService.resetDownloadDirectory();
            setState();
            SmartDialog.showToast(
              '已恢复默认路径：${Mp4DownloadService.currentDownloadDirLabel}',
            );
          },
          child: const Text('恢复默认路径', style: TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

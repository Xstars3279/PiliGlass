import 'dart:async' show unawaited;

import 'package:PiliPlus/common/revamp.dart';
import 'package:PiliPlus/common/ui_tokens.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_action_bar.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:PiliPlus/services/download/mp4_download_service.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class Mp4DownloadPage extends StatefulWidget {
  const Mp4DownloadPage({super.key});

  @override
  State<Mp4DownloadPage> createState() => _Mp4DownloadPageState();
}

class _Mp4DownloadPageState extends State<Mp4DownloadPage> {
  late final Mp4DownloadService _service = Get.putOrFind(
    Mp4DownloadService.new,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_service.waitForInitialization);
  }

  Widget _buildBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: ShapeDecoration(
        color: Revamp.enabled
            ? Revamp.onPage(colorScheme)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: Revamp.rounded(14),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '默认保存路径',
                  style: UiType.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  Mp4DownloadService.currentDownloadDirLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UiType.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await Get.to(
                () => const CommonSetting(settingType: SettingType.downloadSetting),
              );
              if (mounted) setState(() {});
            },
            child: const Text('更改'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Mp4DownloadTask task, ColorScheme colorScheme) {
    final isDownloading =
        task.status == Mp4DownloadStatus.downloading ||
        task.status == Mp4DownloadStatus.muxing;
    final isCompleted = task.status == Mp4DownloadStatus.completed;
    final isFailed = task.status == Mp4DownloadStatus.failed;

    final statusColor = isFailed
        ? colorScheme.error
        : isCompleted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final statusText = switch (task.status) {
      Mp4DownloadStatus.queued => '排队等待中...',
      Mp4DownloadStatus.downloading =>
        '正在下载 ${(task.progress / 0.9 * 100).clamp(0, 99).round()}%',
      Mp4DownloadStatus.muxing => '正在本地合并为 MP4...',
      Mp4DownloadStatus.completed =>
        '已保存至：${task.outputPath ?? Mp4DownloadService.currentDownloadDirLabel}',
      Mp4DownloadStatus.failed => task.error ?? '下载失败',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: ShapeDecoration(
        color: Revamp.enabled
            ? Revamp.onPage(colorScheme)
            : colorScheme.surfaceContainerLow,
        shape: Revamp.rounded(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: Revamp.rounded(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isCompleted ? () => _service.openTaskFile(task) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              spacing: 12,
              children: [
                if (task.cover.isNotEmpty)
                  NetworkImgLayer(
                    src: task.cover,
                    width: 112,
                    height: 70,
                  )
                else
                  Container(
                    width: 112,
                    height: 70,
                    decoration: ShapeDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: Revamp.rounded(10),
                    ),
                    child: Icon(Icons.movie_outlined, color: colorScheme.outline),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        '${task.qualityDesc} · ${task.audioDesc}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isDownloading)
                        ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            value: task.status == Mp4DownloadStatus.muxing
                                ? null
                                : task.progress,
                            minHeight: 4,
                          ),
                        ),
                      Text(
                        statusText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFailed)
                      IconButton(
                        tooltip: '重试',
                        onPressed: () => _service.retryTask(task),
                        icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
                      ),
                    IconButton(
                      tooltip: '移除记录',
                      onPressed: () => _confirmDelete(task: task),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 19,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete({Mp4DownloadTask? task}) async {
    if (task == null && _service.tasks.isEmpty) {
      SmartDialog.showToast('暂无下载记录');
      return;
    }
    final hasLocalFile = task != null
        ? task.status == Mp4DownloadStatus.completed &&
              ((task.outputUri?.isNotEmpty ?? false) ||
                  (task.outputPath?.isNotEmpty ?? false))
        : _service.tasks.any(
            (t) =>
                t.status == Mp4DownloadStatus.completed &&
                ((t.outputUri?.isNotEmpty ?? false) ||
                    (t.outputPath?.isNotEmpty ?? false)),
          );
    var deleteLocalFile = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('确定要删除吗？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task != null
                    ? '将从下载列表中移除“${task.title}”。'
                    : '将清空当前下载列表中的全部记录。',
              ),
              if (hasLocalFile) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  onTap: () => setDialogState(
                    () => deleteLocalFile = !deleteLocalFile,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: deleteLocalFile,
                        onChanged: (v) => setDialogState(
                          () => deleteLocalFile = v ?? false,
                        ),
                      ),
                      const Expanded(
                        child: Text('同时也删除本地视频文件'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '取消',
                style: TextStyle(color: ColorScheme.of(context).outline),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '确定',
                style: TextStyle(color: ColorScheme.of(context).error),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (task != null) {
      await _service.removeTask(task, deleteLocalFile: deleteLocalFile);
    } else {
      await _service.clearTasks(deleteLocalFile: deleteLocalFile);
    }
  }

  Future<void> _openDownloadSettings() async {
    await Get.to(
      () => const CommonSetting(settingType: SettingType.downloadSetting),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final actionButtons = [
      IconButton(
        tooltip: '下载设置',
        onPressed: _openDownloadSettings,
        icon: const Icon(Icons.settings_outlined),
      ),
      IconButton(
        tooltip: '删除下载记录',
        onPressed: _confirmDelete,
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ];

    if (!Revamp.enabled) {
      return SimpleScaffold(
        appBar: AppBar(
          title: const Text('我的下载'),
          actions: [...actionButtons, const SizedBox(width: 4)],
        ),
        body: Obx(() {
          final items = _service.tasks;
          return Column(
            children: [
              _buildBanner(colorScheme),
              Expanded(
                child: items.isEmpty
                    ? const CustomScrollView(
                        slivers: [HttpError(errMsg: '暂无本地下载任务')],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: padding.bottom + 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _buildTaskItem(items[index], colorScheme),
                      ),
              ),
            ],
          );
        }),
      );
    }

    return Scaffold(
      body: Obx(() {
        final items = _service.tasks;
        return CustomScrollView(
          slivers: [
            RevampLargeAppBar(
              title: '我的下载',
              actions: [
                GlassActionBar(actions: actionButtons),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(child: _buildBanner(colorScheme)),
            if (items.isEmpty)
              const HttpError(errMsg: '暂无本地下载任务')
            else
              SliverPadding(
                padding: EdgeInsets.only(bottom: padding.bottom + 40),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildTaskItem(items[index], colorScheme),
                ),
              ),
          ],
        );
      }),
    );
  }
}

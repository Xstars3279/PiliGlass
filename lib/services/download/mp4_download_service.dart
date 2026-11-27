import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show Directory, File, Platform, Process;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/video/base_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/pgc/pgc_info_model/episode.dart' as pgc;
import 'package:PiliPlus/models_new/pgc/pgc_info_model/result.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/episode.dart' as ugc;
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/services/download/download_manager.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

enum Mp4DownloadStatus {
  queued('等待下载'),
  downloading('正在下载'),
  muxing('正在合并 MP4'),
  completed('已保存'),
  failed('下载失败');

  const Mp4DownloadStatus(this.label);
  final String label;
}

class Mp4DownloadTask {
  Mp4DownloadTask({
    required this.id,
    required this.cid,
    required this.avid,
    required this.bvid,
    required this.title,
    required this.cover,
    required this.preferVideoQa,
    required this.preferAudioQa,
    required this.qualityDesc,
    required this.audioDesc,
    this.seasonId,
    this.epid,
    this.videoType = VideoType.ugc,
    this.status = Mp4DownloadStatus.queued,
    this.progress = 0.0,
    this.outputPath,
    this.outputUri,
    this.error,
    required this.createdAt,
  });

  final String id;
  final int cid;
  final int avid;
  final String bvid;
  String title;
  String cover;
  final int preferVideoQa;
  final int preferAudioQa;
  String qualityDesc;
  String audioDesc;
  final int? seasonId;
  final int? epid;
  final VideoType videoType;
  Mp4DownloadStatus status;
  double progress;
  String? outputPath;
  String? outputUri;
  String? error;
  final int createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'cid': cid,
    'avid': avid,
    'bvid': bvid,
    'title': title,
    'cover': cover,
    'preferVideoQa': preferVideoQa,
    'preferAudioQa': preferAudioQa,
    'qualityDesc': qualityDesc,
    'audioDesc': audioDesc,
    'seasonId': seasonId,
    'epid': epid,
    'videoType': videoType.index,
    'status': status.index,
    'progress': progress,
    'outputPath': outputPath,
    'outputUri': outputUri,
    'error': error,
    'createdAt': createdAt,
  };

  factory Mp4DownloadTask.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        Mp4DownloadStatus.values[(json['status'] as int? ?? 0).clamp(
          0,
          Mp4DownloadStatus.values.length - 1,
        )];
    // Interrupted in-flight tasks become retryable failed tasks after restart.
    final status =
        (rawStatus == Mp4DownloadStatus.downloading ||
                rawStatus == Mp4DownloadStatus.muxing ||
                rawStatus == Mp4DownloadStatus.queued)
            ? Mp4DownloadStatus.failed
            : rawStatus;
    return Mp4DownloadTask(
      id: json['id'] as String,
      cid: json['cid'] as int,
      avid: json['avid'] as int,
      bvid: json['bvid'] as String,
      title: json['title'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      preferVideoQa: json['preferVideoQa'] as int? ?? 80,
      preferAudioQa: json['preferAudioQa'] as int? ?? 30280,
      qualityDesc: json['qualityDesc'] as String? ?? '',
      audioDesc: json['audioDesc'] as String? ?? '',
      seasonId: json['seasonId'] as int?,
      epid: json['epid'] as int?,
      videoType:
          VideoType.values[(json['videoType'] as int? ?? 0).clamp(
            0,
            VideoType.values.length - 1,
          )],
      status: status,
      progress: status == Mp4DownloadStatus.completed ? 1.0 : 0.0,
      outputPath: json['outputPath'] as String?,
      outputUri: json['outputUri'] as String?,
      error: status == Mp4DownloadStatus.failed && json['error'] == null
          ? '下载被中断，可点击重试'
          : json['error'] as String?,
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }
}

/// Downloads DASH streams to temporary files, merges them locally into a
/// standard `.mp4` via Android's native MediaMuxer, and writes the result to
/// the configured local directory.
class Mp4DownloadService extends GetxService {
  static const _channel = MethodChannel('piliglass/mp4_export');
  static const _recordFileName = 'mp4_downloads.json';

  final RxList<Mp4DownloadTask> tasks = <Mp4DownloadTask>[].obs;

  late final Future<void> waitForInitialization = _loadTasks();

  bool _running = false;
  DownloadManager? _videoDownloader;
  DownloadManager? _audioDownloader;
  Mp4DownloadTask? _activeTask;

  static String get currentDownloadDirLabel {
    final customLabel = Pref.localVideoDownloadLabel;
    if (customLabel != null && customLabel.isNotEmpty) {
      return customLabel;
    }
    if (Platform.isAndroid) {
      return 'Movies/PiliGlass（系统视频媒体库）';
    }
    return path.join(downloadPath, 'mp4');
  }

  static Future<bool> pickDownloadDirectory() async {
    if (Platform.isAndroid) {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'pickDirectory',
      );
      if (res == null) return false;
      final uri = res['uri'] as String?;
      final label = res['label'] as String?;
      if (uri == null || uri.isEmpty) return false;
      await GStorage.setting.put(SettingBoxKey.localVideoDownloadUri, uri);
      await GStorage.setting.put(
        SettingBoxKey.localVideoDownloadLabel,
        label ?? uri,
      );
      return true;
    }
    // ignore: deprecated_member_use
    final picked = await FilePicker.getDirectoryPath();
    if (picked == null || picked.isEmpty) return false;
    await GStorage.setting.put(SettingBoxKey.localVideoDownloadUri, picked);
    await GStorage.setting.put(SettingBoxKey.localVideoDownloadLabel, picked);
    return true;
  }

  static Future<void> resetDownloadDirectory() async {
    await GStorage.setting.delete(SettingBoxKey.localVideoDownloadUri);
    await GStorage.setting.delete(SettingBoxKey.localVideoDownloadLabel);
  }

  File get _recordFile => File(path.join(appSupportDirPath, _recordFileName));

  Future<void> _loadTasks() async {
    try {
      final file = _recordFile;
      if (!file.existsSync()) return;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        tasks.assignAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(Mp4DownloadTask.fromJson)
              .toList(),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('load mp4 tasks failed: $e');
    }
  }

  Future<void> _saveTasks() async {
    try {
      await _recordFile.writeAsString(
        jsonEncode(tasks.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('save mp4 tasks failed: $e');
    }
  }

  bool isCidQueuedOrDone(int cid) => tasks.any(
    (t) => t.cid == cid && t.status != Mp4DownloadStatus.failed,
  );

  void enqueueUgc({
    required Part page,
    VideoDetailData? videoDetail,
    ugc.EpisodeItem? videoArc,
    required VideoQuality videoQuality,
    required AudioQuality audioQuality,
  }) {
    final cid = page.cid!;
    if (isCidQueuedOrDone(cid)) {
      SmartDialog.showToast('已在下载列表中');
      return;
    }
    final parentTitle = videoDetail?.title ?? videoArc?.title ?? '';
    final partTitle = page.part?.trim();
    final title = (partTitle != null && partTitle.isNotEmpty && partTitle != parentTitle)
        ? '$parentTitle - $partTitle'
        : (parentTitle.isNotEmpty ? parentTitle : 'PiliGlass_$cid');
    final cover =
        (page.firstFrame ?? videoDetail?.pic ?? videoArc?.cover ?? '').http2https;
    final task = Mp4DownloadTask(
      id: '${cid}_${DateTime.now().millisecondsSinceEpoch}',
      cid: cid,
      avid: videoDetail?.aid ?? videoArc!.aid!,
      bvid: videoDetail?.bvid ?? videoArc!.bvid!,
      title: title,
      cover: cover,
      preferVideoQa: videoQuality.code,
      preferAudioQa: audioQuality.code,
      qualityDesc: videoQuality.desc,
      audioDesc: audioQuality.desc,
      videoType: VideoType.ugc,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _enqueue(task);
  }

  void enqueueBangumi({
    required PgcInfoModel pgcItem,
    required pgc.EpisodeItem episode,
    required VideoQuality quality,
    required AudioQuality audioQuality,
  }) {
    final cid = episode.cid!;
    if (isCidQueuedOrDone(cid)) {
      SmartDialog.showToast('已在下载列表中');
      return;
    }
    final epTitle = episode.showTitle ?? episode.title ?? '';
    final seasonTitle = pgcItem.seasonTitle ?? pgcItem.title ?? '';
    final title = seasonTitle.isNotEmpty && epTitle.isNotEmpty
        ? '$seasonTitle - $epTitle'
        : (epTitle.isNotEmpty ? epTitle : 'PiliGlass_$cid');
    final task = Mp4DownloadTask(
      id: '${cid}_${DateTime.now().millisecondsSinceEpoch}',
      cid: cid,
      avid: episode.aid!,
      bvid: episode.bvid ?? IdUtils.av2bv(episode.aid!),
      seasonId: pgcItem.seasonId,
      epid: episode.id,
      title: title,
      cover: (episode.cover ?? pgcItem.cover ?? '').http2https,
      preferVideoQa: quality.code,
      preferAudioQa: audioQuality.code,
      qualityDesc: quality.desc,
      audioDesc: audioQuality.desc,
      videoType: episode.from == 'pugv' ? VideoType.pugv : VideoType.pgc,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _enqueue(task);
  }

  void _enqueue(Mp4DownloadTask task) {
    tasks.removeWhere((e) => e.cid == task.cid && e.status == Mp4DownloadStatus.failed);
    tasks.insert(0, task);
    _saveTasks();
    _processQueue();
  }

  void retryTask(Mp4DownloadTask task) {
    task
      ..status = Mp4DownloadStatus.queued
      ..progress = 0.0
      ..error = null;
    tasks.refresh();
    _saveTasks();
    _processQueue();
  }

  Future<void> removeTask(
    Mp4DownloadTask task, {
    bool deleteLocalFile = false,
  }) async {
    if (_activeTask?.id == task.id) {
      await _videoDownloader?.cancel(isDelete: true);
      await _audioDownloader?.cancel(isDelete: true);
      _videoDownloader = null;
      _audioDownloader = null;
      _activeTask = null;
    }
    if (deleteLocalFile) {
      await _deleteExportedFile(task);
    }
    tasks.remove(task);
    await _saveTasks();
  }

  Future<void> clearTasks({bool deleteLocalFile = false}) async {
    if (_activeTask != null) {
      await _videoDownloader?.cancel(isDelete: true);
      await _audioDownloader?.cancel(isDelete: true);
      _videoDownloader = null;
      _audioDownloader = null;
      _activeTask = null;
    }
    if (deleteLocalFile) {
      for (final task in tasks.toList()) {
        await _deleteExportedFile(task);
      }
    }
    tasks.clear();
    await _saveTasks();
  }

  Future<void> clearCompleted() async {
    tasks.removeWhere((e) => e.status == Mp4DownloadStatus.completed);
    await _saveTasks();
  }

  Future<void> openTaskFile(Mp4DownloadTask task) async {
    if (task.status != Mp4DownloadStatus.completed) return;
    final uri = task.outputUri;
    final filePath = task.outputPath;
    if ((uri == null || uri.isEmpty) && (filePath == null || filePath.isEmpty)) {
      SmartDialog.showToast('未找到视频文件信息');
      return;
    }
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<bool>('openVideo', {
          'uri': uri,
          'path': filePath,
        });
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('not_found')) {
          SmartDialog.showToast('本地视频文件不存在或已被移动/删除');
        } else if (msg.contains('no_app')) {
          SmartDialog.showToast('未找到可用于播放视频的外部应用');
        } else {
          SmartDialog.showToast('打开视频失败：$msg');
        }
      }
      return;
    }
    final target = filePath ?? uri!;
    final file = File(target);
    if (!file.existsSync()) {
      SmartDialog.showToast('本地视频文件不存在或已被删除');
      return;
    }
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', target]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [target]);
    } else {
      await Process.start('xdg-open', [target]);
    }
  }

  Future<bool> _deleteExportedFile(Mp4DownloadTask task) async {
    final uri = task.outputUri;
    final filePath = task.outputPath;
    if ((uri == null || uri.isEmpty) && (filePath == null || filePath.isEmpty)) {
      return false;
    }
    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<bool>('deleteVideo', {
              'uri': uri,
              'path': filePath,
            }) ??
            false;
      }
      final file = File(filePath ?? uri!);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('delete exported video failed: $e');
    }
    return false;
  }

  Future<void> _processQueue() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = tasks.firstWhereOrNull(
          (t) => t.status == Mp4DownloadStatus.queued,
        );
        if (next == null) break;
        await _runTask(next);
      }
    } finally {
      _running = false;
    }
  }

  List<VideoDecodeFormatType> _mp4CompatibleCodecs() {
    final allowAv1 = !Platform.isAndroid || DeviceUtils.sdkInt >= 29;
    final filtered = Pref.preferCodecs.where((c) {
      if (c == VideoDecodeFormatType.DVH1) return false;
      if (!allowAv1 && c == VideoDecodeFormatType.AV1) return false;
      return true;
    }).toList();
    if (filtered.isEmpty) {
      return const [VideoDecodeFormatType.HEVC, VideoDecodeFormatType.AVC];
    }
    return filtered;
  }

  static bool _isIncompatibleAudio(int id) =>
      id == AudioQuality.hiRes.code ||
      id == AudioQuality.dolby_30255.code ||
      id == AudioQuality.dolby_30250.code;

  Future<void> _runTask(Mp4DownloadTask task) async {
    _activeTask = task;
    task
      ..status = Mp4DownloadStatus.downloading
      ..progress = 0.0
      ..error = null;
    tasks.refresh();

    final workDir = Directory(
      path.join(tmpDirPath, 'mp4_dl', task.id),
    );
    try {
      if (workDir.existsSync()) {
        await workDir.delete(recursive: true);
      }
      await workDir.create(recursive: true);

      final isLogin = Accounts.get(AccountType.video).isLogin;
      final res = await VideoHttp.videoUrl(
        avid: task.avid,
        bvid: task.bvid,
        cid: task.cid,
        seasonId: task.seasonId,
        epid: task.epid,
        qn: task.preferVideoQa,
        tryLook: !isLogin && Pref.p1080,
        videoType: task.seasonId != null || task.epid != null
            ? (isLogin ? task.videoType : VideoType.ugc)
            : VideoType.ugc,
        voiceBalance: true,
      );

      if (res case Success(:final response)) {
        String videoFilePath;
        String? audioFilePath;

        if (response.dash case final dash?) {
          final allVideos = dash.video;
          if (allVideos == null || allVideos.isEmpty) {
            throw StateError('未获取到视频流');
          }
          // Prefer MP4-compatible streams (avoid dvh1, avoid AV1 on Android < 10)
          final allowAv1 = !Platform.isAndroid || DeviceUtils.sdkInt >= 29;
          var compatVideos = allVideos.where((v) {
            if (v.id == VideoQuality.dolbyVision.code) return false;
            final codec = v.codecs ?? '';
            if (codec.startsWith('dvh1')) return false;
            if (!allowAv1 && codec.startsWith('av01')) return false;
            return true;
          }).toList();
          if (compatVideos.isEmpty) {
            compatVideos = allVideos;
          }

          final requestedQa = task.preferVideoQa == VideoQuality.dolbyVision.code
              ? VideoQuality.hdr.code
              : task.preferVideoQa;

          final (
            int targetQuality,
            FormatItem targetFormat,
            _,
            VideoItem videoDash,
          ) = VideoUtils.findTargetVideo(
            compatVideos,
            requestedQa,
            response.acceptQuality,
            response.supportFormats!,
            _mp4CompatibleCodecs(),
          );
          task.qualityDesc =
              targetFormat.displayDesc ??
              VideoQuality.fromCode(targetQuality).shortDesc;

          final videoUrl = VideoUtils.getCdnUrl(videoDash.playUrls);
          videoFilePath = path.join(workDir.path, 'video.m4s');

          String? audioUrl;
          final audioList = dash.audio;
          if (audioList != null && audioList.isNotEmpty) {
            var compatAudios =
                audioList.where((a) => !_isIncompatibleAudio(a.id)).toList();
            final autoFallback = _isIncompatibleAudio(task.preferAudioQa) &&
                compatAudios.isNotEmpty;
            if (compatAudios.isEmpty) {
              compatAudios = audioList;
            }
            final targetAudioQa = autoFallback
                ? AudioQuality.k192.code
                : task.preferAudioQa;
            final audioDash = VideoUtils.findTargetAudio(
              compatAudios,
              targetAudioQa,
            );
            final chosenQa = AudioQuality.fromCode(audioDash.id);
            task.audioDesc = autoFallback
                ? '${chosenQa.desc} (MP4兼容)'
                : chosenQa.desc;
            audioUrl = VideoUtils.getCdnUrl(audioDash.playUrls, isAudio: true);
            audioFilePath = path.join(workDir.path, 'audio.m4s');
          } else {
            task.audioDesc = '无音轨';
          }

          tasks.refresh();

          int videoRecv = 0;
          int videoTotal = 1;
          int audioRecv = 0;
          int audioTotal = audioUrl == null ? 0 : 1;

          void updateProgress() {
            if (!tasks.contains(task)) return;
            final denom = (videoTotal > 0 ? videoTotal : 1) +
                (audioTotal > 0 ? audioTotal : 0);
            final frac = denom > 0
                ? ((videoRecv + audioRecv) / denom).clamp(0.0, 1.0)
                : 0.0;
            // Reserve 0.90..1.0 for local MP4 muxing
            task.progress = frac * 0.90;
            tasks.refresh();
          }

          await Future.wait([
            _downloadSingle(
              url: videoUrl,
              filePath: videoFilePath,
              isVideo: true,
              onProgress: (r, t) {
                videoRecv = r;
                if (t > 0) videoTotal = t;
                updateProgress();
              },
            ),
            if (audioUrl != null && audioFilePath != null)
              _downloadSingle(
                url: audioUrl,
                filePath: audioFilePath,
                isVideo: false,
                onProgress: (r, t) {
                  audioRecv = r;
                  if (t > 0) audioTotal = t;
                  updateProgress();
                },
              ),
          ]);
        } else if (response.durl != null && response.durl!.isNotEmpty) {
          final first = response.durl!.first;
          videoFilePath = path.join(workDir.path, 'video.mp4');
          task
            ..qualityDesc = 'MP4'
            ..audioDesc = '内置';
          tasks.refresh();
          await _downloadSingle(
            url: VideoUtils.getCdnUrl(first.playUrls),
            filePath: videoFilePath,
            isVideo: true,
            onProgress: (r, t) {
              if (!tasks.contains(task)) return;
              if (t > 0) {
                task.progress = (r / t).clamp(0.0, 1.0) * 0.90;
                tasks.refresh();
              }
            },
          );
        } else {
          throw StateError('未获取到可用视频下载地址');
        }

        if (!tasks.contains(task)) {
          return;
        }
        task
          ..status = Mp4DownloadStatus.muxing
          ..progress = 0.92;
        tasks.refresh();

        final result = await _exportMp4(
          videoPath: videoFilePath,
          audioPath: audioFilePath,
          title: task.title,
        );

        task
          ..status = Mp4DownloadStatus.completed
          ..progress = 1.0
          ..outputPath = result.displayPath
          ..outputUri = result.uri;
        tasks.refresh();
        await _saveTasks();
        SmartDialog.showToast('已导出 MP4：${task.title}');
      } else {
        throw StateError(res.toString());
      }
    } catch (e, s) {
      if (kDebugMode) debugPrint('mp4 download error: $e\n$s');
      if (tasks.contains(task)) {
        task
          ..status = Mp4DownloadStatus.failed
          ..error = e.toString();
        tasks.refresh();
        await _saveTasks();
        SmartDialog.showToast('下载失败：$e');
      }
    } finally {
      _videoDownloader = null;
      _audioDownloader = null;
      _activeTask = null;
      try {
        if (workDir.existsSync()) {
          await workDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> _downloadSingle({
    required String url,
    required String filePath,
    required bool isVideo,
    required void Function(int received, int total) onProgress,
  }) {
    final completer = Completer<void>();
    final manager = DownloadManager(
      url: url,
      path: filePath,
      onReceiveProgress: onProgress,
      onDone: ([error]) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(error);
        } else {
          completer.complete();
        }
      },
    );
    if (isVideo) {
      _videoDownloader = manager;
    } else {
      _audioDownloader = manager;
    }
    return completer.future;
  }

  Future<({String displayPath, String? uri})> _exportMp4({
    required String videoPath,
    required String? audioPath,
    required String title,
  }) async {
    final sanitized = title
        .replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]'), '_')
        .trim();
    final stem = sanitized.isEmpty ? 'PiliGlass_video' : sanitized;
    final clipped = stem.length > 88 ? stem.substring(0, 88) : stem;
    final fileName = '$clipped.mp4';

    if (Platform.isAndroid) {
      final treeUri = Pref.localVideoDownloadUri;
      final res = await _channel.invokeMapMethod<String, dynamic>('muxToMp4', {
        'videoPath': videoPath,
        'audioPath': audioPath,
        'fileName': fileName,
        'treeUri': treeUri,
      });
      final displayPath =
          res?['displayPath'] as String? ?? 'Movies/PiliGlass/$fileName';
      final uri = res?['uri'] as String?;
      return (displayPath: displayPath, uri: uri);
    }

    // Desktop fallback using system ffmpeg if available
    final targetDir = Directory(
      Pref.localVideoDownloadUri ?? path.join(downloadPath, 'mp4'),
    );
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }
    var outFile = File(path.join(targetDir.path, fileName));
    var idx = 1;
    while (outFile.existsSync()) {
      outFile = File(path.join(targetDir.path, '${clipped}_$idx.mp4'));
      idx++;
    }
    if (audioPath == null) {
      await File(videoPath).copy(outFile.path);
    } else {
      final proc = await Process.run('ffmpeg', [
        '-y',
        '-i',
        videoPath,
        '-i',
        audioPath,
        '-c',
        'copy',
        outFile.path,
      ]);
      if (proc.exitCode != 0) {
        throw StateError('ffmpeg 合并失败：${proc.stderr}');
      }
    }
    return (displayPath: outFile.path, uri: outFile.path);
  }
}

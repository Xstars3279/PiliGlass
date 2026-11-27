package com.example.piliplus

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import kotlin.math.max

/**
 * Muxes DASH video/audio streams into a standard MP4 file using Android's
 * native MediaExtractor + MediaMuxer and saves it either to a user-chosen
 * SAF tree URI or MediaStore (Movies/PiliGlass).
 */
object Mp4Exporter {
    private const val CHANNEL = "piliglass/mp4_export"
    private const val REQUEST_CODE_PICK_TREE = 9421

    private var pendingPickResult: MethodChannel.Result? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDirectory" -> {
                        if (pendingPickResult != null) {
                            result.error("busy", "Directory picker already open", null)
                            return@setMethodCallHandler
                        }
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
                            )
                        }
                        activity.startActivityForResult(intent, REQUEST_CODE_PICK_TREE)
                    }

                    "muxToMp4" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val audioPath = call.argument<String>("audioPath")
                        val fileName = call.argument<String>("fileName") ?: "video.mp4"
                        val treeUriStr = call.argument<String>("treeUri")
                        if (videoPath == null) {
                            result.error("args", "Missing videoPath", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val res = exportMp4(
                                    activity = activity,
                                    videoPath = videoPath,
                                    audioPath = audioPath,
                                    fileName = fileName,
                                    treeUriStr = treeUriStr
                                )
                                activity.runOnUiThread { result.success(res) }
                            } catch (e: Exception) {
                                activity.runOnUiThread {
                                    result.error(
                                        "mux_failed",
                                        e.message ?: e.javaClass.simpleName,
                                        null
                                    )
                                }
                            }
                        }.start()
                    }

                    "openVideo" -> {
                        val uriStr = call.argument<String>("uri")
                        val pathStr = call.argument<String>("path")
                        try {
                            openExportedVideo(activity, uriStr, pathStr)
                            result.success(true)
                        } catch (e: FileMissingException) {
                            result.error("not_found", e.message, null)
                        } catch (e: android.content.ActivityNotFoundException) {
                            result.error("no_app", "未找到可用于播放视频的外部应用", null)
                        } catch (e: Exception) {
                            result.error("open_failed", e.message ?: e.javaClass.simpleName, null)
                        }
                    }

                    "deleteVideo" -> {
                        val uriStr = call.argument<String>("uri")
                        val pathStr = call.argument<String>("path")
                        Thread {
                            val deleted = deleteExportedVideo(activity, uriStr, pathStr)
                            activity.runOnUiThread { result.success(deleted) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    fun onActivityResult(
        activity: Activity,
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        if (requestCode != REQUEST_CODE_PICK_TREE) return false
        val pending = pendingPickResult
        pendingPickResult = null
        if (pending == null) return true
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return true
        }
        val uri = data.data!!
        val takeFlags =
            data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                if (takeFlags != 0) takeFlags
                else Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: SecurityException) {
            // Best effort if provider does not support persistable grants
        }
        val label = extractDisplayLabel(uri)
        pending.success(mapOf("uri" to uri.toString(), "label" to label))
        return true
    }

    private fun extractDisplayLabel(uri: Uri): String {
        val docId = try {
            DocumentsContract.getTreeDocumentId(uri)
        } catch (_: Exception) {
            uri.lastPathSegment ?: uri.toString()
        }
        val colon = docId.indexOf(':')
        if (colon >= 0) {
            val volume = docId.substring(0, colon)
            val rel = docId.substring(colon + 1)
            return if (volume == "primary") {
                if (rel.isEmpty()) "内部存储根目录" else rel
            } else {
                if (rel.isEmpty()) volume else "$volume/$rel"
            }
        }
        return docId
    }

    private fun exportMp4(
        activity: Activity,
        videoPath: String,
        audioPath: String?,
        fileName: String,
        treeUriStr: String?
    ): Map<String, String> {
        val safeName = ensureMp4Name(fileName)
        var tempMuxFile: File? = null
        val sourceMp4: File = if (audioPath == null && videoPath.endsWith(".mp4", ignoreCase = true)) {
            File(videoPath)
        } else {
            tempMuxFile = File.createTempFile("piliglass_mux_", ".mp4", activity.cacheDir)
            muxStreams(videoPath, audioPath, tempMuxFile)
            tempMuxFile
        }

        try {
            if (!treeUriStr.isNullOrEmpty()) {
                val treeUri = Uri.parse(treeUriStr)
                val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    DocumentsContract.getTreeDocumentId(treeUri)
                )
                val destUri = DocumentsContract.createDocument(
                    activity.contentResolver,
                    parentDocUri,
                    "video/mp4",
                    safeName
                ) ?: throw IllegalStateException("无法在所选目录创建文件")

                activity.contentResolver.openOutputStream(destUri)?.use { out ->
                    FileInputStream(sourceMp4).use { input -> input.copyTo(out, 65536) }
                } ?: throw IllegalStateException("无法写入目标文件")

                val label = extractDisplayLabel(treeUri)
                return mapOf(
                    "displayPath" to "$label/$safeName",
                    "uri" to destUri.toString()
                )
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, safeName)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(
                        MediaStore.Video.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_MOVIES}/PiliGlass"
                    )
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
                val resolver = activity.contentResolver
                val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val itemUri = resolver.insert(collection, values)
                    ?: throw IllegalStateException("无法写入系统视频媒体库")
                try {
                    resolver.openOutputStream(itemUri)?.use { out ->
                        FileInputStream(sourceMp4).use { input -> input.copyTo(out, 65536) }
                    } ?: throw IllegalStateException("无法打开媒体库输出流")
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    resolver.update(itemUri, values, null, null)
                } catch (e: Exception) {
                    resolver.delete(itemUri, null, null)
                    throw e
                }
                return mapOf(
                    "displayPath" to "Movies/PiliGlass/$safeName",
                    "uri" to itemUri.toString()
                )
            }

            @Suppress("DEPRECATION")
            val moviesDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
                "PiliGlass"
            )
            if (!moviesDir.exists()) moviesDir.mkdirs()
            val outFile = uniqueFile(moviesDir, safeName)
            sourceMp4.copyTo(outFile, overwrite = false)
            MediaScannerConnection.scanFile(activity, arrayOf(outFile.absolutePath), arrayOf("video/mp4"), null)
            return mapOf(
                "displayPath" to outFile.absolutePath,
                "uri" to Uri.fromFile(outFile).toString()
            )
        } finally {
            tempMuxFile?.delete()
        }
    }

    private fun muxStreams(videoPath: String, audioPath: String?, outFile: File) {
        val videoExtractor = MediaExtractor()
        val audioExtractor = if (audioPath != null) MediaExtractor() else null
        var muxer: MediaMuxer? = null
        try {
            videoExtractor.setDataSource(videoPath)
            val videoSrcTrack = findTrack(videoExtractor, "video/")
                ?: throw IllegalStateException("未找到视频轨道")
            videoExtractor.selectTrack(videoSrcTrack)
            val videoFormat = videoExtractor.getTrackFormat(videoSrcTrack)

            var audioSrcTrack = -1
            var audioFormat: MediaFormat? = null
            if (audioExtractor != null && audioPath != null) {
                audioExtractor.setDataSource(audioPath)
                audioSrcTrack = findTrack(audioExtractor, "audio/") ?: -1
                if (audioSrcTrack >= 0) {
                    audioExtractor.selectTrack(audioSrcTrack)
                    audioFormat = audioExtractor.getTrackFormat(audioSrcTrack)
                }
            }

            muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val videoMuxTrack = muxer.addTrack(videoFormat)
            val audioMuxTrack = if (audioFormat != null) {
                try {
                    muxer.addTrack(audioFormat)
                } catch (e: Exception) {
                    val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: "unknown"
                    throw IllegalStateException("音频格式不支持 MP4 封装 ($mime): ${e.message}")
                }
            } else -1

            val maxVideoBuf = getMaxInputSize(videoFormat)
            val maxAudioBuf = if (audioFormat != null) getMaxInputSize(audioFormat) else 0
            val buffer = ByteBuffer.allocateDirect(max(maxVideoBuf, max(maxAudioBuf, 512 * 1024)))
            val info = MediaCodec.BufferInfo()

            muxer.start()

            copySamples(videoExtractor, muxer, videoMuxTrack, buffer, info)
            if (audioExtractor != null && audioMuxTrack >= 0) {
                copySamples(audioExtractor, muxer, audioMuxTrack, buffer, info)
            }

            muxer.stop()
        } finally {
            try {
                muxer?.release()
            } catch (_: Exception) {}
            try {
                videoExtractor.release()
            } catch (_: Exception) {}
            try {
                audioExtractor?.release()
            } catch (_: Exception) {}
        }
    }

    private fun findTrack(extractor: MediaExtractor, prefix: String): Int? {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith(prefix)) return i
        }
        return null
    }

    private fun getMaxInputSize(format: MediaFormat): Int {
        return if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
        } else {
            1024 * 1024
        }
    }

    private fun copySamples(
        extractor: MediaExtractor,
        muxer: MediaMuxer,
        trackIndex: Int,
        buffer: ByteBuffer,
        info: MediaCodec.BufferInfo
    ) {
        while (true) {
            buffer.clear()
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) break
            info.offset = 0
            info.size = sampleSize
            info.presentationTimeUs = extractor.sampleTime
            @Suppress("DEPRECATION")
            info.flags = extractor.sampleFlags
            muxer.writeSampleData(trackIndex, buffer, info)
            extractor.advance()
        }
    }

    private fun ensureMp4Name(raw: String): String {
        val cleaned = raw
            .replace(Regex("""[\\/:*?"<>|\r\n\t]"""), "_")
            .trim()
            .ifEmpty { "PiliGlass_video" }
        val truncated = if (cleaned.length > 96) cleaned.substring(0, 96) else cleaned
        return if (truncated.endsWith(".mp4", ignoreCase = true)) truncated else "$truncated.mp4"
    }

    private fun uniqueFile(dir: File, name: String): File {
        var candidate = File(dir, name)
        if (!candidate.exists()) return candidate
        val stem = name.removeSuffix(".mp4")
        var idx = 1
        while (candidate.exists()) {
            candidate = File(dir, "${stem}_$idx.mp4")
            idx++
        }
        return candidate
    }

    private class FileMissingException(message: String) : Exception(message)

    private fun openExportedVideo(
        activity: Activity,
        uriStr: String?,
        pathStr: String?
    ) {
        val targetUri = resolvePlayableUri(activity, uriStr, pathStr)
            ?: throw FileMissingException("本地视频文件不存在或已被移动/删除")

        if (targetUri.scheme == "content") {
            try {
                activity.contentResolver.openAssetFileDescriptor(targetUri, "r")?.close()
                    ?: throw FileMissingException("本地视频文件不存在")
            } catch (e: FileMissingException) {
                throw e
            } catch (_: Exception) {
                throw FileMissingException("本地视频文件不存在或已被移动/删除")
            }
        } else if (targetUri.scheme == "file") {
            val file = targetUri.path?.let { File(it) }
            if (file == null || !file.exists()) {
                throw FileMissingException("本地视频文件不存在")
            }
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(targetUri, "video/mp4")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    private fun resolvePlayableUri(
        activity: Activity,
        uriStr: String?,
        pathStr: String?
    ): Uri? {
        if (!uriStr.isNullOrEmpty()) {
            val parsed = Uri.parse(uriStr)
            if (parsed.scheme == "content") return parsed
            val filePath = if (parsed.scheme == "file") parsed.path else uriStr
            if (!filePath.isNullOrEmpty()) {
                queryMediaStoreUri(activity, filePath)?.let { return it }
                val f = File(filePath)
                if (f.exists()) return Uri.fromFile(f)
            }
        }
        if (!pathStr.isNullOrEmpty() && pathStr.startsWith("/")) {
            queryMediaStoreUri(activity, pathStr)?.let { return it }
            val f = File(pathStr)
            if (f.exists()) return Uri.fromFile(f)
        }
        return null
    }

    private fun queryMediaStoreUri(activity: Activity, filePath: String): Uri? {
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Video.Media._ID)
        val selection = "${MediaStore.Video.Media.DATA}=?"
        activity.contentResolver.query(collection, projection, selection, arrayOf(filePath), null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return Uri.withAppendedPath(collection, id.toString())
            }
        }
        return null
    }

    private fun deleteExportedVideo(
        activity: Activity,
        uriStr: String?,
        pathStr: String?
    ): Boolean {
        if (!uriStr.isNullOrEmpty()) {
            val parsed = Uri.parse(uriStr)
            if (parsed.scheme == "content") {
                try {
                    if (DocumentsContract.isDocumentUri(activity, parsed)) {
                        if (DocumentsContract.deleteDocument(activity.contentResolver, parsed)) {
                            return true
                        }
                    }
                } catch (_: Exception) {}
                return try {
                    activity.contentResolver.delete(parsed, null, null) > 0
                } catch (_: Exception) {
                    false
                }
            }
            val filePath = if (parsed.scheme == "file") parsed.path else uriStr
            if (!filePath.isNullOrEmpty()) {
                val file = File(filePath)
                if (file.exists()) return file.delete()
            }
        }
        if (!pathStr.isNullOrEmpty() && pathStr.startsWith("/")) {
            val file = File(pathStr)
            if (file.exists()) return file.delete()
        }
        return false
    }
}

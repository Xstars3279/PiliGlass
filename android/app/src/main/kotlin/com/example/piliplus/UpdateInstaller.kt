package com.example.piliplus

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * PiliGlass: hands an update downloaded in the app to the system installer.
 * See lib/utils/update_download.dart.
 */
object UpdateInstaller {
    private const val CHANNEL = "piliglass/update"

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // whether the app may install packages; asked for in
                    // the system's settings since Android 8
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            activity.packageManager.canRequestPackageInstalls()
                    )

                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            activity.startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:${activity.packageName}")
                                )
                            )
                        }
                        result.success(null)
                    }

                    "install" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("path", "no path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            activity.startActivity(installIntent(activity, path))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("install", e.message, null)
                        }
                    }

                    // the download going on in the background, see
                    // [UpdateService]
                    "serviceStart" -> {
                        UpdateService.start(activity, call.argument<String>("title") ?: "")
                        result.success(null)
                    }

                    "serviceProgress" -> {
                        UpdateService.update(
                            activity,
                            call.argument<String>("title") ?: "",
                            call.argument<Int>("percent") ?: 0,
                            call.argument<String>("text") ?: ""
                        )
                        result.success(null)
                    }

                    // with a path, tapping the notification installs it
                    "serviceFinish" -> {
                        val path = call.argument<String>("path")
                        UpdateService.finish(
                            activity,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("text") ?: "",
                            path?.let {
                                PendingIntent.getActivity(
                                    activity, 1, installIntent(activity, it),
                                    PendingIntent.FLAG_IMMUTABLE or
                                        PendingIntent.FLAG_UPDATE_CURRENT
                                )
                            }
                        )
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun installIntent(context: Context, path: String): Intent =
        Intent(Intent.ACTION_VIEW)
            .setDataAndType(
                FileProvider.getUriForFile(context, "${context.packageName}.update", File(path)),
                "application/vnd.android.package-archive"
            )
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
}

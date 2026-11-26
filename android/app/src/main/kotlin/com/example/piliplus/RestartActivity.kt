package com.example.piliplus

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Process
import kotlin.system.exitProcess

/**
 * Runs in an isolated `:restart` process so the main app process (and its Dart VM)
 * can be torn down completely before relaunching the launcher activity.
 */
class RestartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mainPid = intent.getIntExtra(EXTRA_MAIN_PID, -1)
        if (mainPid > 0) {
            Process.killProcess(mainPid)
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent?.component != null) {
            startActivity(Intent.makeRestartActivityTask(launchIntent.component))
        }
        finish()
        exitProcess(0)
    }

    companion object {
        const val EXTRA_MAIN_PID = "extra_main_pid"
    }
}

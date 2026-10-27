package com.anthonyessaye.opentv

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Installing a build this app downloaded itself.
 *
 * Only ever for a copy that did not come from a store. An app distributed
 * through Google Play may not install packages from anywhere else — that is
 * the Device and Network Abuse policy, not a preference — so [installerName]
 * exists to let the Dart side refuse before it offers anything. A store copy
 * gets its updates from the store, which is both the rule and the right
 * answer.
 */
class UpdateChannel(private val activity: Activity) {

    companion object {
        const val CHANNEL = "opentv/update"

        /** Google Play's own package name, as the installer of record. */
        const val PLAY = "com.android.vending"
    }

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL).also {
            it.setMethodCallHandler(::handle)
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installerName" -> result.success(installerName())
            "canInstall" -> result.success(canInstall())
            "requestPermission" -> requestPermission(result)
            "install" -> install(call.argument<String>("path"), result)
            else -> result.notImplemented()
        }
    }

    /**
     * Who installed this copy, or null when nothing claims it.
     *
     * Null is the ordinary answer for a sideloaded build on older releases,
     * and it is *not* treated as "not from a store" by the caller on its own
     * — the caller asks whether it is Play, so an unknown installer behaves
     * like a sideload, which is what it is.
     */
    private fun installerName(): String? = runCatching {
        val packages = activity.packageManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            packages.getInstallSourceInfo(activity.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            packages.getInstallerPackageName(activity.packageName)
        }
    }.getOrNull()

    /** Whether the OS would let this app install a package at all. */
    private fun canInstall(): Boolean = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }.getOrDefault(false)

    /**
     * Sends the viewer to the OS screen that grants it.
     *
     * There is no dialog for this one — it is a Settings page per app, and
     * the answer arrives whenever they come back, so this reports nothing and
     * the caller asks [canInstall] again.
     */
    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(true)
            return
        }
        runCatching {
            activity.startActivity(
                Intent(
                    android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${activity.packageName}"),
                )
            )
            result.success(true)
        }.onFailure {
            // A television without that Settings screen. Reported rather than
            // thrown: there is nothing the viewer can do about it and the app
            // carries on working perfectly well un-updated.
            result.success(false)
        }
    }

    private fun install(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("no-file", "No downloaded build to install.", null)
            return
        }
        val file = File(path)
        if (!file.exists()) {
            result.error("no-file", "The downloaded build is not there.", null)
            return
        }

        runCatching {
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.updates",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                // The installer is another process and needs to be able to
                // read a file in this app's own storage.
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            result.success(true)
        }.onFailure { error ->
            result.error("install-failed", error.message, null)
        }
    }
}

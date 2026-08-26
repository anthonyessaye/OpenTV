package com.anthonyessaye.opentv

import android.app.UiModeManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of the host channel: a data directory and a keystore.
 *
 * Provider passwords are the reason this exists. Xtream puts the username and
 * password in the path of every stream URL, so the app has to keep the
 * password to play anything at all — which makes where it is kept a real
 * decision rather than a detail. It is not in the database: the schema holds
 * only a reference, and the secret lives here, encrypted with a key held in
 * the hardware-backed Android keystore and never leaving it.
 */
class HostChannel(private val context: Context) {

    /**
     * The opentv:// link this launch was started by, set by MainActivity.
     *
     * Held rather than delivered as an event. The link is what opened the
     * app, so it has already happened by the time any Dart exists to listen
     * for it — an event would fire into nothing. Dart asks once the tree is
     * up, and cleared after reading so a rotation does not replay it.
     */
    var pendingLink: String? = null
        set(value) {
            field = value
            // Pushed as well as held. Dart reads the pending value once, when
            // its tree comes up; a link arriving after that would sit here
            // unread, which is what left the handover screen with no address.
            if (value != null) channel?.invokeMethod("link", value)
        }

    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "opentv/host").also {
            it.setMethodCallHandler(::handle)
        }
    }

    /**
     * Built lazily and kept, because deriving the master key touches the
     * keystore and is slow enough to notice if it happened per call.
     */
    private val secrets: SharedPreferences by lazy {
        val key = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            "opentv_credentials",
            key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Internal storage: private to the app and durable until it is
            // uninstalled. Android has no equivalent of the tvOS purge, so
            // the catalogue can simply live here.
            "dataDirectory" -> result.success(context.filesDir.absolutePath)

            // Asked of UiModeManager rather than measured. An Android TV
            // reports 960x540 logical pixels and a tablet in landscape can
            // report the same shape, so no amount of looking at the screen
            // separates them — but the system already knows, because it is
            // what decided to launch the leanback home screen.
            //
            // The tablet threshold is Android's own: 600dp of smallest width
            // is the breakpoint every resource qualifier uses, so agreeing
            // with it means the layout and the resources cannot disagree.
            "deviceClass" -> {
                val modes = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
                val television =
                    modes?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                val smallestWidth = context.resources.configuration.smallestScreenWidthDp
                result.success(
                    when {
                        television -> "television"
                        smallestWidth >= 600 -> "tablet"
                        else -> "phone"
                    }
                )
            }

            "writeSecret" -> {
                val reference = call.argument<String>("reference")
                val secret = call.argument<String>("secret")
                if (reference == null || secret == null) {
                    result.error("bad-args", "reference and secret required", null)
                    return
                }
                secrets.edit().putString(reference, secret).apply()
                result.success(null)
            }

            // A missing secret is an ordinary answer, not an error: clearing
            // the app's data leaves a source whose password is simply gone.
            "readSecret" -> result.success(
                call.argument<String>("reference")?.let { secrets.getString(it, null) }
            )

            "deleteSecret" -> {
                call.argument<String>("reference")?.let {
                    secrets.edit().remove(it).apply()
                }
                result.success(null)
            }

            "initialLink" -> {
                result.success(pendingLink)
                pendingLink = null
            }

            else -> result.notImplemented()
        }
    }
}

package co.podeo.opentv.tvos_playback

import android.content.Context
import android.content.SharedPreferences
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

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, "opentv/host").setMethodCallHandler(::handle)
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

            else -> result.notImplemented()
        }
    }
}

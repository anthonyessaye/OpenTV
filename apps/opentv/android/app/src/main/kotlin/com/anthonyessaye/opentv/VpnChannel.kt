package com.anthonyessaye.opentv

import android.app.Activity
import android.content.Intent
import com.wireguard.android.backend.Backend
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.StringReader
import kotlin.concurrent.thread

/**
 * The Android half of the tunnel.
 *
 * WireGuard rather than OpenVPN, and the upstream library rather than a
 * hand-rolled `VpnService`. The two reasons are the same one twice: OpenVPN's
 * usable Android implementations are GPL-2.0 and the reference daemon is
 * AGPL-3.0, either of which would decide this project's licence for it and
 * shut the App Store out; and a userspace WireGuard implementation is a
 * cryptographic component, which is not something to write for the practice.
 * `com.wireguard.android:tunnel` is Apache-2.0, ships the audited Go tunnel
 * for all four ABIs, and declares its own `VpnService` in its manifest.
 *
 * The configuration text crosses the channel whole and is parsed twice, which
 * is deliberate. Dart parses it to tell the viewer what is wrong with a file
 * they pasted, before any of this runs; the library parses it because it is
 * the thing that has to be satisfied, and re-marshalling a config through a
 * map of strings only invents a way for the two to disagree.
 */
class VpnChannel(private val activity: Activity) {

    /** Chosen by the OS consent dialog's result, and by nothing else. */
    private companion object {
        const val CONSENT_REQUEST = 0x7601
    }

    private val backend: Backend by lazy { GoBackend(activity.applicationContext) }

    private var channel: MethodChannel? = null

    /** Held so the consent result can answer the call that asked for it. */
    private var pendingConsent: MethodChannel.Result? = null

    /**
     * One tunnel. The app is a client of a VPN, not a manager of several, so
     * there is nothing to name and nothing to choose between.
     */
    private val tunnel = object : Tunnel {
        override fun getName() = "opentv"

        override fun onStateChange(state: Tunnel.State) {
            // Reported rather than polled: a tunnel can drop without anyone
            // asking, and an interface still claiming "protected" after that
            // is worse than one that never claimed it.
            activity.runOnUiThread {
                channel?.invokeMethod("state", state.name.lowercase())
            }
        }
    }

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "opentv/vpn").also {
            it.setMethodCallHandler(::handle)
        }
    }

    /**
     * Answers the pending `prepare` once the viewer has decided.
     *
     * Returns whether the result belonged to this channel, so the activity can
     * pass anything else along.
     */
    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != CONSENT_REQUEST) return false
        pendingConsent?.success(resultCode == Activity.RESULT_OK)
        pendingConsent = null
        return true
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> prepare(result)
            "hasPermission" -> result.success(
                // Asked without launching anything. Connecting on launch has
                // to be able to tell "already allowed" from "would put a
                // system dialog in front of somebody who just turned their
                // television on", and prepare() cannot: it answers by
                // showing the dialog.
                GoBackend.VpnService.prepare(activity) == null,
            )
            "up" -> up(call.argument<String>("config"), result)
            "down" -> down(result)
            "state" -> state(result)
            "statistics" -> statistics(result)
            "version" -> off(result) { backend.version }
            else -> result.notImplemented()
        }
    }

    /**
     * Asks for the OS's own permission to route traffic.
     *
     * This dialog is not skippable and not fake-able — it is the only thing
     * standing between an app and every packet the device sends, and Android
     * is right to insist a human sees it. `null` means it has been granted
     * already, on this install, for this app.
     */
    private fun prepare(result: MethodChannel.Result) {
        val intent: Intent? = GoBackend.VpnService.prepare(activity)
        if (intent == null) {
            result.success(true)
            return
        }
        if (pendingConsent != null) {
            result.error("busy", "The permission dialog is already open.", null)
            return
        }
        pendingConsent = result
        activity.startActivityForResult(intent, CONSENT_REQUEST)
    }

    private fun up(text: String?, result: MethodChannel.Result) {
        if (text.isNullOrBlank()) {
            result.error("config", "No configuration was supplied.", null)
            return
        }
        off(result) {
            val config = Config.parse(BufferedReader(StringReader(text)))
            backend.setState(tunnel, Tunnel.State.UP, config).name.lowercase()
        }
    }

    private fun down(result: MethodChannel.Result) {
        off(result) {
            backend.setState(tunnel, Tunnel.State.DOWN, null).name.lowercase()
        }
    }

    private fun state(result: MethodChannel.Result) {
        off(result) { backend.getState(tunnel).name.lowercase() }
    }

    private fun statistics(result: MethodChannel.Result) {
        off(result) {
            val stats = backend.getStatistics(tunnel)
            mapOf(
                "rx" to stats.totalRx(),
                "tx" to stats.totalTx(),
                // A tunnel that is up but has moved nothing since the last
                // handshake is the shape a dead peer takes, so the freshness
                // of these figures is part of the reading.
                "stale" to stats.isStale,
            )
        }
    }

    /**
     * Runs the work off the main thread and answers on it.
     *
     * Bringing a tunnel up blocks on a handshake with a host that may not
     * answer. On the main thread that is a frozen television for however long
     * the timeout is, and the viewer's only reading of it is that the app has
     * crashed.
     */
    private fun off(result: MethodChannel.Result, work: () -> Any?) {
        thread {
            val outcome = runCatching(work)
            activity.runOnUiThread {
                outcome
                    .onSuccess(result::success)
                    .onFailure {
                        // The message only. A WireGuard failure carries the
                        // configuration in some of its exception paths, and a
                        // stack trace crossing into Dart is a private key one
                        // log line away from a bug report.
                        result.error(
                            "vpn",
                            it.message ?: it::class.java.simpleName,
                            null,
                        )
                    }
            }
        }
    }
}

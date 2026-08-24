package com.anthonyessaye.opentv

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var vpn: VpnChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registered under the same view type the tvOS side uses, so the Dart
        // code asks for "opentv/player" on both and gets whichever engine the
        // platform provides.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "opentv/player",
            PlayerPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        // Somewhere durable for the catalogue, and a hardware-backed keystore
        // for the provider password — which the database deliberately does
        // not hold.
        HostChannel(applicationContext).attach(flutterEngine.dartExecutor.binaryMessenger)

        // The activity rather than the context: granting a VPN permission is
        // a dialog the OS shows on behalf of an activity, and its answer comes
        // back through onActivityResult below.
        vpn = VpnChannel(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    @Deprecated("Flutter's own embedding still routes results through this.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (vpn?.onActivityResult(requestCode, resultCode) == true) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}

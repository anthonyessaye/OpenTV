package co.podeo.opentv.tvos_playback

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Registered under the same view type the tvOS side uses, so the Dart
        // code asks for "opentv/player" on both and gets whichever engine the
        // platform provides.
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "opentv/player",
            PlayerPlatformViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }
}

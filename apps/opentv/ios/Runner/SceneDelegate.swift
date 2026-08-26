import Flutter
import UIKit

/// Where an `opentv://` link actually arrives.
///
/// This project is scene-based — the generated iOS runner declares a
/// `UIApplicationSceneManifest` — and that changes which callbacks fire.
/// `application(_:open:options:)` is never called, and `launchOptions[.url]`
/// is never populated, so an AppDelegate that handles both of those handles
/// neither. The link was reaching the app and stopping there: nothing set the
/// pending link, `Host.initialLink()` returned null, and a scanned code
/// produced a receive screen that sat at nought per cent because it had no
/// address to fetch from.
///
/// Both entry points are covered here. A cold launch carries the URL in the
/// connection options; a link arriving while the app is already open comes
/// through `openURLContexts`.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    if let url = connectionOptions.urlContexts.first(where: {
      $0.url.scheme == "opentv"
    })?.url {
      HostChannel.pendingLink = url.absoluteString
    }
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first(where: { $0.url.scheme == "opentv" })?.url {
      HostChannel.pendingLink = url.absoluteString
      // Told rather than left to be asked for. Dart reads the pending link
      // once, when its tree comes up; a link arriving afterwards would sit
      // there unread — which is the second half of the same bug.
      HostChannel.announce(url.absoluteString)
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}

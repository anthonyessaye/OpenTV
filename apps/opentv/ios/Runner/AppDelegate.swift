import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The link that opened us, taken before Flutter starts so it is already
    // waiting when Dart asks.
    if let url = launchOptions?[.url] as? URL, url.scheme == "opentv" {
      HostChannel.pendingLink = url.absoluteString
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// A link arriving while the app is already running.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.scheme == "opentv" else {
      return super.application(app, open: url, options: options)
    }
    HostChannel.pendingLink = url.absoluteString
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The same channel the television answers, from the same source file.
    //
    // apple/HostChannel.swift is compiled into both targets rather than
    // copied, which is the only arrangement that lets the contract test mean
    // anything: a test that reads one file cannot vouch for a second copy of
    // it that has drifted.
    // Reached through a registrar rather than off the bridge directly: the
    // bridge exposes the plugin registry and nothing else, and a registrar is
    // what carries a messenger. The television takes the same route.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenTVHost") {
      HostChannel.attach(messenger: registrar.messenger())

      // The same view type the television registers, backed by the same
      // Swift file. Dart asks for "opentv/player" on every platform and never
      // learns which engine answered.
      registrar.register(
        VlcPlayerFactory(messenger: registrar.messenger()),
        withId: "opentv/player"
      )
    }
  }
}

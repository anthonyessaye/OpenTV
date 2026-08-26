import Flutter
import UIKit

// tvOS 27 traps at launch unless the app adopts the UIScene lifecycle:
// UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption raises
// EXC_BREAKPOINT. The flutter-tvos template still builds its window the
// classic way in the app delegate, so the window is created in SceneDelegate
// instead.
//
// The engine is created and run here rather than inside the view controller
// so platform view registration has one deterministic home. Letting
// FlutterViewController build its own engine would leave registration racing
// scene connection.

@main
class AppDelegate: FlutterAppDelegate {
    lazy var engine = FlutterEngine(name: "opentv-spike")

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)

        let registrar = engine.registrar(forPlugin: "opentv-vlc")!
        registrar.register(
            VlcPlayerFactory(messenger: registrar.messenger()),
            withId: "opentv/player"
        )

        // Somewhere to put the catalogue, and the Keychain for the provider
        // password — which the database deliberately does not hold.
        HostChannel.attach(messenger: registrar.messenger())

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene,
              let delegate = UIApplication.shared.delegate as? AppDelegate
        else { return }

        let controller = FlutterViewController(
            engine: delegate.engine,
            nibName: nil,
            bundle: nil
        )
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
}

/// Hosts a libVLC surface inside the Flutter view hierarchy.
///
/// This is the spike's entire reason for existing. AVPlayer — and therefore
/// `video_player_tvos`, which wraps it — cannot decode MPEG-TS or Matroska,
/// and between them those account for the great majority of a real IPTV
/// catalogue. libVLC can. The question is whether it can do so through a
/// Flutter platform view on tvOS.

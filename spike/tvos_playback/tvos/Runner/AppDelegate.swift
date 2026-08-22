import UIKit
import Flutter

// tvOS 27 traps at launch unless the app adopts the UIScene lifecycle:
// UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption raises
// EXC_BREAKPOINT. The flutter-tvos template still builds its window the
// classic way in the app delegate, so the window is created here instead.
//
// SceneDelegate lives in this file deliberately: adding a new .swift file
// would mean editing project.pbxproj, and Swift is happy with two classes
// in one file.

@main
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
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
        guard let windowScene = scene as? UIWindowScene else { return }

        let controller = FlutterViewController(project: nil, nibName: nil, bundle: nil)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
}

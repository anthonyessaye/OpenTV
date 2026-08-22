import Flutter
import TVVLCKit
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
            withId: "opentv/vlc-player"
        )

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
final class VlcPlayerView: NSObject, FlutterPlatformView, VLCMediaPlayerDelegate {
    private let container: UIView
    private let player = VLCMediaPlayer()
    private let channel: FlutterMethodChannel

    /// Reported back to Dart so a test can assert on decode progress rather
    /// than a human squinting at a screenshot.
    private var framesSeen = false

    init(
        frame: CGRect,
        viewId: Int64,
        arguments: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        container = UIView(frame: frame)
        container.backgroundColor = .black
        channel = FlutterMethodChannel(
            name: "opentv/vlc/\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        player.delegate = self
        player.drawable = container

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        if let args = arguments as? [String: Any],
           let urlString = args["url"] as? String {
            play(urlString: urlString, options: args["options"] as? [String: String])
        }
    }

    func view() -> UIView { container }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String else {
                result(FlutterError(code: "bad-args", message: "url required", details: nil))
                return
            }
            play(urlString: url, options: args["options"] as? [String: String])
            result(nil)

        case "stop":
            player.stop()
            result(nil)

        case "state":
            result(snapshot())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func play(urlString: String, options: [String: String]?) {
        guard let url = URL(string: urlString) else { return }

        let media = VLCMedia(url: url)

        // Providers frequently refuse to serve a stream without the user agent
        // or referrer their playlist named, so those have to reach libVLC.
        options?.forEach { key, value in
            switch key {
            case "http-user-agent":
                media.addOption(":http-user-agent=\(value)")
            case "http-referrer":
                media.addOption(":http-referrer=\(value)")
            default:
                media.addOption(":\(key)=\(value)")
            }
        }

        // Live IPTV wants a short cache. The default is tuned for files.
        media.addOption(":network-caching=1500")

        framesSeen = false
        player.media = media
        player.play()
    }

    /// Everything a test needs to decide whether decoding actually happened.
    private func snapshot() -> [String: Any] {
        let size = player.videoSize
        return [
            "state": describe(player.state),
            "isPlaying": player.isPlaying,
            "hasVideoOut": player.hasVideoOut,
            "framesSeen": framesSeen,
            "width": Int(size.width),
            "height": Int(size.height),
            "position": player.position,
            "audioTracks": player.numberOfAudioTracks,
            "videoTracks": player.numberOfVideoTracks,
        ]
    }

    private func describe(_ state: VLCMediaPlayerState) -> String {
        switch state {
        case .stopped: return "stopped"
        case .opening: return "opening"
        case .buffering: return "buffering"
        case .ended: return "ended"
        case .error: return "error"
        case .playing: return "playing"
        case .paused: return "paused"
        case .esAdded: return "esAdded"
        @unknown default: return "unknown"
        }
    }

    // MARK: - VLCMediaPlayerDelegate

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        if player.hasVideoOut { framesSeen = true }
        channel.invokeMethod("state", arguments: snapshot())
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        // Time advancing is the strongest signal that frames are being
        // decoded rather than the pipeline merely being open.
        if player.hasVideoOut { framesSeen = true }
    }
}

/// Builds `VlcPlayerView`s on demand for Flutter's `UiKitView`.
final class VlcPlayerFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        VlcPlayerView(
            frame: frame,
            viewId: viewId,
            arguments: args,
            messenger: messenger
        )
    }

    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

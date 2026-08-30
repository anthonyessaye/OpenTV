import Flutter
import UIKit

// libVLC, under whichever name the platform ships it.
//
// TVVLCKit and MobileVLCKit are the same library with the same API — the
// binding differs only in which UIKit it was built against. So this file is
// one implementation compiled into both Apple targets rather than two that
// have to be kept agreeing, which is the same arrangement HostChannel uses
// and for the same reason: the contract test reads one file, and a second
// copy that has drifted is exactly what it cannot see.
#if os(tvOS)
import TVVLCKit
#else
import MobileVLCKit
#endif

final class VlcPlayerView: NSObject, FlutterPlatformView, VLCMediaPlayerDelegate {
    private let container: UIView
    private let player = VLCMediaPlayer()
    private let channel: FlutterMethodChannel

    /// Reported back to Dart so a test can assert on decode progress rather
    /// than a human squinting at a screenshot.
    private var framesSeen = false

    /// Whether this surface should hold the display awake while it plays.
    ///
    /// A television with nothing to do dims and hands over to its
    /// screensaver, and it decides that from input rather than from whether
    /// anything is on screen. Watching a film is the one activity where a
    /// viewer sends no input for two hours by design, so the screensaver took
    /// the picture while the film carried on behind it.
    ///
    /// False for the browse screen's preview: decoration must not keep a
    /// panel lit because a channel is idling in a box.
    private var keepAwake = true

    /// Whether this view is the one currently holding the timer off.
    ///
    /// Tracked because the flag is application-wide while players are not.
    /// Without it, one view finishing would clear a hold another had taken,
    /// and the screensaver would arrive mid-film anyway.
    private var holdingIdleTimer = false

    init(
        frame: CGRect,
        viewId: Int64,
        arguments: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        container = UIView(frame: frame)
        container.backgroundColor = .black
        channel = FlutterMethodChannel(
            name: "opentv/player/\(viewId)",
            binaryMessenger: messenger
        )
        super.init()

        player.delegate = self
        player.drawable = container

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        if let args = arguments as? [String: Any] {
            keepAwake = args["keepAwake"] as? Bool ?? true
        }

        if let args = arguments as? [String: Any],
           let urlString = args["url"] as? String {
            play(
                urlString: urlString,
                options: args["options"] as? [String: String],
                startAtMs: args["startAtMs"] as? Int
            )
        }
    }

    func view() -> UIView { container }

    deinit {
        // The hold is application-wide and this view is not. Left set by a
        // view that no longer exists, it keeps the television awake until the
        // app is killed.
        releaseIdleTimer()
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "play":
            // A play with no url means resume, which is what the transport
            // controls send after a pause. Demanding a url here made the
            // shared chrome's resume impossible on this platform while it
            // worked on the other — the two sides answer one contract, so
            // they have to answer all of it.
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String {
                    play(
                    urlString: url,
                    options: args["options"] as? [String: String],
                    startAtMs: args["startAtMs"] as? Int
                )
            } else {
                player.play()
            }
            result(nil)

        case "pause":
            // VLC's pause is a toggle, which would make two presses of a
            // dedicated pause button cancel each other out. The chrome asks
            // for a state, not a flip, so only pause when actually playing.
            if player.isPlaying {
                player.pause()
            }
            result(nil)

        case "stop":
            player.stop()
            // Asked for directly rather than waited for: stopping is the one
            // path where the state notification is not guaranteed, and a
            // missed one leaves the display pinned awake with nothing playing.
            releaseIdleTimer()
            result(nil)

        case "state":
            result(snapshot())

        // The same three methods Android answers, so the Dart side never
        // learns which engine is underneath.
        case "tracks":
            result(tracks())

        case "selectTrack":
            guard let args = call.arguments as? [String: Any],
                  let type = args["type"] as? String else {
                result(FlutterError(code: "bad-args", message: "type required", details: nil))
                return
            }
            selectTrack(type: type, id: args["id"] as? String)
            result(nil)

        // Moves to a position, in milliseconds from the start.
        //
        // Clamped for the same reason Android clamps: a viewer holding the
        // skip button asks for positions past the end well before they let
        // go, and a seek past the end stops playback rather than finishing.
        case "seek":
            guard let requested = (call.arguments as? [String: Any])?["positionMs"] as? NSNumber else {
                result(FlutterError(code: "bad-args", message: "positionMs required", details: nil))
                return
            }
            let lengthMs = player.media?.length.intValue ?? 0
            let ceiling = lengthMs > 0 ? Int32(lengthMs) - 1_000 : Int32.max
            let target = min(max(Int32(truncating: requested), 0), max(0, ceiling))
            player.time = VLCTime(int: target)
            result(nil)

        case "addSubtitle":
            // libVLC takes a subtitle as a slave on the media that is already
            // playing, so nothing is torn down and the viewer keeps their
            // place. Media3 has no such thing and has to rebuild the item and
            // re-prepare, which is why the same feature costs a rebuffer on
            // Android and nothing here.
            guard let path = (call.arguments as? [String: Any])?["path"] as? String
            else {
                result(FlutterError(
                    code: "addSubtitle",
                    message: "no path",
                    details: nil
                ))
                return
            }
            // Enforced rather than merely offered: somebody who has just gone
            // looking for a subtitle, chosen one and waited for it does not
            // then want to find it switched off in a menu.
            //
            // Returns libVLC's own status rather than a Bool: zero is
            // success and anything else is a refusal, which is the C
            // convention the binding passes straight through.
            let status = player.addPlaybackSlave(
                URL(fileURLWithPath: path),
                type: .subtitle,
                enforce: true
            )
            result(status == 0 ? nil : FlutterError(
                code: "addSubtitle",
                message: "the engine refused the subtitle file",
                details: nil
            ))

        case "setAspect":
            let mode = (call.arguments as? [String: Any])?["mode"] as? String ?? "fit"
            applyAspect(mode)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func play(urlString: String, options: [String: String]?, startAtMs: Int? = nil) {
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
        lastError = nil
        player.media = media
        player.play()

        // Resuming a half-watched film. Set after play rather than before,
        // because VLC has no media to seek within until playback has begun —
        // and the position is applied as soon as it does, so the opening
        // seconds are not shown first.
        if let startAtMs, startAtMs > 0 {
            player.time = VLCTime(int: Int32(startAtMs))
        }
    }

    /// How the picture is currently fitted to the panel.
    private var aspectMode = "fit"

    /// Why playback stopped, when it did.
    private var lastError: String?

    /// Every selectable track, in the shape the Dart chooser expects.
    ///
    /// libVLC describes tracks as parallel arrays of indexes and names, which
    /// is nothing like Media3's groups — mapping both into one shape here is
    /// what lets a single chooser serve both televisions.
    ///
    /// VLC's own "Disable" entry (index -1) is dropped: the interface already
    /// offers Off as its own row, and two ways to say the same thing in one
    /// list is a way to confuse a viewer.
    private func tracks() -> [[String: Any?]] {
        var out: [[String: Any?]] = []

        func collect(_ indexes: [Any]?, _ names: [Any]?, kind: String) {
            guard let indexes = indexes as? [NSNumber],
                  let names = names as? [String] else { return }
            let current: Int32 = kind == "audio"
                ? player.currentAudioTrackIndex
                : player.currentVideoSubTitleIndex

            for (position, index) in indexes.enumerated() where index.int32Value >= 0 {
                out.append([
                    "type": kind,
                    "id": "\(index.int32Value)",
                    "label": position < names.count ? names[position] : "Track",
                    "language": nil,
                    "selected": index.int32Value == current,
                    "codec": nil,
                    "channels": nil,
                    "width": nil,
                    "height": nil,
                    "hdr": nil,
                ])
            }
        }

        collect(player.audioTrackIndexes, player.audioTrackNames, kind: "audio")
        collect(player.videoSubTitlesIndexes, player.videoSubTitlesNames, kind: "text")
        return out
    }

    private func selectTrack(type: String, id: String?) {
        // A nil id means Off for subtitles, and automatic for audio. VLC
        // expresses both as index -1.
        let index = id.flatMap { Int32($0) } ?? -1
        switch type {
        case "audio":
            player.currentAudioTrackIndex = index
        case "text":
            player.currentVideoSubTitleIndex = index
        default:
            break
        }
    }

    /// The four modes the Dart side offers, in VLC's vocabulary.
    ///
    /// VLC separates two ideas Media3 combines: `videoAspectRatio` reshapes
    /// the picture, and `scaleFactor` zooms it. Fit is both cleared, which is
    /// VLC's default and is correct; fill crops by scaling until the shorter
    /// edge is covered; stretch forces the panel's own ratio; original pins
    /// the scale to 1.
    private func applyAspect(_ mode: String) {
        aspectMode = mode

        switch mode {
        case "fill":
            player.videoAspectRatio = nil
            player.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: ("16:9" as NSString).utf8String)
        case "stretch":
            player.videoCropGeometry = nil
            let bounds = container.bounds
            if bounds.height > 0 {
                let ratio = "\(Int(bounds.width)):\(Int(bounds.height))"
                player.videoAspectRatio = UnsafeMutablePointer<Int8>(mutating: (ratio as NSString).utf8String)
            }
        case "original":
            player.videoCropGeometry = nil
            player.videoAspectRatio = nil
            player.scaleFactor = 1
        default:
            player.videoCropGeometry = nil
            player.videoAspectRatio = nil
            player.scaleFactor = 0 // 0 means "fit the view", which is VLC's default
        }
    }

    /// Everything a test needs to decide whether decoding actually happened.
    private func snapshot() -> [String: Any] {
        let size = player.videoSize
        // VLC reports a duration of 0 for live streams, which is how the
        // chrome tells "no end" from "not known yet".
        let lengthMs = player.media?.length.intValue ?? 0

        return [
            "state": describe(player.state),
            "isPlaying": player.isPlaying,
            "hasVideoOut": player.hasVideoOut,
            "framesSeen": framesSeen,
            "width": Int(size.width),
            "height": Int(size.height),
            "position": player.position,
            "timeMs": player.time.intValue ?? 0,
            "lengthMs": lengthMs,
            "audioTracks": player.numberOfAudioTracks,
            "videoTracks": player.numberOfVideoTracks,
            "subtitleTracks": player.numberOfSubtitlesTracks,
            "aspectMode": aspectMode,
            // Named rather than left absent. Android reports its decoder's
            // error code here; libVLC exposes no message, only a state, so
            // this says which state rather than pretending to more detail.
            // Without it a dead channel on Apple TV showed FAILED and no
            // reason at all — the contract test that should have caught that
            // matched the word "error" somewhere else entirely.
            "error": lastError as Any,
            // dynamicRange and videoCodec are deliberately absent rather than
            // present and empty. libVLC does not report a transfer function,
            // so HDR cannot be named here the way Media3 names it, and the
            // Dart side reads a missing key as "unknown" — which is honest.
            // A wrong badge is worse than no badge.
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
        // On a real provider a dead channel is routine. Recording why lets
        // the interface say so instead of spinning.
        if player.state == .error {
            lastError = "the stream could not be opened"
        }
        if player.hasVideoOut { framesSeen = true }
        updateIdleTimer()
        channel.invokeMethod("state", arguments: snapshot())
    }

    /// Holds the display awake for as long as something is actually playing.
    ///
    /// Tied to playing rather than to existing, because a film left paused
    /// overnight should be allowed to let the screen sleep.
    private func updateIdleTimer() {
        let wanted = keepAwake && player.isPlaying
        guard wanted != holdingIdleTimer else { return }
        holdingIdleTimer = wanted
        UIApplication.shared.isIdleTimerDisabled = wanted
    }

    /// Releases the hold, whatever state the player was left in.
    ///
    /// Called on teardown: an application-wide flag left set by a view that
    /// no longer exists keeps a television awake until the app is killed.
    func releaseIdleTimer() {
        guard holdingIdleTimer else { return }
        holdingIdleTimer = false
        UIApplication.shared.isIdleTimerDisabled = false
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

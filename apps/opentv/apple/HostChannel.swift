import Flutter
import Foundation
import Security
import UIKit

/// The tvOS half of the host channel: a data directory and the Keychain.
///
/// Both answers differ from Android's in ways that matter to the app above.
final class HostChannel {

    /// The opentv:// link this launch was opened by, if any.
    ///
    /// Held rather than delivered as an event, for the reason the Android
    /// half holds one too: the link is what opened the app, so it has already
    /// happened before any Dart exists to hear about it. Cleared when read.
    static var pendingLink: String?

    /// The live channel, so a link arriving while the app is running can be
    /// pushed rather than waiting to be asked for.
    private static var channel: FlutterMethodChannel?

    /// Tells Dart about a link that arrived after the tree was already up.
    ///
    /// Pulling alone is not enough. `initialLink` is read once, when the tree
    /// comes up, which covers a cold launch and nothing else — a code scanned
    /// with the app already open set a pending link that nobody ever
    /// collected.
    static func announce(_ link: String) {
        channel?.invokeMethod("link", arguments: link)
    }

    static func attach(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "opentv/host", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            handle(call, result)
        }
        self.channel = channel
    }

    private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {

        // UIKit's own idiom, shared verbatim with the iOS target.
        //
        // This file is compiled into both, which is the point: tvOS reports
        // itself to Dart as iOS, so nothing above this line can tell an Apple
        // TV from an iPhone. UIUserInterfaceIdiom can, and it is the same
        // answer on both platforms rather than two implementations that have
        // to be kept agreeing.
        case "initialLink":
            result(pendingLink)
            pendingLink = nil
            return

        case "deviceClass":
            switch UIDevice.current.userInterfaceIdiom {
            case .tv: result("television")
            case .pad: result("tablet")
            default: result("phone")
            }
            return

        // The caches directory, and not by preference.
        //
        // tvOS gives an app no directory that survives by right: there is a
        // small key-value store, and a cache the system may purge whenever it
        // wants space. A 284,000-row catalogue fits in neither, so on Apple TV
        // it is a cache by necessity and can vanish between launches. The Dart
        // side is written to expect that; the sync engine is resumable and
        // checkpointed per stage precisely so re-filling it is routine rather
        // than an incident.
        case "dataDirectory":
            let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            guard let base = paths.first else {
                result(FlutterError(code: "no-directory",
                                    message: "tvOS returned no caches directory",
                                    details: nil))
                return
            }
            let directory = (base as NSString).appendingPathComponent("opentv")
            do {
                try FileManager.default.createDirectory(
                    atPath: directory, withIntermediateDirectories: true)
                result(directory)
            } catch {
                result(FlutterError(code: "no-directory",
                                    message: error.localizedDescription,
                                    details: nil))
            }

        case "writeSecret":
            guard let args = call.arguments as? [String: Any],
                  let reference = args["reference"] as? String,
                  let secret = args["secret"] as? String,
                  let data = secret.data(using: .utf8) else {
                result(FlutterError(code: "bad-args",
                                    message: "reference and secret required",
                                    details: nil))
                return
            }

            // Delete first rather than trying to update: SecItemAdd fails with
            // errSecDuplicateItem on a re-entered password, which is the most
            // ordinary case there is.
            SecItemDelete(query(for: reference) as CFDictionary)

            var attributes = query(for: reference)
            attributes[kSecValueData as String] = data
            // Never synchronised to other devices and never in a backup: this
            // is one television's copy of one provider's password.
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

            let status = SecItemAdd(attributes as CFDictionary, nil)
            guard status == errSecSuccess else {
                result(FlutterError(code: "keychain",
                                    message: "could not store the secret (OSStatus \(status))",
                                    details: nil))
                return
            }
            result(nil)

        case "readSecret":
            guard let args = call.arguments as? [String: Any],
                  let reference = args["reference"] as? String else {
                result(nil)
                return
            }
            var lookup = query(for: reference)
            lookup[kSecReturnData as String] = true
            lookup[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(lookup as CFDictionary, &item)
            // A missing secret is an ordinary answer, not a failure: the
            // catalogue's directory can be purged, or the app's data cleared,
            // leaving a source whose password is simply gone.
            guard status == errSecSuccess, let data = item as? Data else {
                result(nil)
                return
            }
            result(String(data: data, encoding: .utf8))

        case "deleteSecret":
            if let args = call.arguments as? [String: Any],
               let reference = args["reference"] as? String {
                SecItemDelete(query(for: reference) as CFDictionary)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func query(for reference: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.anthonyessaye.opentv.credentials",
            kSecAttrAccount as String: reference,
        ]
    }
}

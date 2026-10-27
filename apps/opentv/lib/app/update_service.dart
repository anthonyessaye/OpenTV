import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opentv_core/opentv_core.dart';
import '../http_transport.dart';
import 'app_version.dart';
import 'host.dart';

/// Where this app publishes its builds.
const _owner = 'anthonyessaye';
const _repository = 'OpenTV';

/// Checking for a newer build, and installing one.
///
/// **Only for a copy no store installed.** An app distributed through Google
/// Play may not install packages from anywhere else; that is the Device and
/// Network Abuse policy rather than a preference, and a Play copy gets its
/// updates from Play, which is also the right answer. [isOffered] is false
/// there and nothing is ever fetched.
///
/// It exists at all because the other copy has no path: a sideloaded build on
/// a television has no browser to go and find an APK with, and nothing to
/// tell it a fix has shipped.
class UpdateService {
  UpdateService({Transport? transport, this.host = const Host()})
      : _feed = ReleaseFeed(
          owner: _owner,
          repository: _repository,
          transport: transport ?? HttpTransport(),
        );

  static const _channel = MethodChannel('opentv/update');

  final ReleaseFeed _feed;
  final Host host;

  /// The newest build, once a check has found one worth offering.
  final available = ValueNotifier<AppRelease?>(null);

  /// What went wrong, in a sentence, or null.
  final problem = ValueNotifier<String?>(null);

  /// How far a download has got, 0 to 1, or null when nothing is downloading.
  final progress = ValueNotifier<double?>(null);

  /// Whether this platform and this copy can be updated in place at all.
  ///
  /// Android only — the Apple platforms have no such thing and never will,
  /// since an app there is installed by the store and nothing else.
  Future<bool> isOffered() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final installer = await _channel.invokeMethod<String>('installerName');
      // Only Play is excluded by name. An unknown installer is a sideload,
      // which is what it is, and every other store is in the same position
      // this feature exists for.
      return installer != 'com.android.vending';
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Looks for a newer build, and says nothing at all when there is not one.
  ///
  /// Never throws, for the reason a sync pass never does: this runs on the
  /// launch path and an update check that can stop the app opening is worse
  /// than no update check.
  Future<AppRelease?> check() async {
    try {
      if (!await isOffered()) return null;

      final release = await _feed.fetch();
      if (release == null) return null;
      if (!ReleaseFeed.isNewer(release.version, appVersion)) return null;
      // A release with no installable file is a tag, not an update.
      if (release.apk == null) return null;

      available.value = release;
      return release;
    } on Object catch (error) {
      problem.value = '$error';
      return null;
    }
  }

  /// Fetches the build and hands it to the system installer.
  ///
  /// Returns what went wrong, or null once the installer has been shown. It
  /// does not report success: from here on it is the OS asking the viewer to
  /// confirm, and whether they do is not something this app is told.
  Future<String?> download(AppRelease release) async {
    final source = release.apk;
    if (source == null) return 'That release has nothing to install.';

    try {
      if (!await _channel.invokeMethod<bool>('canInstall').then((v) => v ?? false)) {
        // Asked for before the download rather than after: a viewer who is
        // going to decline should not first wait for ninety megabytes.
        await _channel.invokeMethod<bool>('requestPermission');
        final granted =
            await _channel.invokeMethod<bool>('canInstall') ?? false;
        if (!granted) {
          return 'This device has not been allowed to install apps from '
              'OpenTV. Turn that on and try again.';
        }
      }

      progress.value = 0;
      // The app's own files directory, which is what the manifest's
      // FileProvider is pointed at — a provider covering the whole of it
      // would hand out the catalogue along with the build.
      final directory = Directory('${await host.dataDirectory()}/updates');
      await directory.create(recursive: true);

      // Named for the version, and the directory emptied first. A failed
      // download leaves a part-written file, and installing one of those
      // fails in a way that reads as a corrupt release.
      for (final stale in directory.listSync()) {
        await stale.delete(recursive: true);
      }
      final file = File('${directory.path}/OpenTV-${release.version}.apk');

      final request = await HttpClient().getUrl(source);
      final response = await request.close();
      if (response.statusCode != 200) {
        progress.value = null;
        return 'The download answered HTTP ${response.statusCode}.';
      }

      final total = release.sizeBytes ?? response.contentLength;
      final sink = file.openWrite();
      var written = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        written += chunk.length;
        if (total > 0) progress.value = written / total;
      }
      await sink.close();
      progress.value = null;

      await _channel.invokeMethod<bool>('install', {'path': file.path});
      return null;
    } on Object catch (error) {
      progress.value = null;
      return '$error';
    }
  }
}

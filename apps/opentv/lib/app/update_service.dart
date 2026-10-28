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
  UpdateService({
    Transport? transport,
    this.host = const Host(),
    this.db,
    this.interval = const Duration(hours: 6),
  }) : _feed = ReleaseFeed(
          owner: _owner,
          repository: _repository,
          transport: transport ?? HttpTransport(),
        );

  static const _channel = MethodChannel('opentv/update');

  final ReleaseFeed _feed;
  final Host host;

  /// Where the throttle and the declined version are kept.
  ///
  /// Preferences rather than the keystore — neither is a secret — and
  /// deliberately **not** in the synced safelist. Each device updates itself,
  /// so declining 1.2.5 on the phone has nothing to say to the television,
  /// and a check made here is not a check made there.
  ///
  /// Assignable because the app has an update service before it has a
  /// database — the launch check can run while the catalogue is still being
  /// opened, and a check with nowhere to write its throttle simply always
  /// asks, which is the safe way round.
  OpenTvDatabase? db;

  /// How long a check is good for.
  ///
  /// Asked on launch and on waking, which on a television that is only ever
  /// slept and woken could otherwise be several times an hour. Six hours is
  /// far more often than this project publishes and far less often than a box
  /// gets turned on.
  final Duration interval;

  static const _lastCheckedKey = 'update.last-checked';
  static const _declinedKey = 'update.declined';

  /// Whether the offer has already been put in front of somebody this run.
  ///
  /// A home screen rebuilds for reasons that have nothing to do with this —
  /// switching provider, returning from the player — and a prompt that
  /// reappeared on each of them would be the worst thing in the app.
  bool promptShown = false;

  /// The newest build, once a check has found one. Read by About.
  ///
  /// Set even for a version somebody has declined: they said not now, which
  /// is not the same as never, and the panel they would go to on changing
  /// their mind has to have something to show.
  final available = ValueNotifier<AppRelease?>(null);

  /// The newest build somebody has not already said no to.
  ///
  /// This is what a home screen offers unprompted. Null where there is no
  /// update, and null once declined — which is the whole difference between
  /// telling somebody once and nagging them.
  final prompt = ValueNotifier<AppRelease?>(null);

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
  /// [throttle] is for the one caller that happens often.
  ///
  /// Waking is the only one: a television is slept and woken many times a
  /// day, and asking on each would be a request every time somebody picked up
  /// the remote. A launch is a deliberate act and a rare one, and the button
  /// in About is somebody saying *now* — both ask regardless.
  ///
  /// It was the other way round, and that is what a viewer saw: installing a
  /// build runs a check, so the launch straight afterwards was inside the
  /// interval and never asked. The release published minutes later was
  /// invisible for six hours, on the one launch most likely to be looking
  /// for it.
  Future<AppRelease?> check({bool throttle = false}) async {
    try {
      if (!await isOffered()) return null;
      if (throttle && !await _due()) return available.value;

      final release = await _feed.fetch();
      // Only a check that reached the feed counts. Recording one that failed
      // would let a device that launched with no network stay silent for the
      // whole interval after the network came back.
      if (release == null) return null;
      await _note(_lastCheckedKey, DateTime.now().toUtc().toIso8601String());
      if (!ReleaseFeed.isNewer(release.version, appVersion)) return null;
      // A release with no installable file is a tag, not an update.
      if (release.apk == null) return null;

      available.value = release;
      // Offered unprompted only if this is not the one they waved away.
      final declined = await _read(_declinedKey);
      if (declined != release.version) prompt.value = release;
      return release;
    } on Object catch (error) {
      problem.value = '$error';
      return null;
    }
  }

  /// Not now, and not again for this version.
  ///
  /// Remembered rather than held in memory: an app that asked again on the
  /// next launch would be asking every launch, which is how somebody learns
  /// to dismiss a message without reading it.
  Future<void> decline(AppRelease release) async {
    prompt.value = null;
    promptShown = true;
    await _note(_declinedKey, release.version);
  }

  /// Whether enough time has passed to ask again.
  ///
  /// A device with no database to remember in is simply always due, which is
  /// the safe way round — asking too often costs one request.
  Future<bool> _due() async {
    final last = await _read(_lastCheckedKey);
    if (last == null) return true;
    final at = DateTime.tryParse(last);
    if (at == null) return true;
    return DateTime.now().toUtc().difference(at) >= interval;
  }

  Future<String?> _read(String key) async {
    try {
      return await db?.preference(key);
    } on Object {
      return null;
    }
  }

  Future<void> _note(String key, String value) async {
    try {
      await db?.setPreference(key, value);
    } on Object {
      // A throttle that cannot be written is a throttle that does not apply.
      // Not a reason to fail a check.
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

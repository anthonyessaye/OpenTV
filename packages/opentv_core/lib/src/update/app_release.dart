import '../sync/transport.dart';
import '../xtream/coerce.dart';

/// A release of this app, as the place it is published describes it.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    this.notes,
    this.apk,
    this.sizeBytes,
  });

  /// The version with no `v` in front — what [isNewer] compares.
  final String version;
  final String tag;
  final String? notes;

  /// Where the installable file is, if the release has one.
  ///
  /// A release with notes and no APK is a real thing — a tag cut before the
  /// build was attached — and it is not an update, because there is nothing
  /// to install. The caller checks this rather than assuming.
  final Uri? apk;
  final int? sizeBytes;
}

/// Reading GitHub's releases, and deciding whether one is newer.
///
/// In core, where it can be exercised against a fake, because the part that
/// goes wrong is not the HTTP — it is the comparison. `1.2.10` is newer than
/// `1.2.9` and sorts before it as text, which is the bug every hand-written
/// version check has.
class ReleaseFeed {
  const ReleaseFeed({
    required this.owner,
    required this.repository,
    this.transport,
  });

  final String owner;
  final String repository;
  final Transport? transport;

  Uri get latest => Uri.https(
        'api.github.com',
        '/repos/$owner/$repository/releases/latest',
      );

  /// The newest published release, or null where that cannot be answered.
  ///
  /// Never throws. An update check is a convenience, and a convenience that
  /// can stop an app opening is worse than not having it — the same rule a
  /// sync pass and a recovery record both follow.
  Future<AppRelease?> fetch() async {
    final client = transport;
    if (client == null) return null;
    try {
      return parse(await client.getJson(
        latest,
        // GitHub answers HTML to a client that asks for nothing.
        headers: const {'Accept': 'application/vnd.github+json'},
      ));
    } on Object {
      return null;
    }
  }

  /// What a release payload says, or null if it says nothing usable.
  static AppRelease? parse(Object? json) {
    final map = Coerce.asMap(json);
    if (map == null) return null;
    if (Coerce.asBool(map['draft']) == true) return null;
    // A prerelease is published and deliberately not for everybody.
    if (Coerce.asBool(map['prerelease']) == true) return null;

    final tag = Coerce.asString(map['tag_name'])?.trim();
    if (tag == null || tag.isEmpty) return null;

    Uri? apk;
    int? size;
    final assets = map['assets'];
    if (assets is List) {
      for (final entry in assets) {
        final asset = Coerce.asMap(entry);
        if (asset == null) continue;
        final name = Coerce.asString(asset['name'])?.toLowerCase() ?? '';
        if (!name.endsWith('.apk')) continue;
        final url = Coerce.asString(asset['browser_download_url']);
        if (url == null) continue;
        apk = Uri.tryParse(url);
        size = Coerce.asInt(asset['size']);
        break;
      }
    }

    return AppRelease(
      version: normalise(tag),
      tag: tag,
      notes: Coerce.asString(map['body'])?.trim(),
      apk: apk,
      sizeBytes: size,
    );
  }

  /// `v1.2.3` and `1.2.3` are the same version.
  static String normalise(String tag) {
    final trimmed = tag.trim();
    return trimmed.startsWith('v') || trimmed.startsWith('V')
        ? trimmed.substring(1)
        : trimmed;
  }

  /// Whether [candidate] is a later version than [current].
  ///
  /// Compared component by component as numbers. As text `1.2.10` sorts
  /// before `1.2.9`, which is the bug every hand-written version check has
  /// and the reason this is here rather than at a call site.
  ///
  /// A component that is not a number stops the comparison and answers false:
  /// an unreadable version is not grounds for telling somebody to update.
  static bool isNewer(String candidate, String current) {
    final a = _parts(normalise(candidate));
    final b = _parts(normalise(current));
    if (a == null || b == null) return false;

    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  static List<int>? _parts(String version) {
    // Anything after a dash is a prerelease marker, which this does not rank.
    final core = version.split('-').first.split('+').first;
    final parts = <int>[];
    for (final piece in core.split('.')) {
      final value = int.tryParse(piece.trim());
      if (value == null) return null;
      parts.add(value);
    }
    return parts.isEmpty ? null : parts;
  }
}

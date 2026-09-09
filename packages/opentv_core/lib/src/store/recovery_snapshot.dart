import 'dart:convert';

/// Everything about a setup that cannot be fetched again.
///
/// tvOS gives an app about half a megabyte of storage it will not reclaim,
/// and the catalogue is two hundred megabytes — so the catalogue lives in
/// `Library/Caches` and the system is entitled to delete it whenever it wants
/// the space. That is the right place for it: a catalogue is a copy of the
/// provider's listing and one sync rebuilds it.
///
/// Three kinds of thing survive a purge differently. Secrets are in the
/// keystore, which is not purged. Watch history is in the viewer's own backup
/// folder, which is not on the device at all. What was left is this: which
/// portal, which account, and which bucket — a few hundred bytes that are not
/// secret, cannot be derived, and were sitting in the one file the system is
/// allowed to throw away. Without them a purged device holds a keystore full
/// of passwords and no idea what they are for, and cannot even find the
/// folder its history is in.
///
/// So it goes in the keystore beside the secrets. Not because it is one — the
/// address and account name are not — but because that is the only durable
/// store the platform offers.
class RecoverySnapshot {
  const RecoverySnapshot({this.sources = const [], this.backup});

  final List<RecoveredSource> sources;

  /// Where the backup folder is. Null when none is set up.
  final RecoveredBackup? backup;

  bool get isEmpty => sources.isEmpty && backup == null;

  String encode() => jsonEncode({
        'version': 1,
        'sources': [for (final source in sources) source.toJson()],
        if (backup case final held?) 'backup': held.toJson(),
      });

  /// Reads a record back, or an empty one from anything unreadable.
  ///
  /// A record that cannot be parsed must not stop the app: the worst it can
  /// mean is that a viewer sets their provider up again, which is exactly
  /// what happens without it.
  static RecoverySnapshot decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RecoverySnapshot();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const RecoverySnapshot();
      final backup = json['backup'];
      return RecoverySnapshot(
        sources: [
          for (final entry in (json['sources'] as List? ?? const []))
            if (entry is Map) RecoveredSource.fromJson(entry.cast()),
        ],
        backup: backup is Map ? RecoveredBackup.fromJson(backup.cast()) : null,
      );
    } on Object {
      return const RecoverySnapshot();
    }
  }
}

/// One provider, in the terms needed to add it back.
class RecoveredSource {
  const RecoveredSource({
    required this.name,
    required this.kind,
    required this.url,
    this.username,
    this.credentialRef,
    this.epgUrl,
  });

  final String name;

  /// `xtream` or `m3u`, as the enum names them. A string rather than the enum
  /// so a record written by a newer build is skipped rather than fatal.
  final String kind;

  final String url;
  final String? username;

  /// The keystore handle for the password. Not the password: that is already
  /// in the keystore and survives on its own. Without the handle, though, it
  /// is a secret nothing knows the purpose of.
  final String? credentialRef;

  final String? epgUrl;

  Map<String, Object?> toJson() => {
        'name': name,
        'kind': kind,
        'url': url,
        if (username != null) 'username': username,
        if (credentialRef != null) 'credentialRef': credentialRef,
        if (epgUrl != null) 'epgUrl': epgUrl,
      };

  static RecoveredSource fromJson(Map<String, Object?> json) => RecoveredSource(
        name: json['name'] as String? ?? 'Provider',
        kind: json['kind'] as String? ?? 'xtream',
        url: json['url'] as String? ?? '',
        username: json['username'] as String?,
        credentialRef: json['credentialRef'] as String?,
        epgUrl: json['epgUrl'] as String?,
      );
}

/// Where the shared folder is. The keys themselves are already in the
/// keystore under their own references.
class RecoveredBackup {
  const RecoveredBackup({
    required this.endpoint,
    required this.bucket,
    this.region,
  });

  final String endpoint;
  final String bucket;
  final String? region;

  Map<String, Object?> toJson() => {
        'endpoint': endpoint,
        'bucket': bucket,
        if (region != null && region!.isNotEmpty) 'region': region,
      };

  static RecoveredBackup fromJson(Map<String, Object?> json) =>
      RecoveredBackup(
        endpoint: json['endpoint'] as String? ?? '',
        bucket: json['bucket'] as String? ?? '',
        region: json['region'] as String?,
      );
}

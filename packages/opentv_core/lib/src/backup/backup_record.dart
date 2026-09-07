import 'dart:convert';

/// One fact about one thing, and when this device came to believe it.
///
/// State rather than events. A playback position is superseded the moment it
/// changes, so keeping the history of every position would grow without limit
/// to answer a question nobody asks. Keeping only the latest per item makes
/// the log compactable by construction: a snapshot is just the merge of
/// everything so far.
class BackupRecord {
  const BackupRecord({
    required this.scope,
    required this.key,
    required this.value,
    required this.stamp,
  });

  /// Which kind of fact — `playback`, `favourite`, `hidden`, `preference`.
  ///
  /// Kept as a string rather than an enum on the wire. A device on an older
  /// build will meet scopes it has never heard of, and the only safe thing it
  /// can do is carry them through untouched rather than fail to parse the
  /// chunk they arrived in.
  final String scope;

  /// What the fact is about, already in terms both devices share.
  ///
  /// For playback that is `<providerKey>/<kind>/<remoteId>` — never a
  /// `sourceId`, which means nothing off this device.
  final String key;

  /// The fact, or null where the fact is that it is gone.
  ///
  /// A removal has to be a record rather than an absence. A favourite deleted
  /// on the phone would otherwise be re-added by the next device that still
  /// remembers it, for ever.
  final Map<String, Object?>? value;

  final BackupStamp stamp;

  Map<String, Object?> toJson() => {
        'scope': scope,
        'key': key,
        if (value != null) 'value': value,
        'at': stamp.wallClock.toUtc().toIso8601String(),
        'by': stamp.deviceId,
      };

  static BackupRecord fromJson(Map<String, Object?> json) => BackupRecord(
        scope: json['scope']! as String,
        key: json['key']! as String,
        value: (json['value'] as Map?)?.cast<String, Object?>(),
        stamp: BackupStamp(
          wallClock: DateTime.parse(json['at']! as String),
          deviceId: json['by']! as String,
        ),
      );

  @override
  String toString() => 'BackupRecord($scope/$key @ $stamp)';
}

/// When a record was written, and by which device.
///
/// Wall clock first, because it is the only ordering a person would recognise:
/// if you rewind a film on your phone, the newer, *lower* position must win,
/// and a counter that only ever increases cannot express that.
///
/// The device id breaks ties, so two devices that wrote in the same
/// millisecond still agree on which one won. Arbitrary, but identical
/// everywhere, which is the property that matters — a merge that ordered
/// differently on two devices would never converge.
class BackupStamp implements Comparable<BackupStamp> {
  const BackupStamp({required this.wallClock, required this.deviceId});

  final DateTime wallClock;
  final String deviceId;

  @override
  int compareTo(BackupStamp other) {
    final byTime = wallClock.compareTo(other.wallClock);
    return byTime != 0 ? byTime : deviceId.compareTo(other.deviceId);
  }

  @override
  String toString() => '${wallClock.toIso8601String()} by $deviceId';
}

/// Everything one device wrote in one go.
///
/// A version in the clear ahead of the sealed body, because unlike the
/// handover — where both devices are live and one can refuse out loud — a
/// backup is read by whatever build happens to open it, months later, with
/// nobody watching. It has to be able to say "I cannot read this" before
/// trying to decrypt it.
class BackupChunk {
  const BackupChunk({required this.records, this.version = currentVersion});

  final List<BackupRecord> records;
  final int version;

  /// What this build writes.
  static const currentVersion = 1;

  /// The oldest version this build can still read.
  ///
  /// Separate from [currentVersion] on purpose: fields may be added freely
  /// and ignored by readers that do not know them, and only a change that
  /// genuinely cannot be read should move this.
  static const minimumReadable = 1;

  List<int> encode() => utf8.encode(jsonEncode({
        'v': version,
        'records': [for (final record in records) record.toJson()],
      }));

  static BackupChunk decode(List<int> bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    final version = (json['v'] as int?) ?? 0;
    if (version < minimumReadable) {
      throw BackupFormatException(
        'this backup was written by a version of OpenTV too old to read '
        '(format $version, this build reads $minimumReadable and above)',
      );
    }
    return BackupChunk(
      version: version,
      records: [
        for (final record in (json['records']! as List))
          // Unknown scopes and unknown fields are carried rather than
          // rejected. A device that refuses a whole chunk because one record
          // mentions something it has not heard of would stop syncing the
          // moment any other device updated.
          BackupRecord.fromJson((record as Map).cast<String, Object?>()),
      ],
    );
  }
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What is waiting to reach the other devices, and how far the queue was read.
///
/// The two travel together because clearing the queue is only safe once the
/// records are written. Returning the records alone would invite a caller to
/// drain and forget in one step, and lose a viewer's changes to a failed
/// upload.
class BackupOutbox {
  const BackupOutbox({required this.records, required this.through});

  final List<BackupRecord> records;

  /// The stamp of the last entry read, or null when there was nothing.
  final DateTime? through;

  bool get isEmpty => records.isEmpty;
}

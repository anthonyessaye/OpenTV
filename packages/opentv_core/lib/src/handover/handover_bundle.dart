import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One provider's secrets, travelling beside the row that references them.
///
/// This class is the reason the handover is not a file copy. The database has
/// never held a password — `Sources.credentialRef` is a handle into the
/// platform keystore and the secret has always lived there — so a SQLite file
/// arriving on a second device describes a complete catalogue in which every
/// provider points at a keystore entry that does not exist. It would sync, it
/// would show, and not one stream would play.
class HandoverSecret {
  const HandoverSecret({required this.reference, required this.secret});

  /// The value in `Sources.credentialRef`, unchanged.
  final String reference;

  final String secret;

  Map<String, Object?> toJson() => {'reference': reference, 'secret': secret};

  static HandoverSecret fromJson(Map<String, Object?> json) => HandoverSecret(
        reference: json['reference']! as String,
        secret: json['secret']! as String,
      );

  /// Redacted, because these end up in logs and crash reports.
  ///
  /// The same rule `SetupSubmission` follows, for the same reason: an object
  /// that prints its own contents will eventually print them somewhere it
  /// should not, and the reference alone is enough to debug with.
  @override
  String toString() => 'HandoverSecret($reference, •••)';
}

/// What one device is about to hand the other.
class HandoverManifest {
  const HandoverManifest({
    required this.schemaVersion,
    required this.appVersion,
    required this.databaseBytes,
    required this.sourceCount,
    required this.secretCount,
    required this.createdAt,
  });

  /// Checked before a byte of payload moves.
  ///
  /// Two devices on different versions of the app is the ordinary case rather
  /// than the exception — one updates overnight and the other does not — and
  /// a v3 database opened by a v4 app is a migration, while a v4 database
  /// opened by a v3 app is a corrupt store with no way back.
  final int schemaVersion;

  final String appVersion;
  final int databaseBytes;
  final int sourceCount;
  final int secretCount;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'databaseBytes': databaseBytes,
        'sourceCount': sourceCount,
        'secretCount': secretCount,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  static HandoverManifest fromJson(Map<String, Object?> json) =>
      HandoverManifest(
        schemaVersion: json['schemaVersion']! as int,
        appVersion: json['appVersion']! as String,
        databaseBytes: json['databaseBytes']! as int,
        sourceCount: json['sourceCount']! as int,
        secretCount: json['secretCount']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String),
      );
}

/// Why a bundle was refused.
enum HandoverRefusal {
  /// The two devices disagree about the database schema.
  schemaMismatch,

  /// The bundle did not decrypt, which means the key is wrong or the bytes
  /// were altered in flight. AES-GCM cannot tell those apart and neither can
  /// this — both mean the same thing to the viewer: do not trust it.
  notAuthentic,

  /// Structurally not a bundle.
  malformed,
}

class HandoverException implements Exception {
  const HandoverException(this.refusal, this.message);

  final HandoverRefusal refusal;
  final String message;

  @override
  String toString() => 'HandoverException(${refusal.name}: $message)';
}

/// The database and the secrets that make it usable, as one object.
///
/// Serialised with the manifest first and in the clear, so a receiver can
/// refuse a schema it cannot open without ever decrypting the payload — and
/// therefore without the sender having proven anything about who it is
/// talking to. Refusing early is worth more than refusing privately here: the
/// alternative is decrypting a hundred megabytes to discover the version is
/// wrong.
class HandoverBundle {
  const HandoverBundle({
    required this.manifest,
    required this.database,
    required this.secrets,
    this.databaseFile,
  });

  /// Where the catalogue is on disk, when it is.
  ///
  /// Set by [fromFile], so the server can read it a chunk at a time rather
  /// than from [database] — which is what let a 64MB catalogue peak at 464MB
  /// of resident memory and put a television box out of heap.
  final File? databaseFile;

  final HandoverManifest manifest;

  /// The raw SQLite file.
  final Uint8List database;

  final List<HandoverSecret> secrets;

  /// Builds a bundle from a database file on disk.
  static Future<HandoverBundle> fromFile(
    File database, {
    required int schemaVersion,
    required String appVersion,
    required List<HandoverSecret> secrets,
    required int sourceCount,
    DateTime? now,
  }) async {
    final length = await database.length();
    return HandoverBundle(
      databaseFile: database,
      manifest: HandoverManifest(
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        databaseBytes: length,
        sourceCount: sourceCount,
        secretCount: secrets.length,
        createdAt: now ?? DateTime.now(),
      ),
      // Empty: the file is the source, and reading it here is exactly the
      // allocation this avoids.
      database: Uint8List(0),
      secrets: secrets,
    );
  }

  /// The part that is encrypted: everything that is not the manifest.
  Uint8List payload() {
    final secretsJson = utf8.encode(
      jsonEncode([for (final s in secrets) s.toJson()]),
    );
    // Length-prefixed rather than delimited. The database is arbitrary binary
    // and will contain any delimiter that could be chosen for it.
    final out = BytesBuilder(copy: false)
      ..add(_uint32(secretsJson.length))
      ..add(secretsJson)
      ..add(_uint32(database.length))
      ..add(database);
    return out.toBytes();
  }

  /// Rebuilds a bundle from a manifest and its decrypted payload.
  static HandoverBundle fromPayload(
    HandoverManifest manifest,
    Uint8List payload,
  ) {
    var offset = 0;

    int readLength() {
      if (offset + 4 > payload.length) {
        throw const HandoverException(
          HandoverRefusal.malformed,
          'the payload ended in the middle of a length',
        );
      }
      final value = ByteData.sublistView(payload, offset, offset + 4)
          .getUint32(0, Endian.big);
      offset += 4;
      return value;
    }

    Uint8List readBytes(int length) {
      if (offset + length > payload.length) {
        throw const HandoverException(
          HandoverRefusal.malformed,
          'the payload ended in the middle of a section',
        );
      }
      final view = Uint8List.sublistView(payload, offset, offset + length);
      offset += length;
      return view;
    }

    final secretsJson = readBytes(readLength());
    final database = readBytes(readLength());

    late final List<Object?> raw;
    try {
      raw = jsonDecode(utf8.decode(secretsJson)) as List<Object?>;
    } on Object {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the secrets section is not the list it claims to be',
      );
    }

    // Checked against what the manifest promised. The manifest crosses in the
    // clear and the payload does not, so a mismatch means the two halves do
    // not describe the same thing — and the half that was not authenticated
    // is the one that gets believed if nobody looks.
    if (database.length != manifest.databaseBytes) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the database is not the size the manifest promised',
      );
    }
    if (raw.length != manifest.secretCount) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'the secret count does not match the manifest',
      );
    }

    return HandoverBundle(
      manifest: manifest,
      database: database,
      secrets: [
        for (final entry in raw)
          HandoverSecret.fromJson(entry! as Map<String, Object?>),
      ],
    );
  }

  static Uint8List _uint32(int value) {
    final out = ByteData(4)..setUint32(0, value, Endian.big);
    return out.buffer.asUint8List();
  }

  /// Never prints its secrets, for the same reason [HandoverSecret] does not.
  @override
  String toString() =>
      'HandoverBundle(schema ${manifest.schemaVersion}, '
      '${manifest.databaseBytes} bytes, ${secrets.length} secrets)';
}

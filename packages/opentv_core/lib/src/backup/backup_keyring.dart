import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../handover/handover_transfer.dart';
import 'backup_store.dart';

/// How two devices come to hold the same key without ever meeting.
///
/// The first design had the key travel by QR, which quietly put back the
/// constraint the whole feature exists to remove: both devices in the same
/// room. Someone who sets up their television in the living room and their
/// phone on the train would have had two devices writing a shared folder that
/// neither could read — and the only symptom would be a sync that never
/// carried anything.
///
/// So the key is not transported. A random **data key** is generated once and
/// stored in the folder itself, wrapped under a key derived from a passphrase
/// the viewer holds. Any device with the passphrase unwraps the same data key
/// and can read everything ever written.
///
/// The indirection earns its place three times over: the passphrase can be
/// changed without re-encrypting a single chunk, the QR handover can carry
/// the data key directly for devices that *are* in the same room, and both
/// routes arrive at the same key — so a household can use either, or both,
/// and every device still interoperates.
///
/// What the storage service sees is the wrapped blob and a salt. It never
/// sees the passphrase, so it cannot derive the key, which is the entire
/// point of encrypting at all — the threat here is the company holding the
/// files, not somebody who has the account credentials.
class BackupKeyring {
  const BackupKeyring({this.cipher = const HandoverCipher()});

  final HandoverCipher cipher;

  /// Where wrapped keys live, in the clear, at the root of the folder.
  ///
  /// A folder rather than a file, and one candidate per device, because a
  /// plain file store has no compare-and-swap. Two devices set up minutes
  /// apart both find nothing and both write — and with a single file the
  /// second read its own write back before the first overwrote it, so the two
  /// walked away with different keys and could never read each other. That
  /// is not a hypothetical: it is what the first version of this did, and
  /// what the test below caught.
  ///
  /// With one file each, nobody overwrites anybody, and the winner is chosen
  /// by a rule every device computes the same way.
  static const prefix = 'keyring/';

  /// Which candidate wins when a race left more than one.
  ///
  /// The lowest path, which is arbitrary and, more importantly, identical
  /// everywhere. A device only ever writes a candidate when it finds none, so
  /// the set cannot grow once a folder is in use — a device joining later
  /// adopts what is there rather than adding to it, and the winner never
  /// changes underneath chunks that were sealed with it.
  static String elect(List<String> candidates) =>
      (candidates.toList()..sort()).first;

  /// Deliberately not derived from the storage credentials.
  ///
  /// It would be tempting: both devices already type the same access key and
  /// secret, so a key derived from those needs no passphrase at all. But
  /// Backblaze issued that secret and therefore knows it, and a key they can
  /// derive is a key they can read the folder with. The one party the
  /// encryption exists to exclude would have been handed it.
  static const iterations = 120000;

  /// The data key for this folder, creating one if the folder is new.
  ///
  /// The same passphrase always arrives at the same key, on any device, with
  /// no exchange between them.
  Future<Uint8List> unlock({
    required BackupStore store,
    required String deviceId,
    required String passphrase,
    Random? random,
  }) async {
    final existing = await store.list(prefix);
    if (existing.isNotEmpty) {
      return _unwrap(await _read(store, elect(existing)), passphrase);
    }

    final source = random ?? Random.secure();
    final salt = List<int>.generate(16, (_) => source.nextInt(256));
    final dataKey = Uint8List.fromList(
      List<int>.generate(32, (_) => source.nextInt(256)),
    );

    await store.put(
      '$prefix$deviceId.json',
      Uint8List.fromList(utf8.encode(jsonEncode({
        'v': 1,
        'salt': base64.encode(salt),
        'iterations': iterations,
        'wrapped': base64.encode(
          await cipher.sealWith(dataKey, await _derive(passphrase, salt)),
        ),
      }))),
    );

    // Listed again rather than assumed. If another device wrote at the same
    // moment there are now two candidates, and this device adopts whichever
    // the rule elects — it has written no chunks yet, so it loses nothing by
    // changing its mind, and afterwards the two agree for ever.
    final settled = await store.list(prefix);
    if (settled.isEmpty) {
      throw const BackupKeyringException(
        'the keyring could not be written to the backup folder',
      );
    }
    return _unwrap(await _read(store, elect(settled)), passphrase);
  }

  Future<Map<String, Object?>> _read(BackupStore store, String at) async {
    final bytes = await store.get(at);
    if (bytes == null) {
      throw const BackupKeyringException(
        'the keyring in this folder went missing while it was being read',
      );
    }
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } on Object {
      throw const BackupKeyringException(
        'the keyring in this folder could not be read. If something else is '
        'writing to it, choose a folder of its own.',
      );
    }
  }

  Future<Uint8List> _unwrap(
    Map<String, Object?> keyring,
    String passphrase,
  ) async {
    final version = (keyring['v'] as int?) ?? 0;
    if (version > 1) {
      throw const BackupKeyringException(
        'this folder was set up by a newer version of OpenTV. Update this '
        'device before syncing with it.',
      );
    }

    final salt = base64.decode(keyring['salt']! as String);
    // Read from the file rather than assumed, so the cost can be raised for
    // new folders later without stranding every folder made before it.
    final rounds = (keyring['iterations'] as int?) ?? iterations;
    final wrapping = await _derive(passphrase, salt, rounds: rounds);

    try {
      return await cipher.openWith(
        Uint8List.fromList(base64.decode(keyring['wrapped']! as String)),
        wrapping,
      );
    } on Object {
      // A wrong passphrase and an altered file fail identically here, which
      // is correct rather than vague: GCM cannot tell them apart, and neither
      // is a case where the key should be trusted. Said in the words of the
      // thing the viewer actually did.
      throw const BackupKeyringException(
        'that recovery phrase does not match the one this backup folder was '
        'set up with. Use the same phrase on every device, or start a new '
        'folder.',
      );
    }
  }

  Future<Uint8List> _derive(
    String passphrase,
    List<int> salt, {
    int rounds = iterations,
  }) async {
    // Slow on purpose, and slow enough to be felt on a television — which is
    // why it happens once and the result is kept in the keystore rather than
    // derived on every launch.
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    );
    final derived = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase.trim())),
      nonce: salt,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }
}

/// A phrase to write down, rather than one to think up.
///
/// Generated rather than chosen because a chosen one is either weak or
/// forgotten, and this is the only thing standing between a stranger with the
/// bucket credentials and a record of what somebody watches.
///
/// Grouped in fours and drawn from an alphabet with no `0`, `O`, `1`, `I` or
/// `l` in it, because this gets read off a television across a room and typed
/// into a phone.
String newBackupPhrase([Random? random]) {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final source = random ?? Random.secure();
  final groups = [
    for (var group = 0; group < 5; group++)
      [
        for (var i = 0; i < 4; i++) alphabet[source.nextInt(alphabet.length)],
      ].join(),
  ];
  return groups.join('-');
}

class BackupKeyringException implements Exception {
  const BackupKeyringException(this.message);

  final String message;

  @override
  String toString() => message;
}

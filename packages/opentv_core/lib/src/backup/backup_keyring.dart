import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../handover/handover_transfer.dart';
import 'backup_store.dart';

/// One way of getting at the data key.
///
/// The [id] names the route and travels in the clear; the [secret] never
/// leaves the device. Two devices offering the same id must offer the same
/// secret, or one of them has the wrong credentials for this folder — which
/// is exactly what the provider slot is there to notice.
class BackupSecret {
  const BackupSecret({required this.id, required this.secret});

  /// The recovery phrase route, which every folder has.
  static const phraseId = 'phrase';

  /// The route a provider's own credentials open.
  ///
  /// Named by [providerKey] rather than by the address, so a filename in
  /// somebody else's bucket does not spell out which portal is being watched.
  static String providerId(String providerKey) => 'provider:$providerKey';

  final String id;
  final String secret;

  /// Redacted, because these reach crash reports.
  @override
  String toString() => 'BackupSecret($id)';
}

/// How two devices come to hold the same key without ever meeting.
///
/// The key is not transported. A random **data key** is generated once and
/// left in the folder, wrapped separately under every secret that should be
/// able to open it. Any device holding any one of those secrets arrives at
/// the same data key and can read everything ever written.
///
/// Several wrappings rather than one, because the two things a viewer might
/// have fail in opposite ways. Provider credentials are already on both
/// devices and need no typing at all — but portals reissue passwords on
/// renewal, and a key that *was* the password would take every chunk ever
/// written with it, silently, on the day a subscription renewed. A recovery
/// phrase never rotates but has to be carried by hand. Wrapping the same key
/// under both means neither failure is fatal: credentials change and the
/// phrase still opens the folder, a device arrives with nothing and the
/// phrase gets it in, and everything else unlocks with no setup.
///
/// Deliberately not derived from the *storage* credentials, which would need
/// no phrase at all. Backblaze issued that secret and therefore knows it, and
/// the company holding the files is the one party this encryption exists to
/// exclude. A portal password is different: the only party who can derive it
/// is the provider streaming the films, who knows what is being watched
/// already.
class BackupKeyring {
  const BackupKeyring({this.cipher = const HandoverCipher()});

  final HandoverCipher cipher;

  /// Where a device puts its opening bid at a folder nobody has claimed.
  ///
  /// One file per device, because a plain file store has no compare-and-swap.
  /// Two devices set up minutes apart both find an empty folder and both
  /// write — and with a single file the second read its own write back before
  /// the first overwrote it, so the two walked away with different keys and
  /// could never read each other. That is not hypothetical; it is what the
  /// first version of this did.
  static const prefix = 'keyring/';

  /// Where the ways in live, once the folder has a key.
  ///
  /// Named by the secret's id, so two devices adding the same route write the
  /// same path with different salts and the same data key inside — an
  /// overwrite that cannot lose anything, which is the only kind a store like
  /// this can offer.
  static const slotPrefix = 'keyring/slots/';

  static const iterations = 120000;

  /// Which opening bid wins when a race left more than one.
  ///
  /// The lowest path: arbitrary, and identical on every device, which is the
  /// property that matters.
  static String elect(List<String> candidates) =>
      (candidates.toList()..sort()).first;

  /// The data key for this folder, creating one if nobody has claimed it.
  ///
  /// [secrets] is everything this device can offer. Slots are tried in the
  /// order given, so a caller that puts the provider first gets the unlock
  /// that needs no typing and never reaches the phrase.
  ///
  /// Any secret that did not have a slot gets one, so a device that arrives
  /// with the phrase leaves the folder openable by its provider next time.
  Future<Uint8List> unlock({
    required BackupStore store,
    required String deviceId,
    required List<BackupSecret> secrets,
    Random? random,
  }) async {
    if (secrets.isEmpty) {
      throw const BackupKeyringException(
        'this device has nothing to open the backup folder with',
      );
    }

    // Which routes actually worked, so the rest can be rewritten without
    // deriving every one of them a second time — each derivation is a
    // deliberate hundred and twenty thousand rounds, and on a television that
    // is felt.
    final opened = <String>{};
    final key = await _open(store, secrets, opened) ??
        await _claim(store, deviceId, secrets, random, opened);
    await _fill(store, key, secrets, opened);
    return key;
  }

  /// Tries every slot this device has a secret for, and every opening bid.
  Future<Uint8List?> _open(
    BackupStore store,
    List<BackupSecret> secrets,
    Set<String> opened,
  ) async {
    final slots = await store.list(slotPrefix);
    for (final secret in secrets) {
      final path = '$slotPrefix${_fileSafe(secret.id)}.json';
      if (!slots.contains(path)) continue;
      final key = await _tryOpen(store, path, secret);
      if (key != null) {
        opened.add(secret.id);
        return key;
      }
    }

    // No slot opened. The folder may predate slots, in which case the opening
    // bids still hold the key — and the elected one is the authority, so a
    // losing bid from an old race is never consulted.
    final bids = (await store.list(prefix))
        .where((path) => !path.startsWith(slotPrefix))
        .toList();

    if (bids.isNotEmpty) {
      final elected = elect(bids);
      for (final secret in secrets) {
        final key = await _tryOpen(store, elected, secret);
        if (key != null) {
          opened.add(secret.id);
          return key;
        }
      }
    }

    // Null means *nobody has claimed this folder*, and the caller answers it
    // by claiming it with a new data key. So it may only be returned when
    // there is genuinely nothing here. A folder that plainly exists and did
    // not open is a wrong secret, and answering that by minting a new key
    // would orphan every chunk ever written — silently, and to a viewer it
    // would look like their history had simply gone.
    if (slots.isEmpty && bids.isEmpty) return null;

    throw BackupKeyringException(
      secrets.any((s) => s.id == BackupSecret.phraseId)
          ? 'that recovery phrase does not match the one this backup folder '
              'was set up with. Use the same phrase on every device, or start '
              'a new folder.'
          : 'this provider does not open the backup folder. Enter the '
              'recovery phrase for it, or check the account is the same one.',
    );
  }

  Future<Uint8List?> _tryOpen(
    BackupStore store,
    String path,
    BackupSecret secret,
  ) async {
    final slot = await _read(store, path);
    if (slot == null) return null;
    if (((slot['v'] as int?) ?? 0) > 1) {
      throw const BackupKeyringException(
        'this folder was set up by a newer version of OpenTV. Update this '
        'device before syncing with it.',
      );
    }
    try {
      return await cipher.openWith(
        Uint8List.fromList(base64.decode(slot['wrapped']! as String)),
        await _derive(
          secret.secret,
          base64.decode(slot['salt']! as String),
          rounds: (slot['iterations'] as int?) ?? iterations,
        ),
      );
    } on Object {
      // A wrong secret and an altered file fail identically here. GCM cannot
      // tell them apart, and neither is a case where the key should be
      // trusted, so the caller is told which routes were tried rather than
      // which byte went wrong.
      return null;
    }
  }

  /// Nobody has claimed this folder, so this device does.
  Future<Uint8List> _claim(
    BackupStore store,
    String deviceId,
    List<BackupSecret> secrets,
    Random? random,
    Set<String> opened,
  ) async {
    final source = random ?? Random.secure();
    final dataKey = Uint8List.fromList(
      List<int>.generate(32, (_) => source.nextInt(256)),
    );

    await store.put(
      '$prefix$deviceId.json',
      await _wrap(dataKey, secrets.first, source),
    );

    // Listed again rather than assumed. If another device claimed it in the
    // same moment there are two bids now, and this device adopts whichever
    // the rule elects — it has written no chunks yet, so it loses nothing by
    // changing its mind, and afterwards the two agree for ever.
    final bids = (await store.list(prefix))
        .where((path) => !path.startsWith(slotPrefix))
        .toList();
    if (bids.isEmpty) {
      throw const BackupKeyringException(
        'the keyring could not be written to the backup folder',
      );
    }

    final elected = elect(bids);
    final key = await _tryOpen(store, elected, secrets.first);
    if (key == null) {
      throw const BackupKeyringException(
        'another device claimed this folder with a different secret. Use the '
        'recovery phrase it was set up with.',
      );
    }
    opened.add(secrets.first.id);
    return key;
  }

  /// Gives every secret this device holds a way in, if it has not got one.
  ///
  /// This is what makes the arrangement survive a password change: a device
  /// that got in with the phrase writes a fresh provider slot on its way
  /// past, so the next unlock needs no typing again.
  Future<void> _fill(
    BackupStore store,
    Uint8List dataKey,
    List<BackupSecret> secrets,
    Set<String> opened,
  ) async {
    for (final secret in secrets) {
      // Replaced rather than skipped when one is already there. A slot is
      // named by the route, not by the secret behind it, so after a portal
      // reissues a password the old slot still sits at that path opening
      // nothing — and skipping it means the phrase gets typed again on every
      // renewal, for ever.
      if (opened.contains(secret.id)) continue;
      await store.put(
        '$slotPrefix${_fileSafe(secret.id)}.json',
        await _wrap(dataKey, secret, Random.secure()),
      );
    }
  }

  Future<Uint8List> _wrap(
    Uint8List dataKey,
    BackupSecret secret,
    Random source,
  ) async {
    final salt = List<int>.generate(16, (_) => source.nextInt(256));
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'v': 1,
      'id': secret.id,
      'salt': base64.encode(salt),
      'iterations': iterations,
      'wrapped': base64.encode(
        await cipher.sealWith(dataKey, await _derive(secret.secret, salt)),
      ),
    })));
  }

  /// Writes a way in, replacing whatever was at that route before.
  ///
  /// How a phrase is changed. [unlock] only fills in routes that did not
  /// already open, which is right on an ordinary launch and wrong here: a
  /// viewer changing their phrase is asking for the one that *did* open to be
  /// replaced. Without this there is no way to change it at all, and a phrase
  /// somebody has since written on a whiteboard opens the folder for ever.
  ///
  /// The data key does not change, so nothing already written needs
  /// re-encrypting and every other device carries on unaffected.
  Future<void> rewrap({
    required BackupStore store,
    required Uint8List dataKey,
    required BackupSecret secret,
  }) async {
    await store.put(
      '$slotPrefix${_fileSafe(secret.id)}.json',
      await _wrap(dataKey, secret, Random.secure()),
    );

    // The opening bids go with it, and this is the part that makes changing a
    // phrase mean anything. A bid is sealed under whatever secret first
    // claimed the folder and is never rotated, so leaving it behind means the
    // old phrase still opens the folder through the back door — the change
    // would have been decoration, which is what the test found.
    //
    // Safe to remove because the folder is reachable by slots now, and left
    // until a deliberate act rather than cleared at launch: a device still
    // claiming the folder is reading these, and deleting them underneath it
    // is how two devices end up with different keys.
    for (final bid in await store.list(prefix)) {
      if (bid.startsWith(slotPrefix)) continue;
      await store.delete(bid);
    }
  }

  Future<Map<String, Object?>?> _read(BackupStore store, String at) async {
    final bytes = await store.get(at);
    if (bytes == null) return null;
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    } on Object {
      throw const BackupKeyringException(
        'the keyring in this folder could not be read. If something else is '
        'writing to it, choose a folder of its own.',
      );
    }
  }

  Future<Uint8List> _derive(
    String secret,
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
      secretKey: SecretKey(utf8.encode(secret.trim())),
      nonce: salt,
    );
    return Uint8List.fromList(await derived.extractBytes());
  }

  /// A slot id as a filename.
  ///
  /// Ids carry a colon, which is not a character to put in a path on every
  /// store this might one day speak to.
  static String _fileSafe(String id) => id.replaceAll(':', '_');
}

/// What a provider's credentials contribute to opening the folder.
///
/// The password is in here, which is what makes this secret rather than a
/// name — and it is why a rotation has to be survivable rather than fatal.
/// Built here so both ends derive it identically; a second copy of this
/// spelling would be a second thing to keep in step.
String providerSecretMaterial({
  required String providerKey,
  required String? username,
  required String password,
}) =>
    '$providerKey\n${(username ?? '').trim().toLowerCase()}\n$password';

/// A phrase to write down, rather than one to think up.
///
/// Generated rather than chosen because a chosen one is either weak or
/// forgotten, and with the provider slot doing the everyday unlocking this is
/// only ever needed when something has gone wrong — which is exactly when a
/// half-remembered phrase is worth nothing.
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

/// Why a chosen phrase cannot be used, or null when it is fine.
///
/// A viewer may prefer something they can remember to something they have to
/// write down, and that is a reasonable trade for a record of what they
/// watched. It is a trade, though, and this is where the floor under it
/// lives: the wrapped key sits in a bucket, so anyone who reaches the bucket
/// can attack it offline as fast as their hardware allows. A hundred and
/// twenty thousand rounds buys time against a poor phrase; it does not buy
/// enough.
///
/// Refusals say what to do rather than scoring out of five. A meter that
/// turns green is a meter people satisfy rather than read.
String? backupPhraseProblem(
  String phrase, {
  String? providerPassword,
  String? username,
}) {
  final trimmed = phrase.trim();

  if (trimmed.length < 12) {
    return 'Use at least 12 characters. A few unrelated words are easier to '
        'remember than a short password and far harder to guess.';
  }

  // Long and repetitive is not long. `aaaaaaaaaaaaaa` clears any length rule.
  if (trimmed.split('').toSet().length < 6) {
    return 'Use a few more different characters — this repeats too much to be '
        'worth its length.';
  }

  if (providerPassword != null &&
      providerPassword.isNotEmpty &&
      trimmed == providerPassword.trim()) {
    return 'Choose something other than your provider password. Reusing it '
        'means your provider could open your backup, and changing it with '
        'them would not change this.';
  }

  final account = (username ?? '').trim().toLowerCase();
  if (account.length >= 4 && trimmed.toLowerCase().contains(account)) {
    return 'Leave your account name out of it — anyone who knows which '
        'provider you use would try that first.';
  }

  return null;
}

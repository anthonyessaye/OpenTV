import 'dart:typed_data';

/// Somewhere to put a few kilobytes that the viewer controls.
///
/// Four verbs, because that is all a sync needs and because every service
/// worth supporting has them. The engine above this never learns which one it
/// is talking to, which is what lets the whole of the sync be tested without
/// an account, a network, or a key.
///
/// Deliberately not called cloud storage. What travels is watch state —
/// positions, favourites, what is hidden — and a year of it is smaller than
/// one poster image. Capacity was never the question. The only thing that
/// differs between services is how much friction their authentication costs.
abstract class BackupStore {
  /// Every path beginning [prefix], in no promised order.
  Future<List<String>> list(String prefix);

  /// The bytes at [path], or null where there are none.
  ///
  /// Null rather than a throw: a peer that has never written anything is the
  /// ordinary case on a device that has just joined, not a failure.
  Future<Uint8List?> get(String path);

  /// Writes [bytes] to [path], replacing whatever was there.
  ///
  /// Nothing in this design ever writes another device's file, so an
  /// overwrite is only ever a device rewriting its own. That is what removes
  /// the need for locking, which a plain file store cannot offer anyway.
  Future<void> put(String path, Uint8List bytes);

  Future<void> delete(String path);
}

/// A store held in memory, for tests.
///
/// The engine's whole behaviour — ordering, merging, watermarks, recovery
/// after a gap — is exercised against this. A test that needed an account is
/// a test nobody runs.
class MemoryBackupStore implements BackupStore {
  final Map<String, Uint8List> _files = {};

  /// How many reads have been asked of it, so a test can assert that a second
  /// sync does not fetch what it already has.
  int reads = 0;

  Map<String, Uint8List> get files => Map.unmodifiable(_files);

  @override
  Future<List<String>> list(String prefix) async =>
      _files.keys.where((path) => path.startsWith(prefix)).toList()..sort();

  @override
  Future<Uint8List?> get(String path) async {
    reads++;
    return _files[path];
  }

  @override
  Future<void> put(String path, Uint8List bytes) async => _files[path] = bytes;

  @override
  Future<void> delete(String path) async => _files.remove(path);
}

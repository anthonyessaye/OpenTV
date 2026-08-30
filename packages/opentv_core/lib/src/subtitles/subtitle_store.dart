import 'dart:io';
import 'dart:math';

/// Where a downloaded subtitle lives, which is nowhere for long.
///
/// Temporary on purpose. A fetched subtitle belongs to the sitting it was
/// fetched for: it was chosen because the provider's own tracks were absent
/// or wrong for *this* stream, and a provider that fixes its tracks tomorrow
/// would otherwise be overruled for ever by a file somebody accepted once.
///
/// Keeping them would also mean an index — a row saying which file belongs to
/// which title — and this codebase's most common failure by a distance is a
/// row nothing reads or a file nothing points at. There is no index here
/// because there is nothing to index: the file is written, handed to the
/// player, and deleted.
///
/// Anything left behind is a crash, not a cache. [sweep] clears those at
/// launch, so the directory cannot grow across sittings.
class SubtitleStore {
  SubtitleStore(this.directory, {Random? random})
      : _random = random ?? Random();

  /// A cache directory rather than the app's documents: the operating system
  /// is welcome to reclaim any of this at any time, which is exactly the
  /// lifetime these have.
  final String directory;

  final Random _random;

  Directory get folder => Directory('$directory/subtitles');

  /// Writes one, for the player to load now.
  ///
  /// A fresh name every time. Reusing one would mean the engine reading a
  /// file while it is being overwritten when somebody rejects a subtitle and
  /// picks another — which is the common case, since picking a second is what
  /// happens when the first is out of sync.
  Future<File> write(String contents, {String language = 'sub'}) async {
    await folder.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 20);
    final file = File(
      '${folder.path}/${_sanitise(language)}-$stamp-$salt.srt',
    );
    await file.writeAsString(contents);
    return file;
  }

  /// Deletes one the player has finished with.
  ///
  /// Failure is ignored, deliberately. The file is already unreferenced and
  /// [sweep] will take it on the next launch; throwing here would turn a
  /// tidying step into a visible error at the moment a viewer closes a film.
  Future<void> discard(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Left for the sweep.
    }
  }

  /// Clears anything a previous run left behind, and says how many.
  ///
  /// The player deletes its own file when it closes, so this only ever finds
  /// something after a crash or a kill — which on a television, where the app
  /// is usually ended by pulling the power, is not unusual.
  Future<int> sweep() async {
    if (!folder.existsSync()) return 0;
    var removed = 0;
    await for (final entry in folder.list()) {
      if (entry is! File) continue;
      try {
        await entry.delete();
        removed++;
      } on FileSystemException {
        // Busy or gone. Either way, not worth reporting.
      }
    }
    return removed;
  }

  /// A language code is whatever the service returned, and none of it may
  /// reach a filename.
  static String _sanitise(String value) {
    // Dots excluded as well as separators. They cannot traverse anything once
    // the separators are gone, but a name reading `..-..-etc-passwd.srt` in a
    // directory listing invites exactly one question and it is the wrong one.
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
    if (cleaned.isEmpty) return 'sub';
    return cleaned.length <= 16 ? cleaned : cleaned.substring(0, 16);
  }
}

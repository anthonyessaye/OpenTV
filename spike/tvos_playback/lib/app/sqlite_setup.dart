import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Points drift at a SQLite it can actually load, which differs by platform
/// in the opposite direction to the one most people expect.
///
/// Apple links libsqlite3 into every process, so the symbols are already
/// there and nothing needs bundling. Android does not expose its system
/// SQLite to applications at all — dlopen of it is blocked — so the library
/// has to ship inside the APK, which is what `sqlite3_flutter_libs` is for.
///
/// Returns what it used, so a failure can say which route was taken.
String configureSqlite() {
  if (Platform.isAndroid) {
    open.overrideFor(
      OperatingSystem.android,
      () => DynamicLibrary.open('libsqlite3.so'),
    );
    // Touching the version forces the load now, so a missing library fails
    // here with a clear cause rather than at the first query.
    sqlite.sqlite3.version;
    return 'bundled libsqlite3.so';
  }

  try {
    open.overrideFor(OperatingSystem.iOS, DynamicLibrary.process);
    open.overrideFor(OperatingSystem.macOS, DynamicLibrary.process);
    sqlite.sqlite3.version;
    return 'DynamicLibrary.process()';
  } catch (_) {
    open.overrideFor(
      OperatingSystem.iOS,
      () => DynamicLibrary.open('libsqlite3.dylib'),
    );
    sqlite.sqlite3.version;
    return 'libsqlite3.dylib';
  }
}

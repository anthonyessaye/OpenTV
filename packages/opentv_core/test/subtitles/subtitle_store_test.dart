import 'dart:io';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// A fetched subtitle belongs to the sitting it was fetched for.
void main() {
  late Directory root;
  late SubtitleStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('opentv-subs');
    store = SubtitleStore(root.path);
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('it writes something the player can open', () async {
    final file = await store.write('1\n00:00:01,000 --> 00:00:02,000\nHi\n');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('Hi'));
    expect(file.path, endsWith('.srt'));
  });

  test('a second choice does not overwrite the first while it is open', () async {
    // Picking a second subtitle because the first was out of sync is the
    // common case, and a reused name would have the engine reading a file
    // that is being rewritten underneath it.
    final first = await store.write('one');
    final second = await store.write('two');
    expect(first.path, isNot(second.path));
    expect(first.readAsStringSync(), 'one');
  });

  test('discarding removes it', () async {
    final file = await store.write('x');
    await store.discard(file);
    expect(file.existsSync(), isFalse);
  });

  test('discarding something already gone is not an error', () async {
    // It happens: the sweep runs, then a player closes. Throwing here would
    // turn tidying into a visible failure at the moment somebody leaves a
    // film.
    final file = await store.write('x');
    await file.delete();
    await store.discard(file);
  });

  test('a sweep clears what a crash left behind', () async {
    await store.write('a');
    await store.write('b');
    expect(await store.sweep(), 2);
    expect(store.folder.listSync(), isEmpty);
  });

  test('a sweep on a fresh install finds nothing and says so', () async {
    expect(await store.sweep(), 0);
  });

  test('a language the service invented cannot escape the directory', () async {
    final file = await store.write('x', language: '../../etc/passwd');

    // The property that matters: whatever the service said, the file lands in
    // the subtitles directory and nowhere else.
    expect(file.parent.path, store.folder.path);
    expect(file.uri.pathSegments.last, isNot(contains('/')));
    expect(file.uri.pathSegments.last, isNot(contains('..')));
  });
}

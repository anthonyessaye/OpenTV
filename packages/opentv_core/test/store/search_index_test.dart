import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Search against a catalogue the size of a real provider's.
///
/// Written because the cost of the old query ran the wrong way round: `LIKE
/// '%needle%'` cannot use an index, so a term that matched plenty was fast
/// only because LIMIT stopped the scan early, and a term that matched little
/// read every row to say so. The slowest searches were the ones a viewer
/// runs on purpose — a specific title, typed to the end.
Future<int> _seed(OpenTvDatabase db, {required int films}) async {
  final sourceId = await db.addSource(SourcesCompanion.insert(
    name: 'bench',
    kind: SourceKind.m3u,
    url: 'http://example.invalid/list.m3u',
    createdAt: DateTime.utc(2026),
  ));

  const words = ['shawshank', 'godfather', 'inception', 'parasite', 'arrival',
    'whiplash', 'gladiator', 'interstellar', 'oldboy', 'amelie'];
  final rows = <MoviesCompanion>[];
  for (var i = 0; i < films; i++) {
    final name = '${words[i % words.length]} part $i extended cut';
    rows.add(MoviesCompanion.insert(
      sourceId: sourceId,
      remoteId: 'm$i',
      name: name,
      searchName: normaliseForSearch(name),
    ));
  }
  for (var at = 0; at < rows.length; at += 5000) {
    final end = at + 5000 > rows.length ? rows.length : at + 5000;
    await db.upsertMovies(rows.sublist(at, end));
  }
  return sourceId;
}

void main() {
  late OpenTvDatabase db;

  setUp(() => db = OpenTvDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a term that matches nothing costs no more than one that matches',
      () async {
    final sourceId = await _seed(db, films: 90000);

    Future<int> cost(String term) async {
      await db.searchMovies(sourceId, term, limit: 60);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        await db.searchMovies(sourceId, term, limit: 60);
      }
      return sw.elapsedMicroseconds ~/ 5;
    }

    final hit = await cost('shawshank');
    final miss = await cost('brutalist');

    // The ratio is the assertion, not the absolute time: this runs on
    // whatever machine is to hand. The defect measured twenty-four times a
    // hit; the index measures a tenth of one, because a miss touches nothing
    // while a hit still fetches sixty rows. The constant is slack for a
    // machine where both numbers are small.
    expect(
      miss,
      lessThan(hit * 3 + 2000),
      reason: 'a miss cost ${miss}us against ${hit}us for a hit, which is the '
          'full-scan behaviour the index exists to remove',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('titles in scripts that do not fold to ASCII are findable', () async {
    // These were unfindable, and silently: normaliseForSearch drops every
    // rune it has no ASCII mapping for, so both the stored name and the term
    // typed to look for it reduced to the empty string.
    final sourceId = await _seed(db, films: 0);
    await db.upsertChannels([
      for (final (id, name) in const [
        ('a', 'قناة الجزيرة'),
        ('b', 'Первый канал'),
        ('c', 'Ελληνική Τηλεόραση'),
        ('d', 'Telefé Noticias'),
      ])
        ChannelsCompanion.insert(
          sourceId: sourceId,
          remoteId: id,
          name: name,
          searchName: normaliseForSearch(name),
        ),
    ]);

    Future<List<String>> find(String term) async =>
        [for (final c in await db.searchChannels(sourceId, term)) c.name];

    expect(await find('الجزيرة'), ['قناة الجزيرة']);
    expect(await find('Первый'), ['Первый канал']);
    expect(await find('Ελληνική'), ['Ελληνική Τηλεόραση']);
    // Still folds diacritics for the scripts it always handled.
    expect(await find('telefe'), ['Telefé Noticias']);
  });

  test('a part-typed word matches before it is finished', () async {
    final sourceId = await _seed(db, films: 0);
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'x',
        name: 'The Shawshank Redemption',
        searchName: normaliseForSearch('The Shawshank Redemption'),
      ),
    ]);

    for (final term in ['sh', 'shaw', 'shawshank', 'shawshank red']) {
      expect(
        await db.searchMovies(sourceId, term),
        hasLength(1),
        reason: '"$term" found nothing',
      );
    }
  });

  test('the index follows the catalogue after it is built', () async {
    // The trap in an external-content index: it is built from the table and
    // is not updated by writing to that table, so it would be correct in any
    // test that seeds and searches once and wrong from the next sync on.
    final sourceId = await _seed(db, films: 0);

    Future<int> hits(String term) async =>
        (await db.searchMovies(sourceId, term)).length;

    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'later',
        name: 'Arrival',
        searchName: normaliseForSearch('Arrival'),
      ),
    ]);
    expect(await hits('arrival'), 1, reason: 'an inserted row was not indexed');

    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'later',
        name: 'Departure',
        searchName: normaliseForSearch('Departure'),
      ),
    ]);
    expect(await hits('arrival'), 0, reason: 'a renamed row kept its old name');
    expect(await hits('departure'), 1);

    await db.removeSource(sourceId);
    expect(await hits('departure'), 0, reason: 'a deleted row stayed indexed');
  });

  test('a term of punctuation alone asks nothing of the index', () async {
    final sourceId = await _seed(db, films: 0);
    // FTS5 rejects an empty MATCH outright, so this has to be caught before
    // the query rather than by it.
    expect(await db.searchMovies(sourceId, '***'), isEmpty);
    expect(await db.searchMovies(sourceId, '   '), isEmpty);
  });

  test('hidden rows stay hidden, and other sources stay out', () async {
    final first = await _seed(db, films: 0);
    final second = await db.addSource(SourcesCompanion.insert(
      name: 'other',
      kind: SourceKind.m3u,
      url: 'http://example.invalid/other.m3u',
      createdAt: DateTime.utc(2026),
    ));

    for (final id in [first, second]) {
      await db.upsertMovies([
        MoviesCompanion.insert(
          sourceId: id,
          remoteId: 'shared',
          name: 'Gladiator',
          searchName: normaliseForSearch('Gladiator'),
        ),
      ]);
    }

    expect(await db.searchMovies(first, 'gladiator'), hasLength(1));
    await db.setMovieHidden(first, 'shared', true);
    expect(await db.searchMovies(first, 'gladiator'), isEmpty);
    expect(await db.searchMovies(second, 'gladiator'), hasLength(1));
  });

  test('an existing catalogue gains the index without a resync', () async {
    // The migration path. A device updating to schema 5 has a catalogue that
    // took minutes to sync and must not be asked for it again, so the index
    // is built from the rows already there. Reproduced by taking the index
    // away from a populated database and putting it back.
    final sourceId = await _seed(db, films: 0);
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'old',
        name: 'Gladiator',
        searchName: normaliseForSearch('Gladiator'),
      ),
    ]);

    for (final index in const ['channels_fts', 'movies_fts', 'series_fts']) {
      for (final suffix in const ['insert', 'delete', 'update']) {
        await db.customStatement('DROP TRIGGER ${index}_$suffix');
      }
      await db.customStatement('DROP TABLE $index');
    }

    await db.createSearchIndex();
    expect(await db.searchMovies(sourceId, 'gladiator'), hasLength(1));

    // Run twice on the same database, which is what a handover produces: the
    // file arrives with the index the other device built.
    await db.createSearchIndex();
    expect(await db.searchMovies(sourceId, 'gladiator'), hasLength(1));
  });

  test('search still answers when the index cannot, and says it did not',
      () async {
    // Reproduces a device this machine cannot: whatever the reason the index
    // does not answer, a search box that does nothing is the worst of the
    // available outcomes. The scan is what every earlier release used, so the
    // fallback is slow rather than wrong — and it is recorded, because
    // results look identical either way and an invisible fallback is how a
    // feature quietly stops existing.
    final sourceId = await _seed(db, films: 0);
    await db.upsertMovies([
      MoviesCompanion.insert(
        sourceId: sourceId,
        remoteId: 'g',
        name: 'Gladiator',
        searchName: normaliseForSearch('Gladiator'),
      ),
    ]);

    for (final index in const ['channels_fts', 'movies_fts', 'series_fts']) {
      for (final suffix in const ['insert', 'delete', 'update']) {
        await db.customStatement('DROP TRIGGER ${index}_$suffix');
      }
      await db.customStatement('DROP TABLE $index');
    }

    expect(db.searchIndexFailure, null);
    expect(await db.searchMovies(sourceId, 'gladiator'), hasLength(1));
    expect(
      db.searchIndexFailure,
      contains('movies_fts'),
      reason: 'the fallback ran without recording that it had to',
    );
  });
}

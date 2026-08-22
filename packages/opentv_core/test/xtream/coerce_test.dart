import 'package:opentv_core/src/xtream/coerce.dart';
import 'package:test/test.dart';

void main() {
  group('asString', () {
    test('passes a plain string through, trimmed', () {
      expect(Coerce.asString('  BBC One  '), 'BBC One');
    });

    test('stringifies numbers and booleans', () {
      expect(Coerce.asString(42), '42');
      expect(Coerce.asString(7.5), '7.5');
      expect(Coerce.asString(true), 'true');
    });

    test('treats provider empty markers as absent', () {
      expect(Coerce.asString(null), isNull);
      expect(Coerce.asString(''), isNull);
      expect(Coerce.asString('   '), isNull);
      expect(Coerce.asString('null'), isNull);
      expect(Coerce.asString('NULL'), isNull);
      expect(Coerce.asString('undefined'), isNull);
      expect(Coerce.asString('N/A'), isNull);
    });
  });

  group('asInt', () {
    test('reads an int from either a number or a string', () {
      expect(Coerce.asInt(12345), 12345);
      expect(Coerce.asInt('12345'), 12345);
      expect(Coerce.asInt('  12345  '), 12345);
    });

    test('truncates an id sent as a float', () {
      expect(Coerce.asInt(12345.0), 12345);
      expect(Coerce.asInt('12345.0'), 12345);
      expect(Coerce.asInt(12345.9), 12345);
    });

    test('reads negatives', () {
      expect(Coerce.asInt('-1'), -1);
    });

    test('returns null for empty markers and junk', () {
      expect(Coerce.asInt(null), isNull);
      expect(Coerce.asInt(''), isNull);
      expect(Coerce.asInt('null'), isNull);
      expect(Coerce.asInt('not a number'), isNull);
      expect(Coerce.asInt(double.nan), isNull);
      expect(Coerce.asInt(double.infinity), isNull);
    });
  });

  group('asDouble', () {
    test('reads a rating from a number or a string', () {
      expect(Coerce.asDouble(7.5), 7.5);
      expect(Coerce.asDouble('7.5'), 7.5);
      expect(Coerce.asDouble(8), 8.0);
    });

    test('returns null for empty and non-finite values', () {
      expect(Coerce.asDouble(''), isNull);
      expect(Coerce.asDouble('null'), isNull);
      expect(Coerce.asDouble(double.nan), isNull);
      expect(Coerce.asDouble(double.infinity), isNull);
    });
  });

  group('asBool', () {
    test('reads the shapes providers use for true', () {
      for (final value in <Object>[true, 1, '1', 'true', 'TRUE', 'yes', 2]) {
        expect(Coerce.asBool(value), isTrue, reason: 'for $value');
      }
    });

    test('reads the shapes providers use for false', () {
      for (final value in <Object>[false, 0, '0', 'false', 'FALSE', 'no']) {
        expect(Coerce.asBool(value), isFalse, reason: 'for $value');
      }
    });

    test('returns null when absent or unreadable', () {
      expect(Coerce.asBool(null), isNull);
      expect(Coerce.asBool(''), isNull);
      expect(Coerce.asBool('null'), isNull);
      expect(Coerce.asBool('maybe'), isNull);
    });
  });

  group('asUnixSeconds', () {
    test('reads a timestamp from a number or a string', () {
      final expected = DateTime.utc(2026, 8, 22, 12);
      final seconds = expected.millisecondsSinceEpoch ~/ 1000;

      expect(Coerce.asUnixSeconds(seconds), expected);
      expect(Coerce.asUnixSeconds('$seconds'), expected);
    });

    test('returns UTC', () {
      expect(Coerce.asUnixSeconds(1755864000)?.isUtc, isTrue);
    });

    test('rejects values outside a plausible date range', () {
      // A millisecond timestamp read as seconds lands in the year 57000.
      expect(Coerce.asUnixSeconds(1755864000000), isNull);
      expect(Coerce.asUnixSeconds(0), isNull);
      expect(Coerce.asUnixSeconds(-1), isNull);
      expect(Coerce.asUnixSeconds(12345), isNull);
    });

    test('returns null for empty markers', () {
      expect(Coerce.asUnixSeconds(''), isNull);
      expect(Coerce.asUnixSeconds('null'), isNull);
    });
  });

  group('asMapList', () {
    test('passes a list of maps through', () {
      final result = Coerce.asMapList([
        {'id': 1},
        {'id': 2},
      ]);
      expect(result, hasLength(2));
      expect(result.first['id'], 1);
    });

    test('wraps a bare object as a single-element list', () {
      final result = Coerce.asMapList({'id': 1, 'name': 'Only'});
      expect(result, hasLength(1));
      expect(result.single['name'], 'Only');
    });

    test('flattens a season-keyed episode object', () {
      // get_series_info returns episodes keyed by season number.
      final result = Coerce.asMapList({
        '1': [
          {'id': 'e1'},
          {'id': 'e2'},
        ],
        '2': [
          {'id': 'e3'},
        ],
      });

      expect(result, hasLength(3));
      expect(result.map((e) => e['id']), ['e1', 'e2', 'e3']);
    });

    test('skips non-map elements inside a list', () {
      final result = Coerce.asMapList([
        {'id': 1},
        'junk',
        null,
        {'id': 2},
      ]);
      expect(result, hasLength(2));
    });

    test('returns empty for null and unusable input', () {
      expect(Coerce.asMapList(null), isEmpty);
      expect(Coerce.asMapList('a string'), isEmpty);
      expect(Coerce.asMapList(42), isEmpty);
    });

    test('normalises non-string keys', () {
      final result = Coerce.asMapList([
        <Object?, Object?>{1: 'one', 'two': 2},
      ]);
      expect(result.single['1'], 'one');
      expect(result.single['two'], 2);
    });
  });

  group('asStringList', () {
    test('reads a real list', () {
      expect(Coerce.asStringList(['Action', 'Drama']), ['Action', 'Drama']);
    });

    test('splits a comma-delimited string', () {
      expect(Coerce.asStringList('Action, Drama , Comedy'), [
        'Action',
        'Drama',
        'Comedy',
      ]);
    });

    test('drops empty segments', () {
      expect(Coerce.asStringList('Action,,Drama,'), ['Action', 'Drama']);
    });

    test('honours a custom separator', () {
      expect(Coerce.asStringList('a|b|c', separator: '|'), ['a', 'b', 'c']);
    });

    test('returns empty for absent values', () {
      expect(Coerce.asStringList(null), isEmpty);
      expect(Coerce.asStringList(''), isEmpty);
      expect(Coerce.asStringList('null'), isEmpty);
    });

    test('stringifies numeric list elements', () {
      expect(Coerce.asStringList([1, 2, 3]), ['1', '2', '3']);
    });
  });
}

/// Tolerant readers for Xtream Codes JSON.
///
/// Portals are wildly inconsistent about types. The same field arrives as a
/// number from one provider and a string from the next; booleans appear as
/// `0`, `"0"`, `false` and `"false"`; absent values arrive as `null`, `""`
/// or the literal string `"null"`; and a list with one element is sometimes
/// serialised as a bare object.
///
/// Decoding strictly against any one provider's shape is what produces the
/// "works for me, crashes for them" class of bug. Every reader here returns
/// null rather than throwing, so a single odd field costs one value instead
/// of the whole catalogue.
class Coerce {
  const Coerce._();

  /// Values providers use to mean "nothing", beyond actual null.
  static const _emptyMarkers = {'', 'null', 'nil', 'none', 'undefined', 'n/a'};

  static bool _isEmptyMarker(String value) =>
      _emptyMarkers.contains(value.trim().toLowerCase());

  /// Reads a string, treating provider "empty" markers as absent.
  static String? asString(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return _isEmptyMarker(trimmed) ? null : trimmed;
    }
    if (value is num || value is bool) return '$value';
    return null;
  }

  /// Reads an integer from an int, a double, or a numeric string.
  ///
  /// A fractional value truncates, which matters because some portals send
  /// ids as `12345.0`.
  static int? asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) {
      return value.isFinite ? value.truncate() : null;
    }
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      final trimmed = value.trim();
      if (_isEmptyMarker(trimmed)) return null;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.truncate();
    }
    return null;
  }

  static double? asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.isFinite ? value.toDouble() : null;
    if (value is String) {
      final trimmed = value.trim();
      if (_isEmptyMarker(trimmed)) return null;
      final parsed = double.tryParse(trimmed);
      return (parsed == null || !parsed.isFinite) ? null : parsed;
    }
    return null;
  }

  /// Reads a boolean from the many shapes portals use for one.
  ///
  /// Recognises true/false, 1/0, "1"/"0", "true"/"false", "yes"/"no".
  /// Any non-zero number is true.
  static bool? asBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final trimmed = value.trim().toLowerCase();
      if (_isEmptyMarker(trimmed)) return null;
      switch (trimmed) {
        case 'true':
        case 'yes':
        case 'y':
          return true;
        case 'false':
        case 'no':
        case 'n':
          return false;
      }
      final number = num.tryParse(trimmed);
      return number == null ? null : number != 0;
    }
    return null;
  }

  /// Reads a Unix timestamp in seconds, as either a number or a string.
  ///
  /// Returns UTC. Values are sanity-checked against a plausible range so a
  /// millisecond timestamp or a stray id is not read as a date in the year
  /// 55000.
  static DateTime? asUnixSeconds(Object? value) {
    final seconds = asInt(value);
    if (seconds == null || seconds <= 0) return null;
    // Roughly 1990 to 2100. Outside that the field is not a timestamp.
    if (seconds < 631152000 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// Reads a list of maps, tolerating a bare object where a list belongs.
  ///
  /// Portals collapse single-element lists into the element itself, and some
  /// key episode lists by season into an object whose values are the lists.
  static List<Map<String, Object?>> asMapList(Object? value) {
    if (value == null) return const [];

    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map(_castMap)
          .toList(growable: false);
    }

    if (value is Map) {
      // A map keyed by *numbers* whose values are lists is a keyed
      // collection — get_series_info returns episodes as {"1": [...]} — so
      // flatten it.
      //
      // The key test matters. Testing only that the values are lists also
      // matches an ordinary response envelope like {"results": [...]} or
      // {"cast": [...]}, and flattening one of those silently discards the
      // envelope and returns its contents as though they were the object.
      final entries = value.entries.toList();
      final looksKeyed =
          entries.isNotEmpty &&
          entries.every((e) => e.value is List && _isNumericKey(e.key));
      if (looksKeyed) {
        return entries
            .map((e) => e.value)
            .cast<List<Object?>>()
            .expand((list) => list.whereType<Map<Object?, Object?>>())
            .map(_castMap)
            .toList(growable: false);
      }
      return [_castMap(value)];
    }

    return const [];
  }

  /// Reads a list of strings from a real list or a delimited string.
  static List<String> asStringList(Object? value, {String separator = ','}) {
    if (value == null) return const [];

    if (value is List) {
      return value.map(asString).whereType<String>().toList(growable: false);
    }

    final single = asString(value);
    if (single == null) return const [];
    return single
        .split(separator)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// Reads a single JSON object, for unwrapping a response envelope.
  ///
  /// Use this rather than [asMapList] when exactly one object is expected:
  /// asMapList is for collections and has to guess at shapes.
  static Map<String, Object?>? asMap(Object? value) =>
      value is Map ? _castMap(value) : null;

  static bool _isNumericKey(Object? key) =>
      key is num || (key is String && int.tryParse(key.trim()) != null);

  static Map<String, Object?> _castMap(Map<Object?, Object?> raw) {
    return raw.map((key, value) => MapEntry('$key', value));
  }
}

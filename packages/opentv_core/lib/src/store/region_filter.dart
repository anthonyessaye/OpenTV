import 'dart:convert';

import 'tables.dart';

/// Which regions a viewer has chosen not to see, per kind.
///
/// Stored as one preference rather than a table. It is a handful of short
/// strings that change when somebody opens settings and never otherwise, and
/// a table would mean a migration to hold what fits in a line of JSON.
///
/// Per kind rather than one list for everything, because the answer genuinely
/// differs: a household may want every region's live channels — that is what
/// the subscription is for — while wanting films in two languages and no
/// others.
class RegionFilter {
  const RegionFilter({this.hidden = const {}});

  /// Kind to the regions hidden for it.
  final Map<ItemKind, Set<String>> hidden;

  static const preferenceKey = 'hidden-regions';

  Set<String> forKind(ItemKind kind) => hidden[kind] ?? const {};

  bool isHidden(ItemKind kind, String? region) =>
      region != null && forKind(kind).contains(region);

  RegionFilter withRegion(ItemKind kind, String region, {required bool hide}) {
    final next = {
      for (final entry in hidden.entries) entry.key: {...entry.value},
    };
    final set = next.putIfAbsent(kind, () => <String>{});
    if (hide) {
      set.add(region);
    } else {
      set.remove(region);
    }
    // An empty set is dropped rather than stored, so a viewer who hides a
    // region and unhides it again leaves no trace and the "everything is
    // shown" case is one shape rather than two.
    next.removeWhere((_, value) => value.isEmpty);
    return RegionFilter(hidden: next);
  }

  String encode() => jsonEncode({
        for (final entry in hidden.entries)
          entry.key.name: entry.value.toList()..sort(),
      });

  /// Reads the stored value, tolerating anything that is not one.
  ///
  /// A preference is written by a newer version of the app than the one
  /// reading it more often than anyone expects — a handover carries the
  /// database between devices — so a shape this cannot parse means "nothing
  /// hidden" rather than a crash on the settings screen.
  static RegionFilter decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RegionFilter();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const RegionFilter();
      final out = <ItemKind, Set<String>>{};
      for (final entry in decoded.entries) {
        final kind = ItemKind.values
            .where((k) => k.name == entry.key)
            .firstOrNull;
        final value = entry.value;
        if (kind == null || value is! List) continue;
        final regions = {
          for (final region in value)
            if (region is String && region.isNotEmpty) region,
        };
        if (regions.isNotEmpty) out[kind] = regions;
      }
      return RegionFilter(hidden: out);
    } on FormatException {
      return const RegionFilter();
    }
  }

  @override
  String toString() => 'RegionFilter($hidden)';
}

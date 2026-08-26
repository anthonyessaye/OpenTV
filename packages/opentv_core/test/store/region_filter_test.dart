import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

void main() {
  test('a round trip preserves what was hidden', () {
    const start = RegionFilter();
    final after = start
        .withRegion(ItemKind.movie, 'TR', hide: true)
        .withRegion(ItemKind.movie, 'DE', hide: true)
        .withRegion(ItemKind.series, 'FR', hide: true);

    final decoded = RegionFilter.decode(after.encode());
    expect(decoded.forKind(ItemKind.movie), {'TR', 'DE'});
    expect(decoded.forKind(ItemKind.series), {'FR'});
    expect(decoded.forKind(ItemKind.live), isEmpty);
  });

  test('unhiding the last region leaves no trace', () {
    // "Everything is shown" should be one shape, not two — an absent key and
    // an empty list would both mean it and only one of them is obvious.
    final after = const RegionFilter()
        .withRegion(ItemKind.movie, 'TR', hide: true)
        .withRegion(ItemKind.movie, 'TR', hide: false);

    expect(after.hidden, isEmpty);
    expect(after.encode(), '{}');
  });

  test('kinds do not leak into each other', () {
    final after =
        const RegionFilter().withRegion(ItemKind.movie, 'TR', hide: true);

    expect(after.isHidden(ItemKind.movie, 'TR'), isTrue);
    expect(after.isHidden(ItemKind.series, 'TR'), isFalse);
    expect(after.isHidden(ItemKind.live, 'TR'), isFalse);
  });

  test('a row with no region is never hidden', () {
    final after =
        const RegionFilter().withRegion(ItemKind.movie, 'TR', hide: true);
    expect(after.isHidden(ItemKind.movie, null), isFalse);
  });

  test('rubbish decodes to nothing hidden rather than throwing', () {
    // A handover carries this database between devices, so a preference
    // written by a different version of the app is ordinary rather than
    // exceptional.
    for (final raw in ['', 'not json', '[]', '{"movie":"TR"}', '{"nope":["X"]}']) {
      expect(RegionFilter.decode(raw).hidden, isEmpty, reason: raw);
    }
    expect(RegionFilter.decode(null).hidden, isEmpty);
  });
}

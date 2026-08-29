import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Episode rows are file paths, not titles.
///
/// A real catalogue row reads `4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot`,
/// and every episode of that show repeats the first fifty characters. Both
/// interfaces drew the raw string, so a season was a column of identical text
/// with the one word that differed pushed off the end of the line.
void main() {
  test('takes what follows the marker', () {
    expect(
      TitleCleaner.episodeName('4K-A+ - Acapulco (2021) (US) - S01E01 - Pilot'),
      'Pilot',
    );
    expect(
      TitleCleaner.episodeName(
        "4K-A+ - Acapulco (2021) (US) - S01E02 - Jessie's Girl",
      ),
      "Jessie's Girl",
    );
  });

  test('handles the other marker providers use', () {
    expect(TitleCleaner.episodeName('Supernatural 4x01 Lazarus Rising'),
        'Lazarus Rising');
  });

  test('drops the quality that trails it', () {
    expect(
      TitleCleaner.episodeName('Show - S02E05 - The Reckoning 1080p'),
      'The Reckoning',
    );
  });

  test('is null when the marker is all there is', () {
    // The caller then labels it by number, which it knows and this does not.
    expect(TitleCleaner.episodeName('Supernatural S04E01'), isNull);
    expect(TitleCleaner.episodeName('Supernatural S04E01 - '), isNull);
  });

  test('is null when there is no marker to split on', () {
    expect(TitleCleaner.episodeName('Just A Name'), isNull);
  });

  test('leaves a name that happens to contain digits alone', () {
    expect(
      TitleCleaner.episodeName('Show - S01E03 - 99 Problems'),
      '99 Problems',
    );
  });
}

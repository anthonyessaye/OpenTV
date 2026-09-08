import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// The region is usually written in the endpoint already.
///
/// Asking for it separately asks a viewer to copy half of what they have just
/// typed — and a wrong region fails identically to a wrong key, with
/// `SignatureDoesNotMatch` and nothing else to say which.
void main() {
  test('Backblaze says it in the hostname', () {
    expect(
      s3RegionFor(Uri.parse('https://s3.us-west-004.backblazeb2.com')),
      'us-west-004',
    );
  });

  test('so does AWS, in both spellings', () {
    expect(
      s3RegionFor(Uri.parse('https://s3.eu-central-1.amazonaws.com')),
      'eu-central-1',
    );
    expect(
      s3RegionFor(Uri.parse('https://s3-eu-west-2.amazonaws.com')),
      'eu-west-2',
    );
  });

  test('Wasabi too', () {
    expect(
      s3RegionFor(Uri.parse('https://s3.eu-central-2.wasabisys.com')),
      'eu-central-2',
    );
  });

  test('R2 has no regions and wants the word auto', () {
    expect(
      s3RegionFor(Uri.parse('https://abc123.r2.cloudflarestorage.com')),
      'auto',
    );
  });

  test('anything else is not guessed at', () {
    // A MinIO on somebody's NAS. Guessing here would produce a signature
    // failure that names none of this, so the field stays and is asked for.
    expect(s3RegionFor(Uri.parse('https://nas.local:9000')), null);
    expect(s3RegionFor(Uri.parse('https://storage.example.com')), null);
  });
}

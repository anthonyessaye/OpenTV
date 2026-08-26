import 'dart:typed_data';

import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

/// Frames, and the property that sealing pieces separately does not give away
/// for free.
///
/// One-shot sealing authenticated the whole payload at once, so nothing could
/// be reordered, dropped or replayed without the tag failing. Independent
/// frames lose that unless the position is bound into each one — an attacker
/// who can read nothing and forge nothing could still shuffle them, and the
/// result decrypts perfectly and is wrong.
void main() {
  final key = Uint8List.fromList(
    HandoverPairing.generate(hosts: const ['x'], port: 1).key,
  );

  Uint8List chunk(int size, int seed) => Uint8List.fromList(
        List<int>.generate(size, (i) => (i + seed) % 256),
      );

  test('a frame opens at the position it was sealed for', () async {
    final plain = chunk(4096, 3);
    final sealed = await HandoverFrames.seal(plain, 7, key);
    expect(await HandoverFrames.open(sealed, 7, key), plain);
  });

  test('a frame moved to another position is refused', () async {
    // The reordering this exists to stop.
    final sealed = await HandoverFrames.seal(chunk(4096, 3), 7, key);

    await expectLater(
      HandoverFrames.open(sealed, 8, key),
      throwsA(isA<HandoverException>().having(
        (e) => e.refusal, 'refusal', HandoverRefusal.notAuthentic)),
    );
  });

  test('two frames cannot be swapped', () async {
    final first = await HandoverFrames.seal(chunk(1024, 1), 0, key);
    final second = await HandoverFrames.seal(chunk(1024, 2), 1, key);

    await expectLater(
      HandoverFrames.open(second, 0, key),
      throwsA(isA<HandoverException>()),
    );
    await expectLater(
      HandoverFrames.open(first, 1, key),
      throwsA(isA<HandoverException>()),
    );
  });

  test('an altered frame is refused', () async {
    final sealed = await HandoverFrames.seal(chunk(4096, 5), 0, key);
    sealed[sealed.length ~/ 2] ^= 0x01;

    await expectLater(
      HandoverFrames.open(sealed, 0, key),
      throwsA(isA<HandoverException>()),
    );
  });

  test('the wrong key opens nothing', () async {
    final sealed = await HandoverFrames.seal(chunk(4096, 5), 0, key);
    final other = Uint8List.fromList(
      HandoverPairing.generate(hosts: const ['x'], port: 1).key,
    );

    await expectLater(
      HandoverFrames.open(sealed, 0, other),
      throwsA(isA<HandoverException>()),
    );
  });

  test('the reader reassembles frames split across arrivals', () async {
    // A socket hands over whatever it happens to have, which is never the
    // shape the frames were written in.
    final chunks = [chunk(1000, 1), chunk(2000, 2), chunk(1500, 3)];
    final wire = BytesBuilder(copy: false);
    for (var i = 0; i < chunks.length; i++) {
      wire.add(HandoverFrames.framed(
        await HandoverFrames.seal(chunks[i], i, key),
      ));
    }
    final bytes = wire.toBytes();

    final reader = HandoverFrameReader(key);
    final out = <Uint8List>[];
    // Deliberately awkward arrivals, including one byte at a time across a
    // length prefix.
    var offset = 0;
    for (final size in [1, 3, 700, 2, 5000, 99999]) {
      if (offset >= bytes.length) break;
      final end = (offset + size).clamp(0, bytes.length);
      await for (final frame in reader.add(
        Uint8List.sublistView(bytes, offset, end),
      )) {
        out.add(frame);
      }
      offset = end;
    }

    expect(out.length, chunks.length);
    for (var i = 0; i < chunks.length; i++) {
      expect(out[i], chunks[i], reason: 'frame $i came back wrong');
    }
    expect(reader.isComplete, isTrue);
  });

  test('a truncated stream leaves the reader unfinished', () async {
    final sealed = await HandoverFrames.seal(chunk(4096, 9), 0, key);
    final framed = HandoverFrames.framed(sealed);

    final reader = HandoverFrameReader(key);
    final out = <Uint8List>[];
    await for (final frame in reader.add(
      Uint8List.sublistView(framed, 0, framed.length - 10),
    )) {
      out.add(frame);
    }

    expect(out, isEmpty);
    expect(reader.isComplete, isFalse, reason: 'a cut stream looked complete');
  });
}

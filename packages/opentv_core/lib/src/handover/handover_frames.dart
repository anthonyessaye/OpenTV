import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'handover_bundle.dart';

/// The payload, cut into independently sealed pieces.
///
/// One-shot sealing held the whole catalogue three times over — the database,
/// a copy of it inside the payload, and a sealed copy of that. Measured on a
/// laptop, a 64MB catalogue peaked at 464MB of resident memory. A television
/// box has a per-app heap of a couple of hundred megabytes, so it ran out and
/// appeared to hang; a phone with more room got through, and one with a large
/// catalogue produced the ANR that pointed at this.
///
/// Frames make the peak a couple of chunks rather than a multiple of the
/// catalogue. Each is sealed on its own, so the sender can read from the file
/// and write to the socket without ever holding the whole thing, and the
/// receiver can write straight to disk.
///
/// ## Why the index is authenticated
///
/// Sealing pieces separately weakens something one-shot sealing gave for
/// free: with independent frames, an attacker who cannot read or forge any of
/// them can still reorder them, drop the tail, or replay a frame from one
/// position into another. Each of those produces a database that decrypts
/// perfectly and is wrong.
///
/// So the frame's index goes in as additional authenticated data — it is not
/// encrypted, but the tag covers it, and a frame moved to another position
/// fails to open. Truncation is caught separately, by checking the bytes that
/// arrived against the length the manifest promised.
class HandoverFrames {
  const HandoverFrames();

  /// How much plaintext goes in one frame.
  ///
  /// Four megabytes: large enough that the per-frame overhead is noise and
  /// small enough that two of them in memory is nothing on any device this
  /// runs on.
  static const chunkSize = 4 * 1024 * 1024;

  /// Nonce, then ciphertext, then tag — the shape one frame arrives in.
  static const nonceLength = 12;

  static final _algorithm = AesGcm.with256bits();

  /// Seals one chunk, binding it to its position.
  static Future<Uint8List> seal(
    Uint8List chunk,
    int index,
    Uint8List key,
  ) async {
    final box = await _algorithm.encrypt(
      chunk,
      secretKey: SecretKey(key),
      aad: _positionOf(index),
    );
    final out = BytesBuilder(copy: false)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  /// Opens one frame, refusing it if it did not come from this position.
  static Future<Uint8List> open(
    Uint8List frame,
    int index,
    Uint8List key,
  ) async {
    final macLength = _algorithm.macAlgorithm.macLength;
    if (frame.length < nonceLength + macLength) {
      throw const HandoverException(
        HandoverRefusal.malformed,
        'a frame was too short to contain a nonce and a tag',
      );
    }
    final box = SecretBox(
      Uint8List.sublistView(frame, nonceLength, frame.length - macLength),
      nonce: Uint8List.sublistView(frame, 0, nonceLength),
      mac: Mac(Uint8List.sublistView(frame, frame.length - macLength)),
    );
    try {
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(key),
        aad: _positionOf(index),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const HandoverException(
        HandoverRefusal.notAuthentic,
        'a frame did not decrypt: the code was wrong, the bytes were altered '
        'on the way, or they arrived out of order',
      );
    }
  }

  /// The bytes the tag covers but does not hide.
  static List<int> _positionOf(int index) =>
      utf8.encode('opentv/handover/frame/$index');

  /// The secrets, as the first thing in the stream.
  ///
  /// Ahead of the database so a receiver has them before the long part
  /// begins, and small enough to be one frame in every real case.
  static Uint8List secretsBlock(List<HandoverSecret> secrets) {
    final json = utf8.encode(
      jsonEncode([for (final secret in secrets) secret.toJson()]),
    );
    final out = BytesBuilder(copy: false)
      ..add(_uint32(json.length))
      ..add(json);
    return out.toBytes();
  }

  static Uint8List _uint32(int value) =>
      (ByteData(4)..setUint32(0, value, Endian.big)).buffer.asUint8List();

  /// A length-prefixed frame, as it goes on the wire.
  static Uint8List framed(Uint8List sealed) {
    final out = BytesBuilder(copy: false)
      ..add(_uint32(sealed.length))
      ..add(sealed);
    return out.toBytes();
  }
}

/// Reassembles frames arriving in pieces from a socket.
///
/// A socket hands over whatever it happens to have, which is never the same
/// shape as the frames that were written. This buffers only until a whole
/// frame is present and then lets go of it, so what is held is one frame
/// rather than the transfer.
class HandoverFrameReader {
  HandoverFrameReader(this.key);

  final Uint8List key;

  final _buffer = BytesBuilder(copy: false);
  int _index = 0;

  /// Adds bytes and yields whatever whole frames they completed.
  Stream<Uint8List> add(List<int> incoming) async* {
    _buffer.add(incoming);
    while (true) {
      final pending = _buffer.toBytes();
      if (pending.length < 4) {
        _buffer
          ..clear()
          ..add(pending);
        return;
      }
      final length = ByteData.sublistView(pending, 0, 4).getUint32(0, Endian.big);
      if (pending.length < 4 + length) {
        _buffer
          ..clear()
          ..add(pending);
        return;
      }
      final frame = Uint8List.sublistView(pending, 4, 4 + length);
      final rest = Uint8List.sublistView(pending, 4 + length);
      _buffer
        ..clear()
        ..add(rest);
      yield await HandoverFrames.open(frame, _index++, key);
    }
  }

  /// Whether everything that was started has been finished.
  bool get isComplete => _buffer.isEmpty;
}

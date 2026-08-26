import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/stream_resolver.dart';
import 'package:opentv/mobile/zapping.dart';
import 'package:opentv_core/opentv_core.dart';

/// Changing channel from inside the player.
///
/// The rule is the television's, and both halves of it are deliberate:
/// bounded by the list being browsed, and no wrapping.
void main() {
  Channel channel(String id) => Channel(
        sourceId: 1,
        remoteId: id,
        name: 'Channel $id',
        searchName: 'channel $id',
        hidden: false,
        hasArchive: false,
        archiveDays: 0,
      );

  final list = [channel('a'), channel('b'), channel('c')];

  test('the next channel is the next in the list', () {
    final next = zapTo(list, Playable.channel(channel('a')), 1);
    expect(next?.remoteId, 'b');
  });

  test('the previous channel is the previous in the list', () {
    final previous = zapTo(list, Playable.channel(channel('c')), -1);
    expect(previous?.remoteId, 'b');
  });

  test('the ends do not wrap', () {
    // Running off the end says you have reached it. Wrapping silently puts
    // somebody at the other end of three hundred channels with nothing to
    // tell them it happened.
    expect(zapTo(list, Playable.channel(channel('c')), 1), isNull);
    expect(zapTo(list, Playable.channel(channel('a')), -1), isNull);
  });

  test('a film has no neighbours', () {
    // Offering a next channel off a film would be a control that lies.
    final film = Playable.movie(
      Movie(
        sourceId: 1,
        remoteId: 'a',
        name: 'A Film',
        searchName: 'a film',
        hidden: false,
      ),
    );
    expect(zapTo(list, film, 1), isNull);
  });

  test('a channel that is not in the list has no neighbours', () {
    // Catch-up opens a player with no list behind it, and a stray index would
    // zap to whatever happened to sit at position zero.
    expect(zapTo(list, Playable.channel(channel('z')), 1), isNull);
    expect(zapTo(const [], Playable.channel(channel('a')), 1), isNull);
  });
}

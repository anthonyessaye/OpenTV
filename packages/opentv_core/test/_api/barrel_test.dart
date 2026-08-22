// Guards the public surface: importing only the barrel must be enough, and
// must not produce ambiguous exports. Two name collisions between the parse
// models and the drift row classes were found this way.
import 'package:opentv_core/opentv_core.dart';
import 'package:test/test.dart';

void main() {
  test('the barrel exposes parse models and store types side by side', () {
    expect(const EpgChannel(id: 'bbc1').id, 'bbc1');
    expect(SyncStage.values, contains(SyncStage.guide));
    expect(ItemKind.values, contains(ItemKind.live));
    expect(normaliseForSearch('BBC One'), 'bbc one');
    expect(
      XtreamCredentials.normaliseHost('portal.example/'),
      'http://portal.example',
    );
  });
}

import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'app/host.dart';
import 'app/opentv_app.dart';
import 'app/sqlite_setup.dart';

Future<void> main() async {
  // The binding has to exist before anything touches a platform channel, and
  // the app asks the host for its data directory during its first frame.
  WidgetsFlutterBinding.ensureInitialized();

  // Which SQLite to load differs by platform and has to be settled before the
  // first database is opened.
  configureSqlite();

  // Settled once, here, rather than read from a MediaQuery further down.
  //
  // It decides which of two interfaces exists at all — not a breakpoint that
  // can change when a window resizes — so it is resolved before the first
  // frame and then never asked again. Doing it inside the tree would mean a
  // frame of the wrong interface while the channel answers, and on a
  // television that frame is a screen with no focus on it.
  //
  // A failure here falls back to a handset, which is the recoverable
  // direction: a touch layout on a television is awkward, and a d-pad layout
  // on a phone cannot be operated at all.
  var device = DeviceClass.phone;
  try {
    device = await const Host().deviceClass();
  } on Object {
    // Left as the fallback. The contract test is what stops this from being
    // reached; nothing useful can be done about it in front of a viewer.
  }

  runApp(OpenTvApp(device: device));
}

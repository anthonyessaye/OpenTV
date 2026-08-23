import 'package:flutter/widgets.dart';

import 'app/opentv_app.dart';
import 'app/sqlite_setup.dart';

void main() {
  // The binding has to exist before anything touches a platform channel, and
  // the app asks the host for its data directory during its first frame.
  WidgetsFlutterBinding.ensureInitialized();

  // Which SQLite to load differs by platform and has to be settled before the
  // first database is opened.
  configureSqlite();

  runApp(OpenTvApp());
}

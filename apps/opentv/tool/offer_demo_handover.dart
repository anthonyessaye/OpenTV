import 'dart:io';

import 'package:drift/native.dart';
import 'package:opentv_core/opentv_core.dart';

/// Stands in for a television offering its setup, so the phone half can be
/// exercised against a real socket without two devices in the room.
///
/// ```
/// dart run tool/offer_demo_handover.dart <catalogue.sqlite>
/// ```
Future<void> main(List<String> args) async {
  final file = File(args.first);
  final db = OpenTvDatabase(NativeDatabase(file));
  await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

  final hosts = <String>[];
  for (final interface in await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  )) {
    for (final address in interface.addresses) {
      if (!address.isLoopback) hosts.add(address.address);
    }
  }
  hosts.add('127.0.0.1');

  final bundle = await HandoverBundle.fromFile(
    file,
    schemaVersion: db.schemaVersion,
    appVersion: '1.1.0',
    secrets: const [
      HandoverSecret(reference: 'demo/password', secret: 'hunter2'),
    ],
    sourceCount: (await db.allSources()).length,
  );
  await db.close();

  final pairing = HandoverPairing.generate(hosts: hosts, port: 8100);
  final server = HandoverServer(
    pairing: pairing,
    bundle: bundle,
    compatibility: HandoverCompatibility(schemaVersion: bundle.manifest.schemaVersion),
    onReceived: (b) async => stdout.writeln('received ${b.database.length} bytes'),
  );
  await server.start();

  stdout
    ..writeln('schema  ${bundle.manifest.schemaVersion}')
    ..writeln('bytes   ${bundle.manifest.databaseBytes}')
    ..writeln('hosts   ${hosts.join(', ')}')
    ..writeln('URL     ${pairing.encode()}');
}

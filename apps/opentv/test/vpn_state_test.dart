import 'package:flutter_test/flutter_test.dart';
import 'package:opentv/app/vpn_service.dart';

void main() {
  group('VpnState', () {
    test('reads the states the Android backend reports', () {
      // The names come from com.wireguard.android.backend.Tunnel.State,
      // lowercased on the way across. If that enum ever grows a member this
      // is where it shows up.
      expect(VpnState.parse('up'), VpnState.up);
      expect(VpnState.parse('toggle'), VpnState.connecting);
      expect(VpnState.parse('down'), VpnState.down);
    });

    test('treats anything unrecognised as down', () {
      // The safe direction. Claiming a tunnel is up when the app cannot tell
      // gives the viewer a false idea of their own exposure; claiming it is
      // down at worst asks them to press connect again.
      expect(VpnState.parse(null), VpnState.down);
      expect(VpnState.parse(''), VpnState.down);
      expect(VpnState.parse('something new'), VpnState.down);
    });
  });
}

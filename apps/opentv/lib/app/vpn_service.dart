import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:opentv_core/opentv_core.dart';

import 'host.dart';

/// What the tunnel is doing.
enum VpnState {
  /// No tunnel, by choice or because none is configured.
  down,

  /// Asked for, not yet carrying traffic.
  connecting,

  up;

  static VpnState parse(String? name) => switch (name) {
    'up' => VpnState.up,
    'toggle' => VpnState.connecting,
    _ => VpnState.down,
  };
}

/// The app's side of the tunnel.
///
/// Deliberately app-wide and not per-screen. A VPN is either carrying this
/// device's traffic or it is not, and a design where two screens each hold
/// their own idea of that is a design where one of them is wrong.
///
/// The configuration is a secret in full, not just its key: an address, a
/// port and a public key together identify the provider being used, which is
/// most of what a tunnel exists to keep to itself. It goes to the keystore,
/// the same place the provider password goes, and never to the database.
class VpnService {
  VpnService({this.host = const Host()}) {
    _channel.setMethodCallHandler(_fromNative);
  }

  static const _channel = MethodChannel('opentv/vpn');

  /// The keystore entry holding the `.conf`.
  static const configReference = 'vpn.wireguard.config';

  final Host host;

  final state = ValueNotifier<VpnState>(VpnState.down);

  /// Why the last attempt failed, in a sentence, or null.
  final problem = ValueNotifier<String?>(null);

  /// Whether this platform has a tunnel at all.
  ///
  /// Android does. tvOS needs a Network Extension, which needs a paid
  /// developer account to sign — so the honest answer there is "not yet"
  /// rather than a button that fails.
  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _fromNative(MethodCall call) async {
    if (call.method == 'state') {
      state.value = VpnState.parse(call.arguments as String?);
    }
  }

  /// Whether the OS has already allowed this app to route traffic.
  ///
  /// Distinct from [requestPermission], which answers the same question by
  /// showing a dialog. Connecting on launch needs the answer without the
  /// dialog: a television that has just been turned on should not greet its
  /// viewer with a system permission prompt they did not ask for.
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Brings the tunnel up if there is one and it can be done silently.
  ///
  /// Called on launch and on returning from the background. Deliberately
  /// quiet about every reason it might not act — no configuration, no
  /// permission yet, not this platform — because none of those are failures
  /// and none of them are worth a message on a screen somebody is trying to
  /// watch television on. The panel in settings is where the state is
  /// reported.
  ///
  /// Returns whether it connected.
  Future<bool> connectIfConfigured() async {
    if (!isSupported) return false;
    if (state.value != VpnState.down) return false;

    final text = await host.readSecret(configReference);
    if (text == null || text.isEmpty) return false;

    // Permission is checked rather than requested. The one moment a viewer
    // should be asked is when they set the tunnel up and are expecting it.
    if (!await hasPermission()) return false;

    return await connect() == null;
  }

  /// Checks and, if necessary, asks for the OS permission to route traffic.
  ///
  /// False means the viewer declined, which is a decision to respect rather
  /// than an error to report.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      // Flagged for the lifecycle watcher. The permission dialog is another
      // activity, so showing it sends this app to the background — and the
      // rule "disconnect when backgrounded" would otherwise tear the tunnel
      // down at the exact moment the viewer was granting permission for it.
      _awaitingPermission = true;
      return await _channel.invokeMethod<bool>('prepare') ?? false;
    } on PlatformException {
      return false;
    } finally {
      _awaitingPermission = false;
    }
  }

  /// Whether a system dialog this app asked for is currently in front.
  bool get isAwaitingPermission => _awaitingPermission;
  bool _awaitingPermission = false;

  /// Validates and stores a configuration without connecting.
  ///
  /// Returns what is wrong with it, or null when it was accepted. Parsing
  /// here rather than only in the tunnel is what lets a viewer who pasted
  /// half a file be told so, instead of watching a connection fail.
  Future<String?> save(String text) async {
    try {
      WireGuardConfig.parse(text);
    } on WireGuardConfigException catch (error) {
      return error.message;
    }
    await host.writeSecret(configReference, text);
    return null;
  }

  Future<WireGuardConfig?> stored() async {
    final text = await host.readSecret(configReference);
    if (text == null || text.isEmpty) return null;
    try {
      return WireGuardConfig.parse(text);
    } on WireGuardConfigException {
      return null;
    }
  }

  Future<void> forget() async {
    await disconnect();
    await host.deleteSecret(configReference);
  }

  /// Brings the tunnel up, returning what went wrong or null.
  Future<String?> connect() async {
    if (!isSupported) return 'This platform has no tunnel yet.';

    final text = await host.readSecret(configReference);
    if (text == null || text.isEmpty) {
      return 'There is no configuration to connect with.';
    }

    if (!await requestPermission()) {
      return 'Android did not grant permission to route traffic.';
    }

    problem.value = null;
    state.value = VpnState.connecting;
    try {
      final result = await _channel.invokeMethod<String>('up', {
        'config': text,
      });
      state.value = VpnState.parse(result);
      return null;
    } on PlatformException catch (error) {
      state.value = VpnState.down;
      // The native side sends the message only, never the configuration or a
      // stack trace — a private key one bug report away from being public.
      problem.value = error.message ?? 'The tunnel did not come up.';
      return problem.value;
    }
  }

  Future<void> disconnect() async {
    if (!isSupported) return;
    try {
      final result = await _channel.invokeMethod<String>('down');
      state.value = VpnState.parse(result);
    } on PlatformException {
      // Nothing useful to say: the tunnel is down either way, which is what
      // was asked for.
      state.value = VpnState.down;
    }
  }

  /// Bytes carried since the tunnel came up, or null when it is not up.
  Future<({int rx, int tx, bool stale})?> statistics() async {
    if (!isSupported || state.value != VpnState.up) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('statistics');
      if (raw == null) return null;
      return (
        rx: (raw['rx'] as num?)?.toInt() ?? 0,
        tx: (raw['tx'] as num?)?.toInt() ?? 0,
        stale: raw['stale'] as bool? ?? false,
      );
    } on PlatformException {
      return null;
    }
  }

  /// Releases the notifiers and stops listening to the platform.
  ///
  /// The channel handler is set on a channel shared by every instance, so a
  /// second service quietly replaces the first one's handler and the first
  /// stops hearing about state changes. One instance, owned by the app, is
  /// the arrangement this expects.
  void dispose() {
    _channel.setMethodCallHandler(null);
    state.dispose();
    problem.dispose();
  }

  /// Re-reads the tunnel's actual state from the OS.
  ///
  /// Worth doing on resume: a tunnel can be torn down by the system, by
  /// another VPN app taking over, or by the viewer in Android's own settings,
  /// and none of those tell this app about it.
  Future<void> resync() async {
    if (!isSupported) return;
    try {
      state.value = VpnState.parse(
        await _channel.invokeMethod<String>('state'),
      );
    } on PlatformException {
      state.value = VpnState.down;
    }
  }
}

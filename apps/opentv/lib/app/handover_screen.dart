import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'handover_service.dart';

/// Offering this device's setup to another one.
///
/// Displays, and never scans. A television has no camera, so the direction is
/// decided by the hardware rather than by which way the data is about to
/// travel — this screen is the same on a phone, which keeps one arrangement
/// instead of two.
///
/// The code is read by whatever camera the other device already has. Nothing
/// here asks for a camera permission and no scanner is bundled, because a
/// scanner package's podspec would have to declare tvOS and none of them do —
/// the same wall that put the data directory and the keystore on a hand
/// rolled channel. The QR carries an `opentv://` address, so the system
/// camera app opens OpenTV with it and the app never touches the lens.
class HandoverOfferScreen extends StatefulWidget {
  const HandoverOfferScreen({
    super.key,
    required this.service,
    required this.touch,
  });

  final HandoverService service;

  /// Which set of type and spacing tokens to draw with.
  final bool touch;

  @override
  State<HandoverOfferScreen> createState() => _HandoverOfferScreenState();
}

class _HandoverOfferScreenState extends State<HandoverOfferScreen> {
  HandoverPairing? _pairing;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // The window closes with the screen. A server left listening is one
    // nobody knows is running, and it is holding every secret this device
    // has behind a key that was on screen a minute ago.
    widget.service.stop();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final address = await _localAddress();
      if (address == null) {
        setState(() => _failure =
            'This device is not on a network that another device can reach.');
        return;
      }
      final pairing = await widget.service.offer(host: address);
      if (mounted) setState(() => _pairing = pairing);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  /// The address another device on the same network can reach.
  ///
  /// Picked from the interfaces rather than asked of the platform, because
  /// neither Android nor Apple offers a straight answer and both would need a
  /// channel method to give one. Loopback is excluded, which is the whole
  /// trick: it is the address that always exists and never works.
  static Future<String?> _localAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pairing = _pairing;
    final failure = _failure;
    final title = widget.touch ? OpenTvTouchType.title : OpenTvType.title;
    final body = widget.touch ? OpenTvTouchType.bodyMuted : OpenTvType.bodyMuted;

    return Container(
      color: OpenTvColors.ground,
      padding: EdgeInsets.all(widget.touch ? OpenTvTouchSpace.gutter : 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Hand this setup to another device', style: title),
          SizedBox(height: widget.touch ? OpenTvTouchSpace.md : 24),
          Text(
            failure ??
                'Point the other device’s camera at this code. It will carry '
                    'your providers, their passwords, your catalogue and your '
                    'history — everything except what is playing right now.',
            style: body,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: widget.touch ? OpenTvTouchSpace.xl : 48),
          if (pairing != null) ...[
            QrPanel(
              data: pairing.encode(),
              size: widget.touch ? 260 : 360,
            ),
            SizedBox(height: widget.touch ? OpenTvTouchSpace.md : 24),
            Text(
              '${pairing.host}:${pairing.port}',
              style: widget.touch ? OpenTvTouchType.data : OpenTvType.data,
            ),
            SizedBox(height: widget.touch ? OpenTvTouchSpace.sm : 16),
            Text(
              'The code stops working when you leave this screen.',
              style: body,
              textAlign: TextAlign.center,
            ),
          ] else if (failure == null)
            Text('Opening…', style: body),
        ],
      ),
    );
  }
}

/// Taking a setup from the device that displayed the code.
class HandoverReceiveScreen extends StatefulWidget {
  const HandoverReceiveScreen({
    super.key,
    required this.service,
    required this.pairing,
    required this.onDone,
  });

  final HandoverService service;
  final HandoverPairing pairing;

  /// Called once the catalogue has been replaced, so the app can reopen it.
  final VoidCallback onDone;

  @override
  State<HandoverReceiveScreen> createState() => _HandoverReceiveScreenState();
}

class _HandoverReceiveScreenState extends State<HandoverReceiveScreen> {
  double _progress = 0;
  String? _failure;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await widget.service.receive(
        widget.pairing,
        onProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (!mounted) return;
      setState(() => _done = true);
      widget.onDone();
    } on HandoverException catch (error) {
      // The message is written for the viewer, not the log: a schema mismatch
      // says which versions and what to do about it.
      if (mounted) setState(() => _failure = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: 'Taking a setup',
      onBack: _done ? null : () => Navigator.of(context).maybePop(),
      body: Padding(
        padding: OpenTvTouchSpace.page,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_failure != null) ...[
              Text('It did not arrive', style: OpenTvTouchType.title),
              const SizedBox(height: OpenTvTouchSpace.sm),
              Text(_failure!, style: OpenTvTouchType.bodyMuted),
            ] else if (_done) ...[
              Text('Done', style: OpenTvTouchType.title),
              const SizedBox(height: OpenTvTouchSpace.sm),
              const Text(
                'This device now has the same providers, catalogue and '
                'history as the one you took it from.',
                style: OpenTvTouchType.bodyMuted,
              ),
            ] else ...[
              Text(
                'Copying from ${widget.pairing.host}',
                style: OpenTvTouchType.title,
              ),
              const SizedBox(height: OpenTvTouchSpace.lg),
              // Shown as a proportion rather than a spinner. A catalogue is
              // tens of megabytes over a home access point, and a transfer
              // with no visible progress is one people assume has hung and
              // cancel — which is the only way to end up with nothing after
              // waiting.
              ClipRRect(
                borderRadius: OpenTvRadius.tile,
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      const ColoredBox(color: OpenTvColors.rule),
                      FractionallySizedBox(
                        widthFactor: _progress.clamp(0.0, 1.0),
                        child: const ColoredBox(color: OpenTvColors.tally),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: OpenTvTouchSpace.sm),
              Text(
                '${(_progress * 100).round()}%',
                style: OpenTvTouchType.data,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

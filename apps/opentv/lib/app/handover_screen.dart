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
    this.onReceived,
  });

  final HandoverService service;

  /// Called when the other device pushed its setup here instead of taking
  /// this one. The catalogue on disk has been replaced by the time this runs.
  final Future<void> Function()? onReceived;

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
      final addresses = await _localAddresses();
      if (addresses.isEmpty) {
        setState(() => _failure =
            'This device is not on a network that another device can reach.');
        return;
      }
      final pairing = await widget.service.offer(
        hosts: addresses,
        onReceived: widget.onReceived,
      );
      if (mounted) setState(() => _pairing = pairing);
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  /// Every address another device might reach this one at.
  ///
  /// All of them, not the first. This device cannot know which of its own
  /// addresses the other one can get to: a television box commonly has
  /// Ethernet and Wi-Fi up at once, and this app can put a WireGuard tunnel
  /// on top of that. Offering only the first meant a phone that scanned the
  /// code sat at nought per cent against an address it could not route to,
  /// until a twenty-second timeout finally said so.
  ///
  /// Ordered with the likeliest first, so the receiver usually gets it on the
  /// first try: private LAN ranges before anything else, since a handover
  /// happens between two devices in one room.
  ///
  /// Read from the interfaces rather than asked of the platform, because
  /// neither Android nor Apple offers a straight answer and both would need a
  /// channel method to give one. Loopback is excluded, which is the whole
  /// trick: it is the address that always exists and never works.
  static Future<List<String>> _localAddresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final private = <String>[];
    final rest = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        (_isPrivate(address.address) ? private : rest).add(address.address);
      }
    }
    return [...private, ...rest];
  }

  /// Whether this looks like an address on somebody's own network.
  static bool _isPrivate(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    return a == 10 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31);
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
                'Point the other device’s camera at this code. It can then '
                    'take this setup, or send you its own — providers, their '
                    'passwords, the catalogue and your history.',
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
/// Which way the setup should travel.
enum HandoverDirection {
  /// Take the other device's setup and replace this one's.
  take,

  /// Send this device's setup to the other one.
  send,
}

class HandoverReceiveScreen extends StatefulWidget {
  const HandoverReceiveScreen({
    super.key,
    required this.service,
    required this.pairing,
    required this.onDone,
    required this.hasSetup,
  });

  final HandoverService service;
  final HandoverPairing pairing;

  /// Called once this device's catalogue has been replaced.
  final VoidCallback onDone;

  /// Whether this device has anything of its own to send.
  ///
  /// A phone that has just been installed has nothing, so it is not offered
  /// the choice — which is also the common case, and asking a question with
  /// one usable answer is not a choice.
  final bool hasSetup;

  @override
  State<HandoverReceiveScreen> createState() => _HandoverReceiveScreenState();
}

class _HandoverReceiveScreenState extends State<HandoverReceiveScreen> {
  double _progress = 0;
  String? _failure;
  bool _done = false;
  HandoverDirection? _direction;

  @override
  void initState() {
    super.initState();
    // Nothing here to send means there is no question to ask.
    if (!widget.hasSetup) _start(HandoverDirection.take);
  }

  void _start(HandoverDirection direction) {
    setState(() => _direction = direction);
    _run(direction);
  }

  Future<void> _run(HandoverDirection direction) async {
    try {
      if (direction == HandoverDirection.take) {
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
      } else {
        await widget.service.sendTo(
          widget.pairing,
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _progress = sent / total);
            }
          },
        );
        if (!mounted) return;
        // Nothing on this device changed, so onDone is deliberately not
        // called: reopening a database that was never replaced would drop the
        // viewer back to the top of the app for no reason.
        setState(() => _done = true);
      }
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
    final direction = _direction;
    if (direction == null) return _chooser();

    return TouchScaffold(
      title: direction == HandoverDirection.take
          ? 'Taking a setup'
          : 'Sending this setup',
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
              const SizedBox(height: OpenTvTouchSpace.md),
              Text(
                'It was looked for at ${widget.pairing.hosts.join(', ')} '
                'on port ${widget.pairing.port}. Both devices have to be on '
                'the same network, and the other one has to still be showing '
                'the code.',
                style: OpenTvTouchType.caption,
              ),
              const SizedBox(height: OpenTvTouchSpace.xl),
              // A failure with no way forward is a dead end. The commonest
              // cause is a code that had already expired, and trying again is
              // free.
              TouchTile(
                onTap: () {
                  setState(() {
                    _failure = null;
                    _progress = 0;
                  });
                  _run(direction);
                },
                minHeight: 50,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OpenTvColors.tally,
                    borderRadius: OpenTvRadius.tile,
                  ),
                  child: Text(
                    'Try again',
                    style: OpenTvTouchType.section
                        .copyWith(color: OpenTvColors.ground),
                  ),
                ),
              ),
            ] else if (_done) ...[
              Text('Done', style: OpenTvTouchType.title),
              const SizedBox(height: OpenTvTouchSpace.sm),
              Text(
                direction == HandoverDirection.take
                    ? 'This device now has the same providers, catalogue and '
                        'history as the one you took it from.'
                    : 'The other device now has the same providers, catalogue '
                        'and history as this one.',
                style: OpenTvTouchType.bodyMuted,
              ),
            ] else ...[
              Text(
                direction == HandoverDirection.take
                    ? 'Copying from ${widget.pairing.host}'
                    : 'Copying to ${widget.pairing.host}',
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

extension on _HandoverReceiveScreenState {
  /// Which way, asked only when both answers are real.
  ///
  /// Worded as what happens to each device rather than as "send" and
  /// "receive", which are the same word from two ends and get picked wrong.
  Widget _chooser() {
    return TouchScaffold(
      title: 'Which way?',
      onBack: () => Navigator.of(context).maybePop(),
      body: Padding(
        padding: OpenTvTouchSpace.page,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Choice(
              title: 'Take the other device’s setup',
              detail: 'Replaces the providers and catalogue on this device.',
              onTap: () => _start(HandoverDirection.take),
            ),
            const SizedBox(height: OpenTvTouchSpace.md),
            _Choice(
              title: 'Send this device’s setup',
              detail: 'Replaces the providers and catalogue on the other one.',
              onTap: () => _start(HandoverDirection.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TouchTile(
      onTap: onTap,
      minHeight: 76,
      child: Container(
        padding: const EdgeInsets.all(OpenTvTouchSpace.lg),
        decoration: BoxDecoration(
          color: OpenTvColors.surface,
          borderRadius: OpenTvRadius.tile,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: OpenTvTouchType.section),
            const SizedBox(height: OpenTvTouchSpace.xs),
            Text(detail, style: OpenTvTouchType.caption),
          ],
        ),
      ),
    );
  }
}

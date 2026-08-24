import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'host.dart';
import 'settings_screen.dart';
import 'source_service.dart';
import 'vpn_service.dart';

/// The television, waiting for somebody's phone.
///
/// Everything here is the same setup the remote offers; the only difference
/// is where it is typed. What the screen has to do well is state the trade
/// honestly — this is a password crossing a local network in the clear — and
/// give the two things a browser needs: an address and a code.
class PhoneSetupScreen extends StatefulWidget {
  const PhoneSetupScreen({
    super.key,
    required this.service,
    required this.onDone,
    required this.onCancel,
    this.host = const Host(),
  });

  final SourceService service;

  /// Called once a provider has been added and its catalogue read.
  final VoidCallback onDone;

  final VoidCallback onCancel;
  final Host host;

  @override
  State<PhoneSetupScreen> createState() => _PhoneSetupScreenState();
}

class _PhoneSetupScreenState extends State<PhoneSetupScreen> {
  final _server = SetupServer();

  StreamSubscription<SetupSubmission>? _incoming;
  StreamSubscription<String>? _closing;

  bool _starting = true;
  String? _problem;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _incoming?.cancel();
    _closing?.cancel();
    // The window closes with the screen. A server left running because a
    // viewer wandered off is the thing this design is trying not to be.
    unawaited(_server.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final started = await _server.start();
    if (!mounted) return;

    if (!started) {
      setState(() {
        _starting = false;
        _problem =
            'This television is not on a network, so there is nowhere to '
            'serve the page. Connect it to your wifi and try again.';
      });
      return;
    }

    _incoming = _server.submissions.listen(_accept);
    _closing = _server.closed.listen((reason) {
      if (mounted && !_working) setState(() => _problem = reason);
    });

    setState(() => _starting = false);
  }

  Future<void> _accept(SetupSubmission submission) async {
    setState(() {
      _working = true;
      _problem = null;
    });

    // The optional things first, and separately. They are independent of the
    // provider, so a portal that refuses should not also throw away a TMDB
    // key somebody just typed correctly.
    final tmdb = submission.tmdbKey;
    if (tmdb != null) {
      await widget.host.writeSecret(SettingsScreen.tmdbReference, tmdb);
    }
    final tunnel = submission.wireGuardConfig;
    if (tunnel != null) {
      await VpnService(host: widget.host).save(tunnel);
    }

    _server.report(SetupPhase.working, 'Reading the catalogue…');

    final failure = await widget.service.add(
      OnboardingDraft(
        kind: submission.kind == SourceKind.m3u
            ? OnboardingSourceKind.m3u
            : OnboardingSourceKind.xtream,
        name: submission.name,
        url: submission.url,
        // Empty rather than null: the draft treats an absent credential as
        // an empty string, which is what an M3U playlist has.
        username: submission.username ?? '',
        password: submission.password ?? '',
      ),
    );

    if (!mounted) return;

    if (failure != null) {
      // Handed back to the browser rather than only shown here: the person
      // who can fix a wrong password is the one holding the phone, and they
      // may not be looking at the television.
      _server.report(SetupPhase.failed, failure);
      setState(() {
        _working = false;
        _problem = failure;
      });
      return;
    }

    _server.report(SetupPhase.done);
    // A moment before closing, so the browser's next poll sees the finished
    // page rather than a refused connection.
    await Future<void>.delayed(const Duration(seconds: 2));
    await _server.stop('Setup finished.');
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      padding: OpenTvSpace.safe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _body()),
          const ContentDisclaimer(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_starting) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Opening the setup window…', style: OpenTvType.body),
      );
    }

    if (_working) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Reading the catalogue', style: OpenTvType.hero),
          const SizedBox(height: OpenTvSpace.sm),
          ValueListenableBuilder<String>(
            valueListenable: widget.service.progress,
            builder: (context, text, _) => Text(
              text,
              style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
            ),
          ),
        ],
      );
    }

    final address = _server.address;
    final code = _server.pairingCode;

    if (address == null || code == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('The setup window is closed', style: OpenTvType.hero),
          const SizedBox(height: OpenTvSpace.sm),
          SizedBox(
            width: 1100,
            child: Text(
              _problem ?? 'It can be opened again from the previous screen.',
              style: OpenTvType.bodyMuted,
            ),
          ),
          const SizedBox(height: OpenTvSpace.lg),
          Row(
            children: [
              PlayerButton(
                label: 'TRY AGAIN',
                emphasis: true,
                autofocus: true,
                onSelect: () {
                  setState(() {
                    _starting = true;
                    _problem = null;
                  });
                  _open();
                },
              ),
              const SizedBox(width: OpenTvSpace.sm),
              PlayerButton(label: 'BACK', onSelect: widget.onCancel),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('On your phone', style: OpenTvType.hero),
        const SizedBox(height: OpenTvSpace.md),

        _Step(
          number: 1,
          label: 'Open this address in a browser',
          value: address,
        ),
        const SizedBox(height: OpenTvSpace.md),
        _Step(number: 2, label: 'Enter this code', value: code, wide: true),

        const SizedBox(height: OpenTvSpace.lg),
        SizedBox(
          width: 1200,
          child: Text(
            // Said plainly. Somebody is about to type a provider password
            // into a page served over plain HTTP, and they are entitled to
            // know that before they do rather than after.
            'Your phone must be on the same network as this television. What '
            'you type there — including your provider password — crosses '
            'that network unencrypted, so do this on a network you trust '
            'rather than a shared or public one. The window closes as soon '
            'as setup finishes, and in ${_server.lifetime.inMinutes} minutes '
            'either way.',
            style: OpenTvType.bodyMuted,
          ),
        ),

        if (_problem != null) ...[
          const SizedBox(height: OpenTvSpace.sm),
          SizedBox(
            width: 1200,
            child: Text(
              _problem!,
              style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
            ),
          ),
        ],

        const SizedBox(height: OpenTvSpace.lg),
        PlayerButton(
          label: 'CANCEL',
          autofocus: true,
          onSelect: widget.onCancel,
        ),
      ],
    );
  }
}

/// One instruction, with the thing to type set apart from the words.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.value,
    this.wide = false,
  });

  final int number;
  final String label;
  final String value;

  /// Set for the code, which is read a character at a time across a room.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            '$number',
            style: OpenTvType.section.copyWith(color: OpenTvColors.tally),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: OpenTvType.label),
            const SizedBox(height: OpenTvSpace.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvSpace.md,
                vertical: OpenTvSpace.sm,
              ),
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
                border: Border.all(color: OpenTvColors.rule),
              ),
              child: Text(
                value,
                style: OpenTvType.hero.copyWith(
                  fontFamily: OpenTvType.mono,
                  color: OpenTvColors.ink,
                  letterSpacing: wide ? 12 : 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

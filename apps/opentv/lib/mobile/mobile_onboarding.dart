import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'touch_field.dart';

/// Adding a provider, on a device with a keyboard.
///
/// The television's version of this screen is a sequence: one field at a time,
/// filled with a drawn keyboard, because a remote can only ever be on one
/// field and typing is the expensive part. None of that is true here. A phone
/// shows the whole form at once, the system keyboard is the right keyboard,
/// and the browser-setup escape hatch that exists on the television is absent
/// — it was only ever an answer to typing on a remote.
class MobileOnboarding extends StatefulWidget {
  const MobileOnboarding({
    super.key,
    required this.onSubmit,
    this.onCancel,
    this.onTakeFromDevice,
    this.onSaveTunnel,
    this.progress,
  });

  /// Returns a reason it failed, or null when the provider was added.
  final Future<String?> Function(OnboardingDraft) onSubmit;

  /// Stores a WireGuard configuration, returning what is wrong with it.
  ///
  /// Offered here, before the provider, because some portals answer only from
  /// inside a tunnel: they hand out a separate host for VPN access and that
  /// host is silent on an ordinary connection. Setting the tunnel up
  /// afterwards in settings cannot help, because there is no afterwards — the
  /// sign-in that would get you there is the request that fails.
  ///
  /// Null on a platform with no tunnel of its own, which hides the section
  /// rather than offering a field that could not do anything.
  final Future<String?> Function(String)? onSaveTunnel;

  final VoidCallback? onCancel;

  /// Starts a handover instead of typing anything.
  ///
  /// Offered here rather than only in settings, because this is the screen
  /// where somebody has a second device already set up and is about to type
  /// its provider address by hand for no reason.
  final VoidCallback? onTakeFromDevice;
  final ValueListenable<String>? progress;

  @override
  State<MobileOnboarding> createState() => _MobileOnboardingState();
}

class _MobileOnboardingState extends State<MobileOnboarding> {
  var _kind = OnboardingSourceKind.xtream;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    // The button's enabled state is computed from these, so the screen has to
    // rebuild when they change. Without this it was evaluated once against
    // empty fields and never again — every field could be filled and "Add
    // provider" stayed dead.
    for (final c in [_name, _url, _username, _password]) {
      c.addListener(_onEdited);
    }
  }

  void _onEdited() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _url, _username, _password]) {
      c
        ..removeListener(_onEdited)
        ..dispose();
    }
    super.dispose();
  }

  bool get _ready {
    if (_url.text.trim().isEmpty) return false;
    if (_kind == OnboardingSourceKind.xtream) {
      return _username.text.trim().isNotEmpty && _password.text.isNotEmpty;
    }
    return true;
  }

  /// Whether the tunnel field is showing.
  ///
  /// Folded away by default. Most providers need nothing here, and a
  /// WireGuard configuration is the largest field on the screen — open, it
  /// reads as something everybody has to fill in.
  bool _showingTunnel = false;
  final _tunnel = TextEditingController();

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });

    // Saved before the provider is submitted, and only saved — bringing it up
    // belongs to the one place that knows a portal is about to be asked
    // something, so that it happens on every route into this rather than only
    // this one.
    final tunnel = _tunnel.text.trim();
    if (tunnel.isNotEmpty && widget.onSaveTunnel != null) {
      final wrong = await widget.onSaveTunnel!(tunnel);
      if (!mounted) return;
      if (wrong != null) {
        setState(() {
          _busy = false;
          _problem = wrong;
        });
        return;
      }
    }

    final failure = await widget.onSubmit(
      OnboardingDraft(
        kind: _kind,
        url: _url.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final xtream = _kind == OnboardingSourceKind.xtream;

    return TouchScaffold(
      title: 'Add a provider',
      onBack: widget.onCancel,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OpenTvTouchSpace.gutter,
          0,
          OpenTvTouchSpace.gutter,
          OpenTvTouchSpace.xxl,
        ),
        children: [
          const Text(
            'OpenTV supplies no channels, films or playlists. Everything you '
            'see in it comes from a provider you choose and an address you '
            'enter.',
            style: OpenTvTouchType.bodyMuted,
          ),
          if (widget.onTakeFromDevice != null) ...[
            const SizedBox(height: OpenTvTouchSpace.xl),
            // Drawn as a button rather than a panel with a tappable
            // surface. It read as a notice, which is why it was not obvious
            // it did anything — the strongest thing on this screen should be
            // the path that involves no typing at all.
            TouchTile(
              onTap: widget.onTakeFromDevice,
              minHeight: 72,
              child: Container(
                padding: const EdgeInsets.all(OpenTvTouchSpace.lg),
                decoration: BoxDecoration(
                  color: OpenTvColors.tally,
                  borderRadius: OpenTvRadius.tile,
                ),
                child: Row(
                  children: [
                    const GlyphIcon(
                      Glyph.search,
                      size: 22,
                      color: OpenTvColors.ground,
                    ),
                    const SizedBox(width: OpenTvTouchSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Scan another device',
                            style: OpenTvTouchType.section
                                .copyWith(color: OpenTvColors.ground),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Take its providers, passwords, catalogue and '
                            'history. Nothing to type.',
                            style: OpenTvTouchType.caption
                                .copyWith(color: const Color(0xCC07090C)),
                          ),
                        ],
                      ),
                    ),
                    Transform.flip(
                      flipX: Directionality.of(context) == TextDirection.rtl,
                      child: Transform.rotate(
                        angle: 3.14159,
                        child: const GlyphIcon(
                          Glyph.back,
                          size: 18,
                          color: OpenTvColors.ground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: OpenTvTouchSpace.xl),
            const Text('OR ADD ONE BY HAND', style: OpenTvTouchType.label),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          _Segmented(
            selected: xtream ? 0 : 1,
            labels: const ['Xtream Codes', 'M3U playlist'],
            onSelect: (i) => setState(() {
              _kind = i == 0
                  ? OnboardingSourceKind.xtream
                  : OnboardingSourceKind.m3u;
            }),
          ),
          const SizedBox(height: OpenTvTouchSpace.xl),
          TouchField(
            label: xtream ? 'Portal address' : 'Playlist address',
            hint: 'http://example.com:8080',
            controller: _url,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
          ),
          if (xtream) ...[
            TouchField(
              label: 'Username',
              controller: _username,
              textInputAction: TextInputAction.next,
              enabled: !_busy,
            ),
            TouchField(
              label: 'Password',
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.next,
              enabled: !_busy,
            ),
          ],
          TouchField(
            label: 'Name',
            hint: 'What you call this provider',
            controller: _name,
            onSubmitted: (_) => _submit(),
            enabled: !_busy,
          ),
          if (widget.onSaveTunnel != null) ...[
            const SizedBox(height: OpenTvTouchSpace.md),
            TouchTile(
              onTap: _busy
                  ? null
                  : () => setState(() => _showingTunnel = !_showingTunnel),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: OpenTvTouchSpace.sm,
                ),
                child: Text(
                  _showingTunnel
                      ? 'My provider does not need a VPN'
                      : 'My provider needs a VPN',
                  style: OpenTvTouchType.body.copyWith(
                    color: OpenTvColors.tally,
                  ),
                ),
              ),
            ),
            if (_showingTunnel) ...[
              const SizedBox(height: OpenTvTouchSpace.xs),
              // "the portal address" rather than "the address above": this
              // sits below the fields today and a direction is a claim about
              // the layout that stops being true the moment anything moves.
              const Text(
                'Some providers give out a different portal address that only '
                'answers over their VPN. Paste the WireGuard .conf they gave '
                'you and it will be carrying traffic before the portal address '
                'is tried.',
                style: OpenTvTouchType.caption,
              ),
              // Not masked, unlike the television's. `TouchField` refuses to
              // obscure a multiline field — Flutter cannot — and a phone is
              // held at arm's length rather than watched across a room, which
              // is the reason the television masks its copy at all.
              TouchField(
                label: 'WireGuard configuration',
                hint: 'Paste the .conf your provider gave you',
                controller: _tunnel,
                multiline: true,
                enabled: !_busy,
              ),
            ],
          ],
          if (_problem != null) ...[
            const SizedBox(height: OpenTvTouchSpace.md),
            Text(
              _problem!,
              style: OpenTvTouchType.body.copyWith(color: OpenTvColors.alert),
            ),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          if (_busy) ...[
            const TouchProgressBar(),
            const SizedBox(height: OpenTvTouchSpace.md),
            if (widget.progress case final progress?)
              ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (context, stage, _) => Text(
                  stage,
                  style: OpenTvTouchType.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: OpenTvTouchSpace.xs),
            const Text(
              'Reading the whole catalogue. A large provider takes a few '
              'minutes; leaving this screen stops it.',
              style: OpenTvTouchType.caption,
              textAlign: TextAlign.center,
            ),
          ] else
            _Primary(
              label: 'Add provider',
              onTap: _ready ? _submit : null,
            ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: OpenTvColors.surface,
        borderRadius: OpenTvRadius.tile,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: TouchTile(
                onTap: () => onSelect(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? OpenTvColors.surfaceLifted
                        : null,
                    borderRadius: OpenTvRadius.tile,
                    border: i == selected
                        ? const Border(
                            bottom: BorderSide(
                              color: OpenTvColors.tally,
                              width: 2,
                            ),
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: OpenTvTouchType.section.copyWith(
                      color: i == selected
                          ? OpenTvColors.ink
                          : OpenTvColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Primary extends StatelessWidget {
  const _Primary({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return TouchTile(
      onTap: onTap,
      minHeight: 52,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? OpenTvColors.tally : OpenTvColors.surface,
          borderRadius: OpenTvRadius.tile,
        ),
        child: Text(
          label,
          style: OpenTvTouchType.section.copyWith(
            color: enabled ? OpenTvColors.ground : OpenTvColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

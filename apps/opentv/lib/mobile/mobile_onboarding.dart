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
    this.progress,
  });

  /// Returns a reason it failed, or null when the provider was added.
  final Future<String?> Function(OnboardingDraft) onSubmit;

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

  Future<void> _submit() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
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
          ),
          if (xtream) ...[
            TouchField(
              label: 'Username',
              controller: _username,
              textInputAction: TextInputAction.next,
            ),
            TouchField(
              label: 'Password',
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.next,
            ),
          ],
          TouchField(
            label: 'Name',
            hint: 'What you call this provider',
            controller: _name,
            onSubmitted: (_) => _submit(),
          ),
          if (_problem != null) ...[
            const SizedBox(height: OpenTvTouchSpace.md),
            Text(
              _problem!,
              style: OpenTvTouchType.body.copyWith(color: OpenTvColors.alert),
            ),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          if (_busy && widget.progress != null)
            ValueListenableBuilder<String>(
              valueListenable: widget.progress!,
              builder: (context, stage, _) => Text(
                stage,
                style: OpenTvTouchType.bodyMuted,
                textAlign: TextAlign.center,
              ),
            )
          else
            _Primary(
              label: _busy ? 'Working…' : 'Add provider',
              onTap: _ready && !_busy ? _submit : null,
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

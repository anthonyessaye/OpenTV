import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/vpn_service.dart';

/// The WireGuard tunnel, on a phone.
///
/// Android only, and the reason is stated on screen rather than hidden behind
/// a control that fails: iOS needs a Network Extension, which needs a paid
/// developer account to sign. That is the same answer the television gives for
/// tvOS, and the same one it gives out loud.
///
/// The configuration is pasted rather than typed, which is the one place a
/// phone is unambiguously better than a remote — a `.conf` is several lines
/// and a private key is 44 characters of base64.
class MobileTunnelScreen extends StatefulWidget {
  const MobileTunnelScreen({super.key, required this.vpn});

  final VpnService vpn;

  @override
  State<MobileTunnelScreen> createState() => _MobileTunnelScreenState();
}

class _MobileTunnelScreenState extends State<MobileTunnelScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _configured = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    final stored = await widget.vpn.stored();
    if (mounted) setState(() => _configured = stored != null);
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final failure = await widget.vpn.save(text);
    if (!mounted) return;
    if (failure != null) {
      setState(() => _note = failure);
      return;
    }
    _controller.clear();
    setState(() {
      _configured = true;
      _note = 'Saved.';
    });
    await _read();
  }

  Future<void> _forget() async {
    await widget.vpn.forget();
    if (mounted) {
      setState(() {
        _configured = false;
        _note = 'Removed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.vpn.isSupported) {
      return TouchScaffold(
        title: 'Private tunnel',
        onBack: () => Navigator.of(context).maybePop(),
        body: const Padding(
          padding: EdgeInsets.all(OpenTvTouchSpace.gutter),
          child: Text(
            'Not on this platform. A tunnel on iOS needs a Network Extension, '
            'which needs a paid Apple developer account to sign — so there is '
            'no switch here rather than one that fails.',
            style: OpenTvTouchType.bodyMuted,
          ),
        ),
      );
    }

    return TouchScaffold(
      title: 'Private tunnel',
      onBack: () => Navigator.of(context).maybePop(),
      body: ValueListenableBuilder<VpnState>(
        valueListenable: widget.vpn.state,
        builder: (context, state, _) => ListView(
          padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
          children: [
            // Stated plainly, because the honest description is not the one
            // people expect. A tunnel moves who can see your traffic; it does
            // not make it private.
            const Text(
              'A WireGuard tunnel moves who can see this device’s traffic — '
              'your network and your provider stop seeing it, and whoever '
              'runs the tunnel starts. That is a different arrangement, not a '
              'private one.',
              style: OpenTvTouchType.bodyMuted,
            ),
            const SizedBox(height: OpenTvTouchSpace.xl),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: switch (state) {
                      VpnState.up => OpenTvColors.onAir,
                      VpnState.connecting => OpenTvColors.tally,
                      _ => OpenTvColors.inkFaint,
                    },
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: OpenTvTouchSpace.sm),
                Text(
                  switch (state) {
                    VpnState.up => 'CARRYING TRAFFIC',
                    VpnState.connecting => 'CONNECTING',
                    VpnState.down =>
                      _configured ? 'CONFIGURED, DOWN' : 'NOT CONFIGURED',
                  },
                  style: OpenTvTouchType.label,
                ),
              ],
            ),
            const SizedBox(height: OpenTvTouchSpace.xl),
            const Text('PASTE A .CONF', style: OpenTvTouchType.label),
            const SizedBox(height: OpenTvTouchSpace.xs),
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(OpenTvTouchSpace.md),
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
              ),
              child: EditableText(
                controller: _controller,
                focusNode: _focus,
                style: OpenTvTouchType.data.copyWith(color: OpenTvColors.ink),
                cursorColor: OpenTvColors.tally,
                backgroundCursorColor: OpenTvColors.inkFaint,
                // A .conf is several lines and means nothing flattened into
                // one, so a field that swallowed its newlines would store a
                // broken configuration with no sign that it had.
                maxLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: OpenTvTouchSpace.sm),
              Text(_note!, style: OpenTvTouchType.caption),
            ],
            const SizedBox(height: OpenTvTouchSpace.lg),
            _Button(label: 'Save', emphasis: true, onTap: _save),
            if (_configured) ...[
              const SizedBox(height: OpenTvTouchSpace.sm),
              _Button(
                label: state == VpnState.up ? 'Disconnect' : 'Connect',
                onTap: () async {
                  if (state == VpnState.up) {
                    await widget.vpn.disconnect();
                  } else {
                    final failure = await widget.vpn.connect();
                    if (failure != null && mounted) {
                      setState(() => _note = failure);
                    }
                  }
                },
              ),
              const SizedBox(height: OpenTvTouchSpace.sm),
              _Button(label: 'Forget it', danger: true, onTap: _forget),
            ],
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.emphasis = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasis;
  final bool danger;

  @override
  Widget build(BuildContext context) => TouchTile(
        onTap: onTap,
        minHeight: 48,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: emphasis ? OpenTvColors.tally : OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
          ),
          child: Text(
            label,
            style: OpenTvTouchType.section.copyWith(
              color: emphasis
                  ? OpenTvColors.ground
                  : danger
                      ? OpenTvColors.alert
                      : OpenTvColors.ink,
            ),
          ),
        ),
      );
}

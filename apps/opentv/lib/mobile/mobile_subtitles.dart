import 'package:flutter/widgets.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/host.dart';
import '../app/subtitle_service.dart';
import 'touch_field.dart';

/// Where downloaded subtitles come from, and what it costs.
///
/// Every viewer brings their own key, and that is a decision rather than an
/// omission. This app ships no credentials of any kind — there is no TMDB key
/// in it either — and a service key compiled into an open-source client is a
/// key that lasts exactly as long as it takes somebody to read the source,
/// after which every viewer's daily allowance is spent by strangers.
///
/// Its own screen rather than the generic secret one, for the reason the
/// parental panel needed its own: a key with no instructions beside it is a
/// field somebody closes again. The tunnel screen sets the same precedent —
/// it explains what a tunnel does and does not do before offering the box.
class MobileSubtitlesScreen extends StatefulWidget {
  const MobileSubtitlesScreen({super.key, this.host = const Host()});

  final Host host;

  @override
  State<MobileSubtitlesScreen> createState() => _MobileSubtitlesScreenState();
}

class _MobileSubtitlesScreenState extends State<MobileSubtitlesScreen> {
  final _controller = TextEditingController();
  bool _stored = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    // Whether one exists, never what it is. A settings screen that renders a
    // stored secret back is one that shows it to whoever is looking over your
    // shoulder.
    final existing = await widget.host.readSecret(SubtitleService.keyReference);
    if (mounted) setState(() => _stored = existing != null);
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await widget.host.writeSecret(SubtitleService.keyReference, value);
    _controller.clear();
    if (mounted) {
      setState(() {
        _stored = true;
        _note = 'Saved.';
      });
    }
  }

  Future<void> _remove() async {
    await widget.host.deleteSecret(SubtitleService.keyReference);
    if (mounted) {
      setState(() {
        _stored = false;
        _note = 'Removed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: 'Subtitles',
      onBack: () => Navigator.of(context).maybePop(),
      body: ListView(
        padding: OpenTvTouchSpace.page,
        children: [
          const Text(
            'Providers often ship no subtitles at all, or ones timed against '
            'a different cut. With a key, the player can look for others and '
            'load one over the stream.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.lg),
          const Text('HOW TO GET A KEY', style: OpenTvTouchType.label),
          const SizedBox(height: OpenTvTouchSpace.xs),
          const Text(
            '1.  Make a free account at opensubtitles.com.\n'
            '2.  Open the profile menu and choose “API consumers”.\n'
            '3.  Create a consumer — any name will do — and copy its API key.\n'
            '4.  Paste it below.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.lg),
          Text(
            _stored ? 'A key is stored on this device.' : 'No key is stored.',
            style: OpenTvTouchType.data,
          ),
          const SizedBox(height: OpenTvTouchSpace.md),
          TouchField(
            label: 'OpenSubtitles API key',
            controller: _controller,
            hint: 'Paste from opensubtitles.com',
            obscure: true,
            onSubmitted: (_) => _save(),
          ),
          if (_note case final note?) ...[
            Text(note, style: OpenTvTouchType.caption),
            const SizedBox(height: OpenTvTouchSpace.sm),
          ],
          _Button(label: 'Save', emphasis: true, onTap: _save),
          if (_stored) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            _Button(label: 'Remove key', onTap: _remove),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          const Text(
            'A free account allows a small number of downloads a day, and '
            'signing in on the site raises it. Anything downloaded is kept '
            'only while it is being watched and is deleted afterwards — a '
            'subtitle is fetched because this stream needed one, and the '
            'provider may have fixed its own by tomorrow.',
            style: OpenTvTouchType.caption,
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    this.emphasis = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasis;

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
              color: emphasis ? OpenTvColors.ground : OpenTvColors.ink,
            ),
          ),
        ),
      );
}

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'host.dart';
import 'settings_screen.dart';

/// The three questions worth asking once, straight after the first import.
///
/// All three were reachable in settings already, and none of them were being
/// found there. That is the usual fate of an optional setting: it changes
/// something a viewer would have wanted changed, and they never learn it
/// exists, so the app they use is worse than the app they installed.
///
/// Asked here because this is the one moment they are all answerable — the
/// catalogue has just arrived, so the categories to hide are known, and the
/// viewer is already in a setting-things-up frame of mind rather than trying
/// to watch something.
///
/// Every step skips, and skipping is a plain choice rather than a small grey
/// escape. A parental PIN is not something to press someone into, an
/// unwatched provider needs no categories hidden, and a TMDB key is an
/// account on somebody else's website.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.db,
    required this.source,
    required this.onDone,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final Source source;
  final VoidCallback onDone;
  final Host host;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _Step { metadata, parental, hidden }

class _SetupScreenState extends State<SetupScreen> {
  _Step _step = _Step.metadata;

  String _tmdbKey = '';
  String _pin = '';
  String? _problem;
  bool _busy = false;

  List<({Category category, ItemKind kind})> _categories = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await widget.host.readSecret(SettingsScreen.tmdbReference);
    final pin = await widget.host.readSecret(SettingsScreen.pinReference);

    final categories = <({Category category, ItemKind kind})>[];
    for (final kind in [ItemKind.live, ItemKind.movie, ItemKind.series]) {
      final rows = await widget.db.allCategoriesFor(widget.source.id, kind);
      categories.addAll([for (final row in rows) (category: row, kind: kind)]);
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      // A step with nothing left to decide is not shown. Someone adding a
      // second provider has already answered the first two, and asking again
      // reads as the app having forgotten.
      if (existing != null && existing.isNotEmpty) {
        _step = (pin != null && pin.isNotEmpty) ? _Step.hidden : _Step.parental;
      } else if (pin != null && pin.isNotEmpty && _step == _Step.parental) {
        _step = _Step.hidden;
      }
    });
  }

  void _next() {
    setState(() {
      _problem = null;
      _step = switch (_step) {
        _Step.metadata => _Step.parental,
        _Step.parental => _Step.hidden,
        _Step.hidden => _Step.hidden,
      };
    });
    if (_step == _Step.hidden && _categories.isEmpty) widget.onDone();
  }

  Future<void> _saveKey() async {
    if (_tmdbKey.trim().isEmpty) return;
    setState(() => _busy = true);
    await widget.host.writeSecret(
      SettingsScreen.tmdbReference,
      _tmdbKey.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  Future<void> _savePin() async {
    if (_pin.length < 4) {
      setState(() => _problem = 'Four digits or more.');
      return;
    }
    setState(() => _busy = true);
    await widget.host.writeSecret(SettingsScreen.pinReference, _pin);
    if (!mounted) return;
    setState(() => _busy = false);
    _next();
  }

  Future<void> _toggle(({Category category, ItemKind kind}) entry) async {
    await widget.db.setCategoryHidden(
      widget.source.id,
      entry.kind,
      entry.category.remoteId,
      !entry.category.hidden,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      padding: OpenTvSpace.safe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: OpenTvColors.tally),
              const SizedBox(width: OpenTvSpace.xs),
              Text(
                'SETTING UP  ·  ${_step.index + 1} OF 3',
                style: OpenTvType.label.copyWith(color: OpenTvColors.tally),
              ),
            ],
          ),
          const SizedBox(height: OpenTvSpace.sm),
          Expanded(
            child: switch (_step) {
              _Step.metadata => _metadata(),
              _Step.parental => _parental(),
              _Step.hidden => _hidden(),
            },
          ),
        ],
      ),
    );
  }

  Widget _metadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Artwork and descriptions', style: OpenTvType.section),
        const SizedBox(height: OpenTvSpace.xs),
        const SizedBox(
          width: 1100,
          child: Text(
            'Your provider sends film and series names, and usually a poster. '
            'It does not send a synopsis, a cast list or a rating. TMDB does, '
            'free, and OpenTV will ask it for them if you give it a key.',
            style: OpenTvType.bodyMuted,
          ),
        ),
        const SizedBox(height: OpenTvSpace.md),

        // Written out rather than linked. A television cannot open a browser,
        // and the viewer will be doing this on a phone in their other hand.
        const _Instructions([
          'On a phone or a computer, go to themoviedb.org and create a free '
              'account.',
          'Open Settings, then API, and request an API key. Choose the '
              'developer option; personal use is accepted.',
          'Copy the key labelled "API Read Access Token" or "API Key (v3 '
              'auth)". Either works.',
          'Type it below, or select the field and type from your phone.',
        ]),
        const SizedBox(height: OpenTvSpace.md),

        SizedBox(
          width: 1100,
          child: TextEntryField(
            label: 'TMDB API key',
            value: _tmdbKey,
            hint: 'Paste from themoviedb.org',
            active: true,
            obscure: true,
            onChanged: (text) => setState(() => _tmdbKey = text),
            onDone: _saveKey,
          ),
        ),
        const SizedBox(height: OpenTvSpace.md),
        Row(
          children: [
            PlayerButton(
              label: 'SAVE AND CONTINUE',
              emphasis: true,
              onSelect: _tmdbKey.trim().isEmpty || _busy ? null : _saveKey,
            ),
            const SizedBox(width: OpenTvSpace.sm),
            PlayerButton(
              label: 'SKIP — NAMES ONLY',
              autofocus: true,
              onSelect: _next,
            ),
          ],
        ),
        const SizedBox(height: OpenTvSpace.sm),
        const Text(
          'You can add or change this later in Settings, under Metadata.',
          style: OpenTvType.bodyMuted,
        ),
      ],
    );
  }

  Widget _parental() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('A PIN for the things you lock', style: OpenTvType.section),
        const SizedBox(height: OpenTvSpace.xs),
        // Kept to two lines on purpose. This step has to hold a keyboard as
        // well, and the keyboard is five hundred pixels tall — the first
        // draft of this paragraph ran to five lines and pushed the bottom
        // row of keys off the screen.
        const SizedBox(
          width: 1400,
          child: Text(
            'A provider catalogue arrives whole, adult categories included, '
            'and nothing in it is marked. A PIN lets you lock categories so '
            'they disappear from browsing and search until it is entered.',
            style: OpenTvType.bodyMuted,
          ),
        ),
        const SizedBox(height: OpenTvSpace.sm),
        SizedBox(
          width: 700,
          child: TextEntryField(
            label: 'New PIN',
            value: _pin,
            obscure: true,
            active: true,
            hint: 'Four digits or more',
            problem: _problem,
          ),
        ),
        const SizedBox(height: OpenTvSpace.sm),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TvKeyboard(
                  autofocus: true,
                  onKey: (character) => setState(() => _pin += character),
                  onDelete: () => setState(() {
                    if (_pin.isNotEmpty) {
                      _pin = _pin.substring(0, _pin.length - 1);
                    }
                  }),
                  doneLabel: 'SET PIN',
                  onDone: _pin.length >= 4 && !_busy ? _savePin : null,
                ),
                const SizedBox(width: OpenTvSpace.lg),
                PlayerButton(label: 'SKIP — NO PIN', onSelect: _next),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _hidden() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anything you would rather not see', style: OpenTvType.section),
        const SizedBox(height: OpenTvSpace.xs),
        const SizedBox(
          width: 1100,
          child: Text(
            'Providers carry hundreds of categories, most of them for '
            'somebody else — other countries, other languages, sports you do '
            'not follow. Hiding one removes it from browsing and search. It '
            'stays in the catalogue, so favourites and history survive, and '
            'you can bring it back at any time.',
            style: OpenTvType.bodyMuted,
          ),
        ),
        const SizedBox(height: OpenTvSpace.md),
        Expanded(
          child: _categories.isEmpty
              ? const Text(
                  'This provider sent no categories to hide.',
                  style: OpenTvType.bodyMuted,
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final entry = _categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _HideRow(
                        name: entry.category.name,
                        kind: switch (entry.kind) {
                          ItemKind.live => 'Channels',
                          ItemKind.movie => 'Films',
                          ItemKind.series => 'Series',
                          // Episodes have no categories of their own; they
                          // inherit their series'. Nothing reaches this.
                          ItemKind.episode => 'Episodes',
                        },
                        hidden: entry.category.hidden,
                        autofocus: index == 0,
                        onToggle: () => _toggle(entry),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: OpenTvSpace.md),
        PlayerButton(
          label: 'FINISH',
          emphasis: true,
          autofocus: _categories.isEmpty,
          onSelect: widget.onDone,
        ),
      ],
    );
  }
}

/// Numbered steps, for something the viewer does on another device.
class _Instructions extends StatelessWidget {
  const _Instructions(this.steps);

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: OpenTvSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${index + 1}',
                      style: OpenTvType.data.copyWith(
                        color: OpenTvColors.tally,
                      ),
                    ),
                  ),
                  Expanded(child: Text(step, style: OpenTvType.bodyMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HideRow extends StatelessWidget {
  const _HideRow({
    required this.name,
    required this.kind,
    required this.hidden,
    required this.onToggle,
    this.autofocus = false,
  });

  final String name;
  final String kind;
  final bool hidden;
  final VoidCallback onToggle;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onToggle,
      autofocus: autofocus,
      semanticLabel: hidden ? 'Show $name' : 'Hide $name',
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.005,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.md),
        decoration: BoxDecoration(
          color: OpenTvColors.surface,
          borderRadius: OpenTvRadius.tile,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.body.copyWith(
                  color: hidden ? OpenTvColors.inkFaint : OpenTvColors.ink,
                ),
              ),
            ),
            Text(
              kind.toUpperCase(),
              style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
            ),
            const SizedBox(width: OpenTvSpace.md),
            SizedBox(
              width: 90,
              child: Text(
                hidden ? 'HIDDEN' : '',
                textAlign: TextAlign.right,
                style: OpenTvType.label.copyWith(color: OpenTvColors.tally),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

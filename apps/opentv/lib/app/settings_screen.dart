import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'host.dart';

/// Where a provider is chosen, and where the television is locked.
///
/// Both live here for the same reason: they are the two things a viewer sets
/// once and then wants to forget, and neither belongs in the path of watching
/// something.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.db,
    required this.sources,
    required this.active,
    required this.onSwitch,
    required this.onAddSource,
    required this.onRemoveSource,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final List<Source> sources;
  final Source active;

  final ValueChanged<Source> onSwitch;
  final VoidCallback onAddSource;
  final ValueChanged<Source> onRemoveSource;

  final Host host;

  /// Where the parental PIN lives.
  ///
  /// The keystore, not the database. On tvOS the catalogue is a purgeable
  /// cache, so a lock kept beside it would quietly disappear — and a parental
  /// control that evaporates when the system reclaims disk is worse than none,
  /// because nobody would think to check.
  static const pinReference = 'parental-pin';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Panel { sources, account, hidden, parental, about }

class _SettingsScreenState extends State<SettingsScreen> {
  _Panel _panel = _Panel.sources;

  bool _hasPin = false;
  Set<String> _locked = const {};
  List<Category> _categories = const [];
  List<_CategoryEntry> _allCategories = const [];

  /// Non-null while a PIN is being entered.
  String? _entry;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await widget.host.readSecret(SettingsScreen.pinReference);
    final locked = await widget.db.lockedCategories(widget.active.id);
    final categories = <Category>[
      for (final kind in [ItemKind.live, ItemKind.movie, ItemKind.series])
        ...await widget.db.categoriesFor(widget.active.id, kind),
    ];

    // Hidden ones too: categoriesFor excludes them, which is right for
    // browsing and useless for the screen whose job is un-hiding them.
    final everything = <_CategoryEntry>[
      for (final kind in [ItemKind.live, ItemKind.movie, ItemKind.series])
        for (final category in await widget.db.allCategoriesFor(
          widget.active.id,
          kind,
        ))
          _CategoryEntry(category: category, kind: kind),
    ];

    if (!mounted) return;
    setState(() {
      _hasPin = pin != null && pin.isNotEmpty;
      _locked = locked;
      _categories = categories;
      _allCategories = everything;
    });
  }

  Future<void> _toggleLock(Category category) async {
    final next = {..._locked};
    if (!next.remove(category.remoteId)) next.add(category.remoteId);
    await widget.db.setLockedCategories(widget.active.id, next);
    if (mounted) setState(() => _locked = next);
  }

  Future<void> _commitPin(String pin) async {
    if (pin.length < 4) {
      setState(() => _note = 'A PIN needs at least four digits.');
      return;
    }
    await widget.host.writeSecret(SettingsScreen.pinReference, pin);
    if (!mounted) return;
    setState(() {
      _hasPin = true;
      _entry = null;
      _note = 'PIN set.';
    });
  }

  Future<void> _clearPin() async {
    await widget.host.deleteSecret(SettingsScreen.pinReference);
    // Locks are cleared with the PIN. Leaving categories hidden with no way
    // to unlock them would strand a viewer with no route back.
    await widget.db.setLockedCategories(widget.active.id, {});
    if (!mounted) return;
    setState(() {
      _hasPin = false;
      _locked = const {};
      _note = 'PIN removed, and every lock with it.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: ListView(
            padding: const EdgeInsets.only(
              left: OpenTvSpace.safeHorizontal,
              right: OpenTvSpace.md,
            ),
            children: [
              for (final panel in _Panel.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _PanelButton(
                    label: switch (panel) {
                      _Panel.sources => 'Providers',
                      _Panel.account => 'Account',
                      _Panel.hidden => 'Hidden categories',
                      _Panel.parental => 'Parental lock',
                      _Panel.about => 'About',
                    },
                    selected: panel == _panel,
                    autofocus: panel == _Panel.sources,
                    onSelect: () => setState(() {
                      _panel = panel;
                      _note = null;
                      _entry = null;
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              right: OpenTvSpace.safeHorizontal,
              bottom: OpenTvSpace.xl,
            ),
            child: switch (_panel) {
              _Panel.sources => _sources(),
              _Panel.account => _account(),
              _Panel.hidden => _hidden(),
              _Panel.parental => _parental(),
              _Panel.about => _about(),
            },
          ),
        ),
      ],
    );
  }

  Widget _sources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every provider you have added. The catalogue, favourites and '
          'history are kept separately for each.',
          style: OpenTvType.bodyMuted,
        ),
        const SizedBox(height: OpenTvSpace.md),
        Expanded(
          child: ListView(
            children: [
              for (final source in widget.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: OpenTvSpace.xs),
                  child: _SourceRow(
                    source: source,
                    active: source.id == widget.active.id,
                    onSwitch: () => widget.onSwitch(source),
                    // The last provider cannot be removed from here: doing so
                    // would leave the app with nothing to show and no screen
                    // to add one from.
                    onRemove: widget.sources.length > 1
                        ? () => widget.onRemoveSource(source)
                        : null,
                  ),
                ),
              const SizedBox(height: OpenTvSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: PlayerButton(
                  label: 'ADD ANOTHER PROVIDER',
                  emphasis: true,
                  onSelect: widget.onAddSource,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _parental() {
    final entry = _entry;

    if (entry != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 700,
            child: TextEntryField(
              label: 'New PIN',
              value: entry,
              obscure: true,
              active: true,
              hint: 'Four digits or more',
              problem: _note,
            ),
          ),
          const SizedBox(height: OpenTvSpace.md),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: TvKeyboard(
                autofocus: true,
                onKey: (character) => setState(() => _entry = entry + character),
                onDelete: () => setState(() {
                  _entry = entry.isEmpty
                      ? entry
                      : entry.substring(0, entry.length - 1);
                }),
                doneLabel: 'SET PIN',
                onDone: entry.length >= 4 ? () => _commitPin(entry) : null,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _hasPin
              ? 'A PIN is set. Locked categories are hidden until it is '
                    'entered.'
              : 'No PIN is set. Set one before locking anything, or the lock '
                    'has nothing to enforce it.',
          style: OpenTvType.bodyMuted,
        ),
        if (_note != null) ...[
          const SizedBox(height: OpenTvSpace.xs),
          Text(_note!, style: OpenTvType.data.copyWith(
            color: OpenTvColors.tally,
          )),
        ],
        const SizedBox(height: OpenTvSpace.md),
        Row(
          children: [
            PlayerButton(
              label: _hasPin ? 'CHANGE PIN' : 'SET A PIN',
              emphasis: !_hasPin,
              autofocus: true,
              onSelect: () => setState(() {
                _entry = '';
                _note = null;
              }),
            ),
            if (_hasPin) ...[
              const SizedBox(width: OpenTvSpace.sm),
              PlayerButton(label: 'REMOVE PIN', onSelect: _clearPin),
            ],
          ],
        ),
        const SizedBox(height: OpenTvSpace.lg),
        Text(
          _hasPin
              ? 'Choose what to hide. ${_locked.length} locked.'
              : 'Categories can be chosen once a PIN is set.',
          style: OpenTvType.label,
        ),
        const SizedBox(height: OpenTvSpace.xs),
        Expanded(
          child: !_hasPin
              ? const SizedBox()
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _LockRow(
                        name: category.name,
                        locked: _locked.contains(category.remoteId),
                        onToggle: () => _toggleLock(category),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// What the provider says about the account.
  ///
  /// Read live rather than stored, because the two facts worth knowing —
  /// whether it is active and when it expires — are exactly the ones that
  /// change without the app being told.
  Widget _account() {
    if (widget.active.kind != SourceKind.xtream) {
      return const Text(
        'A playlist has no account behind it. There is nothing to expire and '
        'nothing to check.',
        style: OpenTvType.bodyMuted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Fact(label: 'Provider', value: widget.active.name),
        _Fact(label: 'Portal', value: widget.active.url),
        _Fact(label: 'Username', value: widget.active.username ?? '—'),
        _Fact(
          label: 'Password',
          // Never shown. It lives in the keystore and there is no version of
          // "check my account" that requires putting it on a television
          // screen in a room with other people in it.
          value: widget.active.credentialRef == null ? 'Not stored' : 'Stored',
        ),
        _Fact(
          label: 'Last synced',
          value: widget.active.lastSyncedAt == null
              ? 'Never'
              : _when(widget.active.lastSyncedAt!),
        ),
        const SizedBox(height: OpenTvSpace.md),
        Text(
          'Expiry and connection limits come from the provider and are read '
          'during a sync. Nothing here is sent anywhere.',
          style: OpenTvType.bodyMuted,
        ),
      ],
    );
  }

  static String _when(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  /// Categories the viewer has taken off their own screen.
  ///
  /// Separate from the parental lock and needing no PIN, because this
  /// protects nothing — it is a shopping channel, a duplicate feed, or films
  /// in a language nobody in the house speaks.
  Widget _hidden() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anything hidden here is removed from browsing and search. It stays '
          'in the catalogue, so favourites and history survive, and it can be '
          'brought back at any time.',
          style: OpenTvType.bodyMuted,
        ),
        const SizedBox(height: OpenTvSpace.md),
        Expanded(
          child: _allCategories.isEmpty
              ? const Text('Nothing to hide yet.', style: OpenTvType.bodyMuted)
              : ListView.builder(
                  itemCount: _allCategories.length,
                  itemBuilder: (context, index) {
                    final entry = _allCategories[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _LockRow(
                        name: '${entry.category.name}  ·  ${entry.kindLabel}',
                        locked: entry.category.hidden,
                        lockedLabel: 'HIDDEN',
                        onToggle: () => _toggleHidden(entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _toggleHidden(_CategoryEntry entry) async {
    await widget.db.setCategoryHidden(
      widget.active.id,
      entry.kind,
      entry.category.remoteId,
      !entry.category.hidden,
    );
    await _load();
  }

  Widget _about() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OpenTV', style: OpenTvType.section),
        const SizedBox(height: OpenTvSpace.sm),
        const ContentDisclaimer(width: 1100),
        const SizedBox(height: OpenTvSpace.lg),
        Text(
          'Metadata by TMDB. This product uses the TMDB API but is not '
          'endorsed or certified by TMDB.',
          style: OpenTvType.bodyMuted,
        ),
      ],
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.label,
    required this.selected,
    required this.onSelect,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      semanticLabel: label,
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.01,
      child: Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.sm),
        decoration: BoxDecoration(
          color: selected ? OpenTvColors.surface : null,
          borderRadius: OpenTvRadius.tile,
          border: Border(
            left: BorderSide(
              color: selected ? OpenTvColors.tally : const Color(0x00000000),
              width: 4,
            ),
          ),
        ),
        child: Text(
          label,
          style: OpenTvType.body.copyWith(
            color: selected ? OpenTvColors.ink : OpenTvColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.source,
    required this.active,
    required this.onSwitch,
    this.onRemove,
  });

  final Source source;
  final bool active;
  final VoidCallback onSwitch;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FocusableTile(
            onSelect: onSwitch,
            semanticLabel: source.name,
            borderRadius: OpenTvRadius.tile,
            scaleOnFocus: 1.01,
            child: Container(
              height: 76,
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvSpace.sm,
              ),
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
                border: Border(
                  left: BorderSide(
                    color: active
                        ? OpenTvColors.onAir
                        : const Color(0x00000000),
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpenTvType.body,
                        ),
                        Text(
                          source.kind == SourceKind.xtream
                              ? 'Provider account'
                              : 'Playlist',
                          style: OpenTvType.data.copyWith(
                            color: OpenTvColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (active)
                    Text(
                      'IN USE',
                      style: OpenTvType.data.copyWith(
                        color: OpenTvColors.onAir,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: OpenTvSpace.sm),
          PlayerButton(label: 'REMOVE', onSelect: onRemove),
        ],
      ],
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.name,
    required this.locked,
    required this.onToggle,
    this.lockedLabel = 'LOCKED',
  });

  final String name;
  final bool locked;
  final VoidCallback onToggle;

  /// "Locked" and "hidden" are different promises, and the row says which.
  final String lockedLabel;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onToggle,
      semanticLabel: '$name, ${locked ? lockedLabel.toLowerCase() : 'visible'}',
      borderRadius: OpenTvRadius.tile,
      scaleOnFocus: 1.01,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: OpenTvSpace.sm),
        decoration: BoxDecoration(
          borderRadius: OpenTvRadius.tile,
          border: Border(
            left: BorderSide(
              color: locked ? OpenTvColors.alert : const Color(0x00000000),
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OpenTvType.body.copyWith(
                  color: locked ? OpenTvColors.ink : OpenTvColors.inkMuted,
                ),
              ),
            ),
            Text(
              locked ? lockedLabel : '—',
              style: OpenTvType.data.copyWith(
                color: locked ? OpenTvColors.alert : OpenTvColors.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// A category together with the kind it belongs to, which the row itself
/// does not carry in a form the update needs.
class _CategoryEntry {
  const _CategoryEntry({required this.category, required this.kind});

  final Category category;
  final ItemKind kind;

  String get kindLabel => switch (kind) {
    ItemKind.live => 'Live',
    ItemKind.movie => 'Films',
    ItemKind.series || ItemKind.episode => 'Series',
  };
}

/// One labelled fact, set as a readout.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label.toUpperCase(),
              style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OpenTvType.body,
            ),
          ),
        ],
      ),
    );
  }
}

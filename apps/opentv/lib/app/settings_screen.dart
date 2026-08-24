import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'host.dart';
import 'source_service.dart';
import 'vpn_service.dart';

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
    required this.service,
    required this.vpn,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final List<Source> sources;
  final Source active;

  final ValueChanged<Source> onSwitch;
  final VoidCallback onAddSource;
  final ValueChanged<Source> onRemoveSource;

  /// Used to ask the portal about the account and to re-read the catalogue.
  final SourceService service;

  /// The app's one tunnel. Not built here: a panel with its own instance
  /// would report a state nothing else agreed with.
  final VpnService vpn;

  final Host host;

  /// Where the parental PIN lives.
  ///
  /// The keystore, not the database. On tvOS the catalogue is a purgeable
  /// cache, so a lock kept beside it would quietly disappear — and a parental
  /// control that evaporates when the system reclaims disk is worse than none,
  /// because nobody would think to check.
  static const pinReference = 'parental-pin';

  /// The TMDB key, kept beside the provider password for the same reason:
  /// it is issued to a person and belongs in the keystore, not the database.
  static const tmdbReference = 'tmdb-key';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Panel { sources, account, hidden, metadata, vpn, parental, about }

class _SettingsScreenState extends State<SettingsScreen> {
  _Panel _panel = _Panel.sources;

  bool _hasPin = false;
  Set<String> _locked = const {};
  List<Category> _categories = const [];
  List<_CategoryEntry> _allCategories = const [];

  /// Which kind the hidden-categories panel is showing.
  ///
  /// One at a time, for the same reason the setup step shows one at a time:
  /// three hundred categories from three sections in a single list is not
  /// something a viewer can navigate or decide about.
  ItemKind _hiddenKind = ItemKind.live;

  /// Non-null while a PIN is being entered.
  String? _entry;
  String? _note;
  String _tmdbKey = '';

  XtreamAccount? _account;
  bool _askingPortal = false;

  /// Set while a refresh runs, so the button cannot be pressed twice and the
  /// viewer can see which stage is running.
  bool _refreshing = false;
  String? _refreshNote;

  /// How much the catalogue currently holds, which is the other half of
  /// "is this working" and comes from the database rather than the portal.
  Map<ItemKind, int> _counts = const {};

  WireGuardConfig? _tunnel;
  String _tunnelDraft = '';
  String? _tunnelProblem;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await widget.host.readSecret(SettingsScreen.pinReference);
    final tmdb = await widget.host.readSecret(SettingsScreen.tmdbReference);
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

    final counts = <ItemKind, int>{
      for (final kind in [ItemKind.live, ItemKind.movie, ItemKind.series])
        kind: (await widget.db.countsByCategory(widget.active.id, kind)).values
            .fold(0, (sum, value) => sum + value),
    };

    final tunnel = await widget.vpn.stored();
    await widget.vpn.resync();

    if (!mounted) return;
    setState(() {
      _tunnel = tunnel;
      _counts = counts;
      _hasPin = pin != null && pin.isNotEmpty;
      _tmdbKey = tmdb ?? '';
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
                      _Panel.metadata => 'Metadata',
                      _Panel.vpn => 'Private tunnel',
                      _Panel.parental => 'Parental lock',
                      _Panel.about => 'About',
                    },
                    selected: panel == _panel,
                    autofocus: panel == _Panel.sources,
                    onSelect: () {
                      setState(() {
                        _panel = panel;
                        _note = null;
                        _entry = null;
                      });
                      // Asked on opening rather than on every build, and only
                      // once — a portal round trip per rebuild would make the
                      // panel flicker and hammer the provider.
                      if (panel == _Panel.account &&
                          _account == null &&
                          !_askingPortal) {
                        _askPortal();
                      }
                    },
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
              _Panel.account => _accountPanel(),
              _Panel.hidden => _hidden(),
              _Panel.metadata => _metadata(),
              _Panel.vpn => _vpn(),
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
                    // Including the last one. It used to be exempt, on the
                    // reasoning that removing it leaves the app with nothing
                    // to show — but it does not leave it with nowhere to go:
                    // an app with no provider opens onboarding, which is
                    // exactly the right place to be. Refusing meant a viewer
                    // who wanted their account off this television had no way
                    // to do it short of clearing the app's data.
                    onRemove: () => _confirmRemove(source),
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
  Widget _accountPanel() {
    final source = widget.active;

    if (source.kind != SourceKind.xtream) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A playlist has no account behind it. There is nothing to expire '
            'and no connection limit to report.',
            style: OpenTvType.bodyMuted,
          ),
          const SizedBox(height: OpenTvSpace.md),
          ..._localFacts(),
          const SizedBox(height: OpenTvSpace.lg),
          _refreshControl(),
        ],
      );
    }

    final account = _account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            children: [
              _Fact(label: 'Provider', value: source.name),
              _Fact(label: 'Portal', value: source.url),
              _Fact(label: 'Username', value: source.username ?? '—'),
              _Fact(
                label: 'Password',
                // Never shown. There is no version of "check my account" that
                // requires putting it on a television in a room with other
                // people in it.
                value: source.credentialRef == null ? 'Not stored' : 'Stored',
              ),
              const SizedBox(height: OpenTvSpace.sm),

              if (_askingPortal)
                const Text('Asking the provider…', style: OpenTvType.bodyMuted)
              else if (account == null)
                const Text(
                  'The provider did not answer. The catalogue still works; '
                  'only these figures are unavailable.',
                  style: OpenTvType.bodyMuted,
                )
              else ...[
                _Fact(
                  label: 'Status',
                  value: account.isTrial
                      ? '${account.status} · trial'
                      : account.status,
                ),
                _Fact(label: 'Expires', value: _expiry(account)),
                _Fact(
                  label: 'Connections',
                  value: account.maxConnections == null
                      ? '—'
                      : '${account.activeConnections ?? 0} of '
                            '${account.maxConnections} in use',
                ),
              ],

              const SizedBox(height: OpenTvSpace.sm),
              ..._localFacts(),
              const SizedBox(height: OpenTvSpace.lg),
              _refreshControl(),
            ],
          ),
        ),
      ],
    );
  }

  /// What the catalogue holds, which the portal does not report and which is
  /// the other half of "is this working".
  List<Widget> _localFacts() => [
    _Fact(label: 'Channels', value: _plain(_counts[ItemKind.live])),
    _Fact(label: 'Films', value: _plain(_counts[ItemKind.movie])),
    _Fact(label: 'Series', value: _plain(_counts[ItemKind.series])),
    _Fact(
      label: 'Last synced',
      value: widget.active.lastSyncedAt == null
          ? 'Never'
          : _when(widget.active.lastSyncedAt!),
    ),
  ];

  static String _plain(int? count) =>
      count == null ? '—' : count.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );

  String _expiry(XtreamAccount account) {
    final at = account.expiresAt;
    // Some panels report nothing for unlimited accounts. Showing that as
    // expired would tell a viewer their working account is dead.
    if (at == null) return 'No expiry reported';

    final days = account.daysRemaining(DateTime.now()) ?? 0;
    final when = _when(at);
    if (days < 0) return '$when · lapsed ${-days} days ago';
    if (days == 0) return '$when · today';
    return '$when · $days days left';
  }

  /// Re-reads the whole catalogue from the provider.
  Widget _refreshControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlayerButton(
              label: _refreshing ? 'REFRESHING…' : 'REFRESH CATALOGUE',
              emphasis: !_refreshing,
              onSelect: _refreshing ? null : _refresh,
            ),
            if (!_refreshing && widget.active.kind == SourceKind.xtream) ...[
              const SizedBox(width: OpenTvSpace.sm),
              PlayerButton(label: 'CHECK ACCOUNT', onSelect: _askPortal),
            ],
          ],
        ),
        if (_refreshing) ...[
          const SizedBox(height: OpenTvSpace.sm),
          ValueListenableBuilder<String>(
            valueListenable: widget.service.progress,
            builder: (context, text, _) => Text(
              text,
              style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
            ),
          ),
        ],
        if (_refreshNote != null) ...[
          const SizedBox(height: OpenTvSpace.sm),
          Text(
            _refreshNote!,
            style: OpenTvType.bodyMuted.copyWith(
              color: _refreshNote!.startsWith('Updated')
                  ? OpenTvColors.onAir
                  : OpenTvColors.alert,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _askPortal() async {
    setState(() => _askingPortal = true);
    final account = await widget.service.account(widget.active);
    if (!mounted) return;
    setState(() {
      _account = account;
      _askingPortal = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshNote = null;
    });
    final failure = await widget.service.refresh(widget.active);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _refreshNote = failure ?? 'Updated from the provider.';
    });
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
    final showing = [
      for (final entry in _allCategories)
        if (entry.kind == _hiddenKind) entry,
    ];
    final hiddenNow = showing.where((e) => e.category.hidden).length;

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

        // The kinds and the bulk actions on one line above the list, so
        // neither is at the far end of three hundred rows.
        Row(
          children: [
            for (final kind in [
              ItemKind.live,
              ItemKind.movie,
              ItemKind.series,
            ]) ...[
              PlayerButton(
                label: switch (kind) {
                  ItemKind.live => 'CHANNELS',
                  ItemKind.movie => 'FILMS',
                  ItemKind.series => 'SERIES',
                  ItemKind.episode => 'EPISODES',
                },
                emphasis: kind == _hiddenKind,
                autofocus: kind == ItemKind.live,
                onSelect: () => setState(() => _hiddenKind = kind),
              ),
              const SizedBox(width: OpenTvSpace.xs),
            ],
            const SizedBox(width: OpenTvSpace.md),
            // Hide the lot, then bring back the few you watch. On a provider
            // with hundreds of categories that is the only workable order.
            PlayerButton(label: 'HIDE ALL', onSelect: () => _setAllHidden(true)),
            const SizedBox(width: OpenTvSpace.xs),
            PlayerButton(
              label: 'SHOW ALL',
              onSelect: () => _setAllHidden(false),
            ),
          ],
        ),
        const SizedBox(height: OpenTvSpace.sm),
        Text(
          '$hiddenNow of ${showing.length} hidden',
          style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
        ),
        const SizedBox(height: OpenTvSpace.sm),

        Expanded(
          child: showing.isEmpty
              ? const Text(
                  'Nothing of this kind to hide.',
                  style: OpenTvType.bodyMuted,
                )
              : ListView.builder(
                  itemCount: showing.length,
                  itemBuilder: (context, index) {
                    final entry = showing[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _LockRow(
                        name: entry.category.name,
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

  Future<void> _setAllHidden(bool hidden) async {
    await widget.db.setAllCategoriesHidden(
      sourceId: widget.active.id,
      kind: _hiddenKind,
      hidden: hidden,
    );
    await _load();
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

  /// Where the artwork, synopses and cast come from.
  ///
  /// A key rather than a switch, because TMDB is free but not anonymous: it
  /// issues one per person. Kept in the keystore with the provider password,
  /// since it is a credential even though it unlocks nothing of the viewer's.
  Widget _metadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopses, cast and artwork come from TMDB. Without a key the app '
          'still works — films show the name the provider gave them and '
          'nothing more.',
          style: OpenTvType.bodyMuted,
        ),
        const SizedBox(height: OpenTvSpace.md),
        SizedBox(
          width: 900,
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
              label: 'SAVE KEY',
              emphasis: true,
              onSelect: _tmdbKey.isEmpty ? null : _saveKey,
            ),
            if (_tmdbKey.isNotEmpty) ...[
              const SizedBox(width: OpenTvSpace.sm),
              PlayerButton(label: 'REMOVE', onSelect: _clearKey),
            ],
          ],
        ),
        if (_note != null) ...[
          const SizedBox(height: OpenTvSpace.sm),
          Text(
            _note!,
            style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
          ),
        ],
        const SizedBox(height: OpenTvSpace.lg),
        Text(
          'This product uses the TMDB API but is not endorsed or certified '
          'by TMDB.',
          style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
        ),
      ],
    );
  }

  /// The tunnel panel.
  ///
  /// Stated plainly rather than sold. A VPN moves the question of who can see
  /// this traffic from the viewer's network to the tunnel provider's; it does
  /// not make the traffic private, and an interface implying otherwise is
  /// giving someone a false idea of their own exposure.
  Widget _vpn() {
    if (!widget.vpn.isSupported) {
      return const Text(
        'The tunnel is Android-only for now. Apple TV needs a Network '
        'Extension, which needs a paid developer account to sign — so rather '
        'than a button that fails, there is none yet.',
        style: OpenTvType.bodyMuted,
      );
    }

    final tunnel = _tunnel;

    return ValueListenableBuilder<VpnState>(
      valueListenable: widget.vpn.state,
      builder: (context, state, _) => ListView(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (state) {
                    VpnState.up => OpenTvColors.onAir,
                    VpnState.connecting => OpenTvColors.tally,
                    VpnState.down => OpenTvColors.inkFaint,
                  },
                ),
              ),
              const SizedBox(width: OpenTvSpace.xs),
              Text(
                switch (state) {
                  VpnState.up => 'CARRYING TRAFFIC',
                  VpnState.connecting => 'CONNECTING',
                  VpnState.down => 'NOT CONNECTED',
                },
                style: OpenTvType.label.copyWith(
                  color: switch (state) {
                    VpnState.up => OpenTvColors.onAir,
                    VpnState.connecting => OpenTvColors.tally,
                    VpnState.down => OpenTvColors.inkFaint,
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: OpenTvSpace.sm),

          const Text(
            'A WireGuard tunnel carries this app\'s traffic to your provider '
            'instead of over your own connection. It moves who can see that '
            'traffic — from your network to whoever runs the tunnel. It does '
            'not make it invisible, and it is only as trustworthy as they are.',
            style: OpenTvType.bodyMuted,
          ),
          const SizedBox(height: OpenTvSpace.md),

          if (tunnel != null) ...[
            _Fact(label: 'Endpoint', value: tunnel.peer.endpoint),
            _Fact(
              label: 'Routes',
              // The distinction the viewer's expectations rest on.
              value: tunnel.isFullTunnel
                  ? 'Everything'
                  : tunnel.peer.allowedIps.join(', '),
            ),
            _Fact(
              label: 'DNS',
              value: tunnel.dns.isEmpty ? 'Unchanged' : tunnel.dns.join(', '),
            ),
            if (tunnel.mtu != null)
              _Fact(label: 'MTU', value: '\${tunnel.mtu}'),
            const SizedBox(height: OpenTvSpace.md),
            Row(
              children: [
                PlayerButton(
                  label: state == VpnState.up ? 'DISCONNECT' : 'CONNECT',
                  emphasis: state != VpnState.up,
                  onSelect: _connecting
                      ? null
                      : state == VpnState.up
                      ? _disconnect
                      : _connect,
                ),
                const SizedBox(width: OpenTvSpace.sm),
                PlayerButton(
                  label: 'FORGET TUNNEL',
                  onSelect: _connecting ? null : _forgetTunnel,
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: 900,
              child: TextEntryField(
                label: 'WireGuard configuration',
                value: _tunnelDraft,
                hint: 'Paste the .conf your provider gave you',
                active: true,
                // Masked: the file contains a private key, and a television
                // is a screen other people are in the room with.
                obscure: true,
                multiline: true,
                problem: _tunnelProblem,
                onChanged: (text) => setState(() => _tunnelDraft = text),
                onDone: _saveTunnel,
              ),
            ),
            const SizedBox(height: OpenTvSpace.sm),
            const Text(
              'Easiest from your phone: open this screen, then type into it '
              'with a keyboard app rather than the remote.',
              style: OpenTvType.bodyMuted,
            ),
            const SizedBox(height: OpenTvSpace.md),
            PlayerButton(
              label: 'SAVE TUNNEL',
              emphasis: true,
              onSelect: _tunnelDraft.isEmpty ? null : _saveTunnel,
            ),
          ],

          if (widget.vpn.problem.value != null) ...[
            const SizedBox(height: OpenTvSpace.sm),
            Text(
              widget.vpn.problem.value!,
              style: OpenTvType.bodyMuted.copyWith(color: OpenTvColors.alert),
            ),
          ],
        ],
      ),
    );
  }

  /// Asks before forgetting a provider.
  ///
  /// Everything cascades — catalogue, favourites, history, and the password
  /// in the keystore — and none of it comes back. That is worth one press to
  /// confirm, and the panel names what goes rather than asking whether the
  /// viewer is sure.
  void _confirmRemove(Source source) {
    final last = widget.sources.length == 1;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => ConfirmPanel(
          title: 'Forget ${source.name}?',
          detail: last
              ? 'Its catalogue, favourites, history and stored password are '
                    'deleted. This is your only provider, so the app will '
                    'return to setup.'
              : 'Its catalogue, favourites, history and stored password are '
                    'deleted. Your other providers are untouched.',
          confirmLabel: 'FORGET',
          cancelLabel: 'KEEP',
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () {
            Navigator.of(context).pop();
            widget.onRemoveSource(source);
          },
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _saveTunnel() async {
    final problem = await widget.vpn.save(_tunnelDraft);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _tunnelProblem = problem);
      return;
    }
    final tunnel = await widget.vpn.stored();
    if (!mounted) return;
    setState(() {
      _tunnel = tunnel;
      _tunnelProblem = null;
      // Dropped from memory once it is in the keystore. There is no reason
      // for a private key to sit in a widget's state for the rest of the
      // session.
      _tunnelDraft = '';
    });
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    await widget.vpn.connect();
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _disconnect() async {
    setState(() => _connecting = true);
    await widget.vpn.disconnect();
    if (mounted) setState(() => _connecting = false);
  }

  Future<void> _forgetTunnel() async {
    await widget.vpn.forget();
    if (mounted) setState(() => _tunnel = null);
  }

  Future<void> _saveKey() async {
    await widget.host.writeSecret(SettingsScreen.tmdbReference, _tmdbKey);
    if (mounted) setState(() => _note = 'Key saved. New films will use it.');
  }

  Future<void> _clearKey() async {
    await widget.host.deleteSecret(SettingsScreen.tmdbReference);
    if (mounted) {
      setState(() {
        _tmdbKey = '';
        _note = 'Key removed.';
      });
    }
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

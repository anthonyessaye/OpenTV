import 'package:flutter/services.dart' show TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/host.dart';
import '../app/settings_screen.dart' show SettingsScreen;
import 'touch_field.dart';

/// The parental lock on a phone: the PIN, and what it hides.
///
/// The phone had half of this. It could set the PIN, because a PIN is a
/// keystore secret exactly like the TMDB key and so it fitted the generic
/// secret screen for free — and it had no way at all to choose which
/// categories the PIN locked, which is the half that gives the PIN a meaning.
/// The screen's own text said "categories you lock" while the phone offered
/// nothing that locked one.
///
/// It enforced them, though: a lock set on a television is honoured here in
/// browsing, search and the guide. So the feature half-worked, from a
/// settings list that looked complete.
///
/// The trap was removal. The television clears every lock when the PIN goes,
/// deliberately, so that nobody is left with content hidden and no way back;
/// the generic screen simply deleted the secret. On a phone-only setup that
/// left the catalogue locked, the PIN gone, and no control on the device
/// capable of undoing either.
class MobileParentalScreen extends StatefulWidget {
  const MobileParentalScreen({
    super.key,
    required this.db,
    required this.sourceId,
    this.host = const Host(),
  });

  final OpenTvDatabase db;
  final int sourceId;
  final Host host;

  @override
  State<MobileParentalScreen> createState() => _MobileParentalScreenState();
}

class _MobileParentalScreenState extends State<MobileParentalScreen> {
  static const _kinds = [ItemKind.live, ItemKind.movie, ItemKind.series];
  static const _labels = ['Live', 'Films', 'Series'];

  final _entry = TextEditingController();

  int _tab = 0;
  bool _loading = true;
  bool _hasPin = false;

  /// Whether the PIN has been given since this screen was opened.
  ///
  /// Per visit rather than remembered, for the reason the television keeps it
  /// per visit: a device gets handed over, and the next person holding it is
  /// the person this exists to stop.
  bool _proved = false;

  List<Category> _categories = const [];
  Set<String> _locked = const {};
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Whether one exists, never what it is. A settings screen that renders a
    // stored secret back is a settings screen that shows it to the room.
    final stored = await widget.host.readSecret(SettingsScreen.pinReference);
    final categories =
        await widget.db.allCategoriesFor(widget.sourceId, _kinds[_tab]);
    final locked = await widget.db.lockedCategories(widget.sourceId);
    if (!mounted) return;
    setState(() {
      _hasPin = stored != null && stored.isNotEmpty;
      _categories = categories;
      _locked = locked;
      _loading = false;
    });
  }

  Future<void> _prove() async {
    final stored = await widget.host.readSecret(SettingsScreen.pinReference);
    if (!mounted) return;
    // Constant time, through the helper the setup server has always used.
    // Four digits is not much to leak and there is no reason to leak any.
    if (!SecretMatch.constantTime(_entry.text.trim(), stored)) {
      setState(() => _note = 'That is not the PIN.');
      return;
    }
    _entry.clear();
    setState(() {
      _proved = true;
      _note = null;
    });
  }

  Future<void> _setPin() async {
    final value = _entry.text.trim();
    if (value.length < 4) {
      setState(() => _note = 'Four digits or more.');
      return;
    }
    await widget.host.writeSecret(SettingsScreen.pinReference, value);
    _entry.clear();
    if (!mounted) return;
    setState(() {
      _hasPin = true;
      // Whoever just chose it knows it. Locking them out of the panel they
      // are standing in would be the app arguing with itself.
      _proved = true;
      _note = 'PIN set.';
    });
  }

  Future<void> _removePin() async {
    await widget.host.deleteSecret(SettingsScreen.pinReference);
    // The locks go with it, as they do on the television. Leaving categories
    // hidden with no PIN and no way to reach them again is how a viewer ends
    // up needing a second device to get their own catalogue back.
    await widget.db.setLockedCategories(widget.sourceId, {});
    if (!mounted) return;
    setState(() {
      _hasPin = false;
      _locked = const {};
      _note = 'PIN removed, and every lock with it.';
    });
  }

  Future<void> _toggle(Category category) async {
    final next = {..._locked};
    if (!next.remove(category.remoteId)) next.add(category.remoteId);
    await widget.db.setLockedCategories(widget.sourceId, next);
    if (mounted) setState(() => _locked = next);
  }

  Future<void> _selectTab(int index) async {
    setState(() {
      _tab = index;
      _loading = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: 'Parental lock',
      onBack: () => Navigator.of(context).maybePop(),
      body: _loading
          ? const Center(
              child: Text('Reading…', style: OpenTvTouchType.bodyMuted),
            )
          : _hasPin && !_proved
              ? _gate()
              : _panel(),
    );
  }

  /// Everything behind this changes or removes the lock, so everything behind
  /// it is behind the PIN.
  Widget _gate() {
    return ListView(
      padding: OpenTvTouchSpace.page,
      children: [
        const Text(
          'A PIN is set on this device. Enter it to change what is locked, '
          'or to remove the lock.',
          style: OpenTvTouchType.bodyMuted,
        ),
        const SizedBox(height: OpenTvTouchSpace.lg),
        TouchField(
          label: 'PIN',
          controller: _entry,
          obscure: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _prove(),
        ),
        if (_note case final note?) ...[
          const SizedBox(height: OpenTvTouchSpace.sm),
          Text(note, style: OpenTvTouchType.caption),
        ],
        const SizedBox(height: OpenTvTouchSpace.lg),
        _Action(label: 'Unlock', emphasis: true, onTap: _prove),
      ],
    );
  }

  Widget _panel() {
    // One scroll view, not a fixed header above an Expanded list. The
    // explanation, the field and the two buttons are most of a small phone
    // before a single category — and an Expanded under all that is handed
    // whatever is left, which on a 390-point screen was nothing at all.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: OpenTvTouchSpace.page,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasPin
                      ? 'A locked category is removed from browsing, from '
                          'search and from the guide — not greyed out and '
                          'not listed, because a list that names what it '
                          'hides tells a child where to look. There is no '
                          'prompt to reveal it while watching; this screen '
                          'is the way back, and it needs the PIN.'
                      : 'Set a PIN before locking anything, or the lock has '
                          'nothing to enforce it.',
                  style: OpenTvTouchType.bodyMuted,
                ),
                const SizedBox(height: OpenTvTouchSpace.md),
                TouchField(
                  label: _hasPin ? 'New PIN' : 'PIN',
                  controller: _entry,
                  obscure: true,
                  hint: 'Four digits or more',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _setPin(),
                ),
                if (_note case final note?) ...[
                  const SizedBox(height: OpenTvTouchSpace.sm),
                  Text(note, style: OpenTvTouchType.caption),
                ],
                const SizedBox(height: OpenTvTouchSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: _Action(
                        label: _hasPin ? 'Change PIN' : 'Set PIN',
                        emphasis: !_hasPin,
                        onTap: _setPin,
                      ),
                    ),
                    if (_hasPin) ...[
                      const SizedBox(width: OpenTvTouchSpace.sm),
                      Expanded(
                        child: _Action(
                          label: 'Remove PIN',
                          onTap: _removePin,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_hasPin) ...[
          // Room between changing the PIN and choosing what it hides. They
          // are two different jobs, and stacked flush against each other the
          // tabs read as a third row of buttons belonging to the first.
          const SliverToBoxAdapter(
            child: SizedBox(height: OpenTvTouchSpace.xl),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenTvTouchSpace.gutter,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: TouchTile(
                        onTap: () => _selectTab(i),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            vertical: OpenTvTouchSpace.sm,
                          ),
                          decoration: BoxDecoration(
                            color: i == _tab
                                ? OpenTvColors.surfaceLifted
                                : OpenTvColors.surface,
                            borderRadius: OpenTvRadius.tile,
                          ),
                          child: Text(
                            _labels[i],
                            style: OpenTvTouchType.section,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              OpenTvTouchSpace.gutter,
              OpenTvTouchSpace.sm,
              OpenTvTouchSpace.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_locked.length} locked',
                  style: OpenTvTouchType.data,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: _categories.length,
            itemBuilder: (context, i) {
              final category = _categories[i];
              final locked = _locked.contains(category.remoteId);
              return TouchTile(
                onTap: () => _toggle(category),
                minHeight: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OpenTvTouchSpace.gutter,
                    vertical: OpenTvTouchSpace.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OpenTvTouchType.body.copyWith(
                            color: locked
                                ? OpenTvColors.inkFaint
                                : OpenTvColors.ink,
                          ),
                        ),
                      ),
                      if (locked)
                        const Text('LOCKED', style: OpenTvTouchType.label),
                    ],
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: OpenTvTouchSpace.xxl),
          ),
        ],
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: OpenTvTouchSpace.md),
          decoration: BoxDecoration(
            color: emphasis ? OpenTvColors.tally : OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
          ),
          child: Text(
            label,
            style: OpenTvTouchType.body.copyWith(
              color: emphasis ? OpenTvColors.ground : OpenTvColors.ink,
            ),
          ),
        ),
      );
}

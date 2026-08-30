import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/host.dart';
import '../app/settings_screen.dart';

/// A secret entered on a phone, where the keyboard is the system's.
///
/// The television draws its own keyboard because a remote cannot type. Here
/// that would be an imitation of something the phone does better, which is the
/// same reason the browser setup does not exist on this device.
class MobileSecretScreen extends StatefulWidget {
  const MobileSecretScreen({
    super.key,
    required this.title,
    required this.reference,
    required this.explanation,
    this.hint,
    this.digitsOnly = false,
    this.onCheck,
    this.host = const Host(),
  });

  final String title;

  /// The keystore reference. The secret is never written to the database, on
  /// this device any more than on the television.
  final String reference;

  final String explanation;
  final String? hint;
  final bool digitsOnly;

  /// Tries the stored secret against whatever issued it, and says what came
  /// back. Absent for a secret nothing can be asked about — a parental PIN
  /// answers to nobody.
  final Future<String> Function()? onCheck;

  final Host host;

  @override
  State<MobileSecretScreen> createState() => _MobileSecretScreenState();
}

class _MobileSecretScreenState extends State<MobileSecretScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _stored = false;
  String? _note;
  bool _checking = false;

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
    // Whether one exists, never what it is. A settings screen that renders a
    // stored secret back is a settings screen that shows it to the room.
    final existing = await widget.host.readSecret(widget.reference);
    if (mounted) setState(() => _stored = existing != null);
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (widget.digitsOnly && value.length < 4) {
      setState(() => _note = 'Four digits or more.');
      return;
    }
    if (value.isEmpty) return;
    await widget.host.writeSecret(widget.reference, value);
    _controller.clear();
    if (mounted) {
      setState(() {
        _stored = true;
        _note = 'Saved.';
      });
    }
  }

  Future<void> _check() async {
    final check = widget.onCheck;
    if (check == null) return;
    setState(() {
      _checking = true;
      _note = null;
    });
    final answer = await check();
    if (mounted) {
      setState(() {
        _checking = false;
        _note = answer;
      });
    }
  }

  Future<void> _remove() async {
    await widget.host.deleteSecret(widget.reference);
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
      title: widget.title,
      onBack: () => Navigator.of(context).maybePop(),
      body: ListView(
        padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
        children: [
          Text(widget.explanation, style: OpenTvTouchType.bodyMuted),
          const SizedBox(height: OpenTvTouchSpace.xl),
          Text(
            _stored ? 'ONE IS STORED' : 'NONE STORED',
            style: OpenTvTouchType.label,
          ),
          const SizedBox(height: OpenTvTouchSpace.xs),
          Container(
            height: OpenTvTouchSpace.tapTarget,
            padding: const EdgeInsets.symmetric(
              horizontal: OpenTvTouchSpace.md,
            ),
            alignment: AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: OpenTvColors.surface,
              borderRadius: OpenTvRadius.tile,
            ),
            child: EditableText(
              controller: _controller,
              focusNode: _focus,
              style: OpenTvTouchType.body,
              cursorColor: OpenTvColors.tally,
              backgroundCursorColor: OpenTvColors.inkFaint,
              obscureText: true,
              keyboardType:
                  widget.digitsOnly ? TextInputType.number : TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            Text(_note!, style: OpenTvTouchType.caption),
          ],
          const SizedBox(height: OpenTvTouchSpace.lg),
          TouchTile(
            onTap: _save,
            minHeight: 48,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OpenTvColors.tally,
                borderRadius: OpenTvRadius.tile,
              ),
              child: Text(
                'Save',
                style: OpenTvTouchType.section
                    .copyWith(color: OpenTvColors.ground),
              ),
            ),
          ),
          if (_stored && widget.onCheck != null) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            TouchTile(
              onTap: _checking ? null : _check,
              minHeight: 48,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OpenTvColors.surface,
                  borderRadius: OpenTvRadius.tile,
                ),
                child: Text(
                  _checking ? 'Testing…' : 'Test this key',
                  style: OpenTvTouchType.section,
                ),
              ),
            ),
          ],
          if (_stored) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            TouchTile(
              onTap: _remove,
              minHeight: 48,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Remove',
                  style: OpenTvTouchType.section
                      .copyWith(color: OpenTvColors.alert),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hiding categories, one kind at a time.
///
/// The bulk actions are here for the reason they are on the television: a
/// provider with three hundred categories is not a list anybody works through
/// one row at a time, and hiding the lot then restoring the few you watch is
/// the only workable order.
class MobileCategoriesScreen extends StatefulWidget {
  const MobileCategoriesScreen({
    super.key,
    required this.db,
    required this.sourceId,
  });

  final OpenTvDatabase db;
  final int sourceId;

  @override
  State<MobileCategoriesScreen> createState() => _MobileCategoriesScreenState();
}

class _MobileCategoriesScreenState extends State<MobileCategoriesScreen> {
  static const _kinds = [ItemKind.live, ItemKind.movie, ItemKind.series];
  static const _labels = ['Live', 'Films', 'Series'];

  int _tab = 0;
  List<Category> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await widget.db.allCategoriesFor(widget.sourceId, _kinds[_tab]);
    if (mounted) {
      setState(() {
        _categories = rows;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Category category) async {
    await widget.db.setCategoryHidden(
      widget.sourceId,
      _kinds[_tab],
      category.remoteId,
      !category.hidden,
    );
    await _load();
  }

  Future<void> _setAll(bool hidden) async {
    await widget.db.setAllCategoriesHidden(
      sourceId: widget.sourceId,
      kind: _kinds[_tab],
      hidden: hidden,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final hiddenNow = _categories.where((c) => c.hidden).length;

    return TouchScaffold(
      title: 'Categories',
      onBack: () => Navigator.of(context).maybePop(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < _labels.length; i++)
                      Expanded(
                        child: TouchTile(
                          onTap: () {
                            setState(() {
                              _tab = i;
                              _loading = true;
                            });
                            _load();
                          },
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
                const SizedBox(height: OpenTvTouchSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Bulk(
                        label: 'Hide all',
                        onTap: () => _setAll(true),
                      ),
                    ),
                    const SizedBox(width: OpenTvTouchSpace.sm),
                    Expanded(
                      child: _Bulk(
                        label: 'Show all',
                        onTap: () => _setAll(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OpenTvTouchSpace.xs),
                Text(
                  '$hiddenNow of ${_categories.length} hidden',
                  style: OpenTvTouchType.data,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Text('Reading…', style: OpenTvTouchType.bodyMuted),
                  )
                : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final category = _categories[i];
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
                                    color: category.hidden
                                        ? OpenTvColors.inkFaint
                                        : OpenTvColors.ink,
                                  ),
                                ),
                              ),
                              if (category.hidden)
                                Text('HIDDEN', style: OpenTvTouchType.label),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Bulk extends StatelessWidget {
  const _Bulk({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TouchTile(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: OpenTvTouchSpace.sm),
          decoration: BoxDecoration(
            color: OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
            border: const Border(
              bottom: BorderSide(color: OpenTvColors.rule),
            ),
          ),
          child: Text(label, style: OpenTvTouchType.body),
        ),
      );
}

/// The two secrets a phone can set, named where the television names them.
class MobileSecretReferences {
  const MobileSecretReferences._();

  static const pin = SettingsScreen.pinReference;
  static const tmdb = SettingsScreen.tmdbReference;
}

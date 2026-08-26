import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

/// Choosing which regions to see, one kind at a time.
///
/// Regions are counted out of the catalogue rather than offered from a list of
/// countries, because they are whatever the provider chose to type into its
/// titles. `AR`, `EX-YU`, `4K` and `VIP` all turn up, and a list of real
/// countries would hide most of what is actually there.
///
/// Phrased as hiding rather than choosing. A viewer with eleven regions wants
/// to remove the two they do not speak, not to tick nine — and the difference
/// matters when a sync adds a twelfth, because a hide list lets it through and
/// a show list silently swallows it.
class RegionScreen extends StatefulWidget {
  const RegionScreen({
    super.key,
    required this.db,
    required this.sourceId,
    required this.onChanged,
  });

  final OpenTvDatabase db;
  final int sourceId;

  /// Called after every change, so shelves behind this rebuild.
  final ValueChanged<RegionFilter> onChanged;

  @override
  State<RegionScreen> createState() => _RegionScreenState();
}

class _RegionScreenState extends State<RegionScreen> {
  static const _kinds = [ItemKind.live, ItemKind.movie, ItemKind.series];
  static const _labels = ['Live', 'Films', 'Series'];

  int _tab = 1;
  RegionFilter _filter = const RegionFilter();
  final _regions = <ItemKind, List<({String region, int count})>>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await widget.db.preference(RegionFilter.preferenceKey);
    for (final kind in _kinds) {
      _regions[kind] = await widget.db.regionsIn(widget.sourceId, kind);
    }
    if (!mounted) return;
    setState(() {
      _filter = RegionFilter.decode(stored);
      _loading = false;
    });
  }

  Future<void> _toggle(ItemKind kind, String region, bool hide) async {
    await _write(_filter.withRegion(kind, region, hide: hide));
  }

  /// Hide or show every region of this kind at once.
  ///
  /// The same reason the categories panel has them: a provider with a dozen
  /// regions is not a list anybody works through one row at a time, and
  /// hiding the lot then restoring the two you watch is the workable order.
  Future<void> _setAll(bool hide) async {
    var next = _filter;
    for (final entry in _regions[_kinds[_tab]] ?? const []) {
      next = next.withRegion(_kinds[_tab], entry.region, hide: hide);
    }
    await _write(next);
  }

  Future<void> _write(RegionFilter next) async {
    setState(() => _filter = next);
    await widget.db.setPreference(RegionFilter.preferenceKey, next.encode());
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kinds[_tab];
    final regions = _regions[kind] ?? const [];
    final hidden = _filter.forKind(kind);

    return TouchScaffold(
      title: 'Regions',
      onBack: () => Navigator.of(context).maybePop(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
            child: _Segmented(
              selected: _tab,
              labels: _labels,
              onSelect: (i) => setState(() => _tab = i),
            ),
          ),
          if (regions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OpenTvTouchSpace.gutter,
              ),
              child: Row(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OpenTvTouchSpace.gutter,
                OpenTvTouchSpace.sm,
                OpenTvTouchSpace.gutter,
                0,
              ),
              child: Text(
                '${hidden.length} of ${regions.length} hidden',
                style: OpenTvTouchType.data,
              ),
            ),
          ],
          Expanded(
            child: _loading
                ? const Center(
                    child: Text('Reading…', style: OpenTvTouchType.bodyMuted),
                  )
                : regions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: OpenTvTouchSpace.page,
                          child: Text(
                            'No regions are recorded for these.\n\n'
                            'Either the provider does not put one in front of '
                            'its titles, or this catalogue was imported by a '
                            'version of the app that did not read them. '
                            'Re-reading the catalogue from settings will '
                            'record them.',
                            style: OpenTvTouchType.bodyMuted,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          for (final entry in regions)
                            _RegionRow(
                              region: entry.region,
                              count: entry.count,
                              shown: !hidden.contains(entry.region),
                              onChanged: (shown) => _toggle(
                                kind,
                                entry.region,
                                !shown,
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.all(OpenTvTouchSpace.gutter),
                            child: Text(
                              'Titles with no region prefix are always shown. '
                              'Most catalogues label only some of what they '
                              'carry.',
                              style: OpenTvTouchType.caption,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

/// A bulk action, matching the categories screen's.
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

class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.region,
    required this.count,
    required this.shown,
    required this.onChanged,
  });

  final String region;
  final int count;
  final bool shown;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TouchTile(
      onTap: () => onChanged(!shown),
      semanticLabel: '$region, ${shown ? 'shown' : 'hidden'}',
      minHeight: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OpenTvTouchSpace.gutter,
          vertical: OpenTvTouchSpace.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(region, style: OpenTvTouchType.section),
                  Text(
                    '$count ${count == 1 ? 'title' : 'titles'}',
                    style: OpenTvTouchType.caption,
                  ),
                ],
              ),
            ),
            _Switch(on: shown),
          ],
        ),
      ),
    );
  }
}

/// A switch, drawn.
class _Switch extends StatelessWidget {
  const _Switch({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: on ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: on ? OpenTvColors.tally : OpenTvColors.rule,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: on ? OpenTvColors.ground : OpenTvColors.inkMuted,
          borderRadius: BorderRadius.circular(11),
        ),
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
                    color: i == selected ? OpenTvColors.surfaceLifted : null,
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

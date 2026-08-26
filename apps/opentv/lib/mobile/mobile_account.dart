import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/source_service.dart';

/// What the provider says about this account, and what the catalogue holds.
///
/// The password is never on this screen, and there is no field that could put
/// it there. A settings screen that renders a stored secret back is one that
/// shows it to whoever is looking over your shoulder — the same rule the
/// television's account panel follows.
class MobileAccountScreen extends StatefulWidget {
  const MobileAccountScreen({
    super.key,
    required this.db,
    required this.service,
    required this.source,
  });

  final OpenTvDatabase db;
  final SourceService service;
  final Source source;

  @override
  State<MobileAccountScreen> createState() => _MobileAccountScreenState();
}

class _MobileAccountScreenState extends State<MobileAccountScreen> {
  XtreamAccount? _account;
  Map<ItemKind, int> _counts = const {};
  bool _asking = true;
  bool _refreshing = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final counts = <ItemKind, int>{
      for (final kind in [ItemKind.live, ItemKind.movie, ItemKind.series])
        kind: (await widget.db.countsByCategory(widget.source.id, kind))
            .values
            .fold(0, (sum, value) => sum + value),
    };
    // Asked once, on opening. A portal round trip per rebuild would make the
    // screen flicker and hammer the provider.
    final account = await widget.service.account(widget.source);
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _account = account;
      _asking = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _note = null;
    });
    final failure = await widget.service.refresh(widget.source);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _note = failure ?? 'Updated from the provider.';
    });
  }

  static String _date(DateTime at) {
    final local = at.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;

    return TouchScaffold(
      title: widget.source.name,
      onBack: () => Navigator.of(context).maybePop(),
      body: ListView(
        padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
        children: [
          const Text('ACCOUNT', style: OpenTvTouchType.label),
          const SizedBox(height: OpenTvTouchSpace.sm),
          if (_asking)
            const Text('Asking the provider…', style: OpenTvTouchType.bodyMuted)
          else if (account == null)
            const Text(
              'This provider does not report an account, which is normal for '
              'a plain playlist.',
              style: OpenTvTouchType.bodyMuted,
            )
          else ...[
            _Fact(label: 'Status', value: account.status),
            _Fact(
              label: 'Expires',
              // Absent is not expired, and showing it as one would tell
              // somebody with an unlimited account that it had run out.
              value: account.expiresAt == null
                  ? 'No expiry reported'
                  : _date(account.expiresAt!),
            ),
            if (account.maxConnections != null)
              _Fact(
                label: 'Connections',
                value: '${account.activeConnections ?? 0} '
                    'of ${account.maxConnections} in use',
              ),
            if (account.isTrial) const _Fact(label: 'Trial', value: 'Yes'),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          const Text('CATALOGUE', style: OpenTvTouchType.label),
          const SizedBox(height: OpenTvTouchSpace.sm),
          _Fact(label: 'Channels', value: '${_counts[ItemKind.live] ?? 0}'),
          _Fact(label: 'Films', value: '${_counts[ItemKind.movie] ?? 0}'),
          _Fact(label: 'Series', value: '${_counts[ItemKind.series] ?? 0}'),
          if (widget.source.lastSyncedAt case final DateTime at)
            _Fact(label: 'Last synced', value: _date(at)),
          const SizedBox(height: OpenTvTouchSpace.xl),
          TouchTile(
            onTap: _refreshing ? null : _refresh,
            minHeight: 48,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OpenTvColors.surface,
                borderRadius: OpenTvRadius.tile,
                border: const Border(
                  bottom: BorderSide(color: OpenTvColors.rule),
                ),
              ),
              child: Text(
                _refreshing ? 'Reading…' : 'Re-read the catalogue',
                style: OpenTvTouchType.section,
              ),
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            Text(_note!, style: OpenTvTouchType.caption),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: OpenTvTouchType.bodyMuted),
            ),
            Expanded(
              child: Text(
                value,
                style: OpenTvTouchType.data.copyWith(color: OpenTvColors.ink),
              ),
            ),
          ],
        ),
      );
}

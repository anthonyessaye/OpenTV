import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/backup_service.dart';
import '../app/backup_sync.dart';
import '../app/host.dart';
import 'touch_field.dart';

/// The folder this phone leaves its watch state in.
///
/// The television has had this and the phone has not, which made the feature
/// half a feature: a position set on the sofa reached nothing, because the
/// device most likely to be picked up next had no way to be pointed at the
/// same folder. It syncs on this side already — at launch and on leaving —
/// and had no screen to be configured from.
///
/// Bring your own storage, for the reason the TMDB and OpenSubtitles keys
/// are the viewer's own. Here it is also the point: the folder holds a record
/// of what somebody watches, on an account nobody else pays for.
class MobileBackupScreen extends StatefulWidget {
  const MobileBackupScreen({
    super.key,
    required this.db,
    required this.sync,
    this.host = const Host(),
  });

  final OpenTvDatabase db;

  /// The app's own sync, so saving a folder starts using it rather than
  /// waiting for the next launch.
  final BackupSync? sync;

  final Host host;

  @override
  State<MobileBackupScreen> createState() => _MobileBackupScreenState();
}

class _MobileBackupScreenState extends State<MobileBackupScreen> {
  late final BackupService _backup =
      BackupService(db: widget.db, host: widget.host);

  final _endpoint = TextEditingController();
  final _bucket = TextEditingController();
  final _accessKey = TextEditingController();
  final _secretKey = TextEditingController();
  final _region = TextEditingController();
  final _phrase = TextEditingController();

  bool _configured = false;
  bool _hasPhrase = false;
  bool _regionNeeded = false;
  bool _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void dispose() {
    for (final controller in [
      _endpoint,
      _bucket,
      _accessKey,
      _secretKey,
      _region,
      _phrase,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _read() async {
    final settings = await _backup.config();
    final phrase = await _backup.hasPhrase();
    if (!mounted) return;
    setState(() {
      _configured = settings != null;
      _hasPhrase = phrase;
      _endpoint.text = settings?.endpoint.toString() ?? _endpoint.text;
      _bucket.text = settings?.bucket ?? _bucket.text;
      _regionNeeded = _needsRegion(_endpoint.text);
      // The keys are never read back into the fields. No other screen here
      // renders a stored secret, and this one opens a bucket.
      _note = widget.sync?.failure;
    });
  }

  static bool _needsRegion(String endpoint) {
    final parsed = Uri.tryParse(endpoint.trim());
    if (parsed == null || parsed.host.isEmpty) return false;
    return s3RegionFor(parsed) == null;
  }

  Future<void> _save() async {
    if (_endpoint.text.trim().isEmpty || _bucket.text.trim().isEmpty) return;
    await _backup.save(
      endpoint: _endpoint.text,
      region: _region.text,
      bucket: _bucket.text,
      accessKey: _accessKey.text,
      secretKey: _secretKey.text,
    );
    _accessKey.clear();
    _secretKey.clear();
    if (!mounted) return;
    setState(() {
      _configured = true;
      _regionNeeded = _needsRegion(_endpoint.text);
      _note = 'Saved.';
    });

    // Straight away rather than at the next launch. A viewer who has just set
    // a folder up and looks in it should find something there.
    if (_regionNeeded && _region.text.trim().isEmpty) return;
    await _run();
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    final result = await _backup.check();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = result;
    });
  }

  Future<void> _run() async {
    final sync = widget.sync;
    if (sync == null) return;
    setState(() => _busy = true);
    await sync.run();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = sync.failure ??
          'Synced. This happens on its own when the app opens, when it is '
              'left, and after something is watched.';
    });
  }

  Future<void> _savePhrase() async {
    final problem = backupPhraseProblem(_phrase.text);
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    await _backup.savePhrase(_phrase.text);
    _phrase.clear();
    if (!mounted) return;
    setState(() {
      _hasPhrase = true;
      _note = 'Recovery phrase saved. Write it down somewhere that is not '
          'this device.';
    });

    // And try again with it, which is the whole point of having been asked
    // for one. Saving it and waiting for the next launch is indistinguishable
    // from it not having worked.
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: 'Device sync',
      onBack: () => Navigator.of(context).maybePop(),
      body: ListView(
        padding: OpenTvTouchSpace.page,
        children: [
          const Text(
            'Your devices leave what you have watched in a folder you own, so '
            'a film paused on the television carries on here. Nothing goes to '
            'us — this app has no server. Everything written there is '
            'encrypted before it leaves the device, so the company holding '
            'the folder cannot read it.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.md),
          const Text(
            'Use the same folder on every device. If your television is '
            'already set up, scanning it from Another device brings these '
            'settings across and there is nothing to type here at all.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.lg),
          const Text('WHERE IT GOES', style: OpenTvTouchType.label),
          const SizedBox(height: OpenTvTouchSpace.xs),
          const Text(
            'Any S3-compatible storage: Backblaze B2, Cloudflare R2, Wasabi, '
            'Storj, or your own MinIO. B2 is the shortest route — make a '
            'private bucket, create an application key, and copy the two '
            'strings it gives you.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.lg),
          Text(
            _configured
                ? 'A folder is set up on this device.'
                : 'No folder is set up.',
            style: OpenTvTouchType.data,
          ),
          const SizedBox(height: OpenTvTouchSpace.md),
          TouchField(
            label: 'Endpoint',
            controller: _endpoint,
            hint: 'https://s3.us-west-004.backblazeb2.com',
            // Settled when the field is done with rather than on every
            // keystroke: adding and removing a row mid-list as somebody types
            // is what threw focus around on the television.
            onSubmitted: (text) {
              final needed = _needsRegion(text);
              if (needed != _regionNeeded) {
                setState(() => _regionNeeded = needed);
              }
            },
          ),
          TouchField(
            label: 'Bucket',
            controller: _bucket,
            hint: 'The private bucket you made',
          ),
          TouchField(
            label: 'Access key ID',
            controller: _accessKey,
            hint: _configured ? 'Stored' : 'From your storage account',
            obscure: true,
          ),
          TouchField(
            label: 'Secret access key',
            controller: _secretKey,
            hint: _configured ? 'Stored' : 'From your storage account',
            obscure: true,
          ),
          // Only when the endpoint does not say. Backblaze, AWS, Wasabi and
          // Storj all write it into the hostname and R2 has none, so asking
          // is asking a viewer to copy half of what they just typed.
          if (_regionNeeded)
            TouchField(
              label: 'Region',
              controller: _region,
              hint: 'This endpoint does not say, so it has to be given',
            ),
          if (_note case final note?) ...[
            const SizedBox(height: OpenTvTouchSpace.xs),
            Text(note, style: OpenTvTouchType.caption),
          ],
          const SizedBox(height: OpenTvTouchSpace.sm),
          _Button(label: 'Save', emphasis: true, onTap: _busy ? null : _save),
          const SizedBox(height: OpenTvTouchSpace.sm),
          _Button(
            label: _busy ? 'Working…' : 'Test the connection',
            onTap: _busy ? null : _check,
          ),
          if (_configured) ...[
            const SizedBox(height: OpenTvTouchSpace.sm),
            _Button(
              label: 'Sync now',
              onTap: _busy || widget.sync == null ? null : _run,
            ),
          ],
          const SizedBox(height: OpenTvTouchSpace.xl),
          const Text('RECOVERY PHRASE', style: OpenTvTouchType.label),
          const SizedBox(height: OpenTvTouchSpace.xs),
          Text(
            _hasPhrase
                ? 'A phrase is set on this device. Use the same one everywhere.'
                : 'Your devices normally open the folder with your provider '
                    'password and no phrase is needed. This is the way back in '
                    'when that password changes — which providers do on '
                    'renewal — and the only way in for a device that has no '
                    'provider yet.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.md),
          TouchField(
            label: 'Recovery phrase',
            controller: _phrase,
            hint: 'A few unrelated words',
          ),
          const SizedBox(height: OpenTvTouchSpace.sm),
          _Button(label: 'Save phrase', onTap: _savePhrase),
          const SizedBox(height: OpenTvTouchSpace.sm),
          _Button(
            label: 'Generate one',
            onTap: () => setState(() {
              _phrase.text = newBackupPhrase();
              _note = 'Write this down before saving it.';
            }),
          ),
          const SizedBox(height: OpenTvTouchSpace.xl),
          const Text(
            'What crosses is what you have watched, where you stopped, and '
            'what you have favourited. Your catalogue is not copied — each '
            'device reads that from your provider.',
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
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => TouchTile(
        onTap: onTap,
        minHeight: 50,
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

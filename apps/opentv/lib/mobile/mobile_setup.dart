import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../app/host.dart';
import '../app/settings_screen.dart';
import 'mobile_settings_screens.dart';

/// The three questions asked once, straight after a provider's catalogue
/// lands.
///
/// The television asks them as a sequence of full screens because a d-pad has
/// one focus and a viewer is standing in front of a television with a remote.
/// A phone can hold all three as a scrolling list, and skipping one is a tap
/// rather than a trip to the end of a row.
///
/// Asked at this moment for the reason the television gives: it is the only
/// point where all three are answerable at once. The categories to hide are
/// now known, and whoever is holding the phone is setting things up rather
/// than trying to watch something.
class MobileSetupScreen extends StatefulWidget {
  const MobileSetupScreen({
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
  State<MobileSetupScreen> createState() => _MobileSetupScreenState();
}

class _MobileSetupScreenState extends State<MobileSetupScreen> {
  bool _hasPin = false;
  bool _hasTmdb = false;
  int _lockedCount = 0;
  int _hiddenCount = 0;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final pin = await widget.host.readSecret(SettingsScreen.pinReference);
    final tmdb = await widget.host.readSecret(SettingsScreen.tmdbReference);
    final locked = await widget.db.lockedCategories(widget.source.id);
    final categories = await widget.db.allCategoriesFor(
      widget.source.id,
      ItemKind.movie,
    );
    if (!mounted) return;
    setState(() {
      _hasPin = pin != null;
      _hasTmdb = tmdb != null;
      _lockedCount = locked.length;
      _hiddenCount = categories.where((c) => c.hidden).length;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(pageBuilder: (context, _, _) => screen),
    );
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    return TouchScaffold(
      title: '${widget.source.name} is ready',
      body: ListView(
        padding: const EdgeInsets.all(OpenTvTouchSpace.gutter),
        children: [
          const Text(
            'Three things worth setting now. All of them can wait, and all of '
            'them can be changed later in settings.',
            style: OpenTvTouchType.bodyMuted,
          ),
          const SizedBox(height: OpenTvTouchSpace.xl),
          _Step(
            title: 'Artwork and descriptions',
            detail: _hasTmdb
                ? 'A key is stored. Films will use it.'
                : 'A free TMDB key gets synopses, cast and posters. Without '
                    'one, films show what your provider sent.',
            done: _hasTmdb,
            onTap: () => _push(
              const MobileSecretScreen(
                title: 'TMDB key',
                reference: SettingsScreen.tmdbReference,
                explanation:
                    'Where synopses, cast and artwork come from. TMDB issues '
                    'one per person, free, at themoviedb.org. Either '
                    'credential they give you works. Kept in this device’s '
                    'keystore beside your provider passwords.',
              ),
            ),
          ),
          _Step(
            title: 'Parental lock',
            detail: _hasPin
                ? '$_lockedCount ${_lockedCount == 1 ? 'category is' : 'categories are'} locked.'
                : 'A PIN removes chosen categories from browsing entirely, '
                    'rather than greying them out.',
            done: _hasPin,
            onTap: () => _push(
              const MobileSecretScreen(
                title: 'Parental lock',
                reference: SettingsScreen.pinReference,
                digitsOnly: true,
                explanation:
                    'Categories you lock are removed from browsing entirely '
                    'rather than greyed out, so nothing advertises what is '
                    'behind the PIN. Four digits or more.',
              ),
            ),
          ),
          _Step(
            title: 'Anything you would rather not see',
            detail: _hiddenCount > 0
                ? '$_hiddenCount hidden so far.'
                : 'Providers carry a great deal nobody watches. Hiding a '
                    'category removes it from browsing and search.',
            done: _hiddenCount > 0,
            onTap: () => _push(
              MobileCategoriesScreen(
                db: widget.db,
                sourceId: widget.source.id,
              ),
            ),
          ),
          const SizedBox(height: OpenTvTouchSpace.xl),
          TouchTile(
            onTap: widget.onDone,
            minHeight: 52,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OpenTvColors.tally,
                borderRadius: OpenTvRadius.tile,
              ),
              child: Text(
                'Start watching',
                style: OpenTvTouchType.section
                    .copyWith(color: OpenTvColors.ground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.detail,
    required this.done,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OpenTvTouchSpace.md),
      child: TouchTile(
        onTap: onTap,
        minHeight: 72,
        child: Container(
          padding: const EdgeInsets.all(OpenTvTouchSpace.lg),
          decoration: BoxDecoration(
            color: OpenTvColors.surface,
            borderRadius: OpenTvRadius.tile,
            border: Border(
              bottom: BorderSide(
                color: done ? OpenTvColors.onAir : OpenTvColors.rule,
                width: done ? 2 : 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: OpenTvTouchType.section),
                  ),
                  Text(
                    done ? 'SET' : 'SKIP FOR NOW',
                    style: OpenTvTouchType.label.copyWith(
                      color: done ? OpenTvColors.onAir : OpenTvColors.inkFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OpenTvTouchSpace.xs),
              Text(detail, style: OpenTvTouchType.caption),
            ],
          ),
        ),
      ),
    );
  }
}

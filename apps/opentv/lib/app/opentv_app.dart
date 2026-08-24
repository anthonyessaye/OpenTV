import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'browse_screen.dart';
import 'host.dart';
import 'phone_setup_screen.dart';
import 'setup_screen.dart';
import 'source_service.dart';
import 'stream_resolver.dart';

/// The application.
///
/// No MaterialApp anywhere: the point of the redesign is that nothing
/// inherits Google's design language, on either television. WidgetsApp gives
/// routing and text direction and stops there.
class OpenTvApp extends StatelessWidget {
  OpenTvApp({super.key});

  /// Needed because the back handler is installed above the navigator, in
  /// [WidgetsApp.builder], where the context cannot see it.
  final _navigator = GlobalKey<NavigatorState>();

  /// Pops one screen, or reports that there was nothing to pop.
  ///
  /// Returning false at the root is deliberate: tvOS requires Menu to leave
  /// for the system home screen, and consuming it here would trap the viewer
  /// inside the app — which is also grounds for rejection.
  bool _back() {
    final navigator = _navigator.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    navigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      navigatorKey: _navigator,
      color: OpenTvColors.ground,
      debugShowCheckedModeBanner: false,
      // WidgetsApp has no default text style; without this a Text with no
      // style of its own renders as the debug red-on-yellow.
      textStyle: OpenTvType.body,
      // Every screen is authored on a 1920x1080 canvas and scaled, because
      // Apple TV and Android TV disagree about how many logical pixels
      // describe the same panel — 1920x1080 against 960x540.
      builder: (context, child) => BackKeys(
        onBack: _back,
        child: TvCanvas(child: child ?? const SizedBox()),
      ),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        // Without Material there is no default transition. A fade suits a
        // ten-foot interface; sliding pages read as phone gestures on a
        // screen nobody touches.
        return PageRouteBuilder<T>(
          settings: settings,
          transitionDuration: OpenTvMotion.fade,
          pageBuilder: (context, animation, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
      home: const _Root(),
    );
  }
}

/// Decides what the viewer sees first: onboarding, or their catalogue.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  static const _host = Host();

  OpenTvDatabase? _db;
  SourceService? _service;
  StreamResolver? _resolver;
  List<Source> _sources = const [];
  Source? _source;
  String? _failure;

  /// True while a second provider is being added, so onboarding is shown
  /// over an app that already has one.
  bool _addingSource = false;

  /// Set to the provider that has just finished importing, while the three
  /// one-time questions are asked about it.
  Source? _settingUp;

  /// True while the local setup page is being served.
  ///
  /// Only ever true because somebody asked for it on this screen, and false
  /// again the moment they leave — the server is not something that runs in
  /// the background.
  bool _usingPhone = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _service?.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final directory = await _host.dataDirectory();
      final file = File('$directory/catalogue.sqlite');

      final db = OpenTvDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            // Drift does not enable this and SQLite defaults it off, so
            // without it every ON DELETE CASCADE in the schema is inert and
            // removing a source silently orphans its whole catalogue.
            raw.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );

      final sources = await db.allSources();

      if (!mounted) {
        await db.close();
        return;
      }
      setState(() {
        _db = db;
        _service = SourceService(db: db, host: _host);
        _resolver = StreamResolver(db: db, host: _host);
        _sources = sources;
        _source = sources.isEmpty ? null : sources.first;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  /// Called when onboarding has finished a sync.
  ///
  /// The newest source becomes the active one, because someone who has just
  /// finished adding a provider wants to see it rather than the one they
  /// already had.
  Future<void> _adopt() async {
    final sources = await _db!.allSources();
    if (!mounted || sources.isEmpty) return;
    setState(() {
      _sources = sources;
      _source = sources.last;
      _addingSource = false;
      // Asked once per provider, straight after its catalogue lands. This is
      // the only moment the questions are all answerable at once: the
      // categories to hide are now known, and the viewer is setting things up
      // rather than trying to watch something.
      _settingUp = sources.last;
    });
  }

  Future<void> _removeSource(Source source) async {
    await _db!.removeSource(source.id);
    final sources = await _db!.allSources();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      if (_source?.id == source.id) {
        _source = sources.isEmpty ? null : sources.first;
      }
    });
  }

  /// Asks before closing, and gives every screen a chance first.
  ///
  /// This is the only place on Android where the back button can be caught at
  /// all. The framework routes it to the navigator rather than to the key
  /// handlers, so a screen that wanted the press — search returning to its
  /// keyboard, say — never heard it, and the app closed instead. The registry
  /// is those screens; the panel is what happens when none of them wants it.
  void _onSystemBack() {
    if (BackKeysRegistry.dispatch()) return;

    final navigator = Navigator.of(context);
    navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: OpenTvMotion.fade,
        pageBuilder: (context, animation, _) => ConfirmPanel(
          title: 'Leave OpenTV?',
          detail: 'Nothing is playing that will be lost.',
          confirmLabel: 'QUIT',
          onConfirm: SystemNavigator.pop,
          onCancel: () => Navigator.of(context).pop(),
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only on Android. tvOS requires Menu at the root to return to the system
    // home screen, and an app that refuses is rejected — so there the press
    // goes through, and the key handlers above deal with the rest.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onSystemBack();
        },
        child: _content(),
      );
    }
    return _content();
  }

  Widget _content() {
    if (_failure != null) {
      return Container(
        color: OpenTvColors.ground,
        padding: OpenTvSpace.safe,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This television could not open its store',
                style: OpenTvType.section),
            const SizedBox(height: OpenTvSpace.sm),
            Text(_failure!, style: OpenTvType.bodyMuted),
          ],
        ),
      );
    }

    final db = _db;
    final service = _service;
    if (db == null || service == null) {
      return Container(
        color: OpenTvColors.ground,
        alignment: Alignment.center,
        child: const Text('Starting…', style: OpenTvType.body),
      );
    }

    if (_usingPhone) {
      return PhoneSetupScreen(
        service: service,
        onDone: () async {
          setState(() => _usingPhone = false);
          await _adopt();
        },
        onCancel: () => setState(() => _usingPhone = false),
      );
    }

    final source = _source;
    if (source == null || _addingSource) {
      return OnboardingScreen(
        onUsePhone: () => setState(() => _usingPhone = true),
        // Adding a second provider can be abandoned; a first cannot, because
        // there would be nothing behind it to go back to.
        onCancel: _addingSource
            ? () => setState(() => _addingSource = false)
            : null,
        progress: service.progress,
        onSubmit: (draft) async {
          final failure = await service.add(draft);
          // Navigating on success is the caller's job — the screen stays on
          // its progress stage rather than deciding what comes next.
          if (failure == null) await _adopt();
          return failure;
        },
      );
    }

    final settingUp = _settingUp;
    if (settingUp != null) {
      return SetupScreen(
        db: db,
        source: settingUp,
        onDone: () => setState(() => _settingUp = null),
      );
    }

    return BrowseScreen(
      db: db,
      source: source,
      resolver: _resolver!,
      service: service,
      sources: _sources,
      onSwitchSource: (next) => setState(() => _source = next),
      onAddSource: () => setState(() => _addingSource = true),
      onRemoveSource: _removeSource,
    );
  }
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import '../mobile/mobile_home.dart';
import '../mobile/mobile_onboarding.dart';
import 'browse_screen.dart';
import 'host.dart';
import 'phone_setup_screen.dart';
import 'setup_screen.dart';
import 'source_service.dart';
import 'stream_resolver.dart';
import 'vpn_service.dart';

/// The application, in one of two shapes.
///
/// No MaterialApp anywhere: the point of the redesign is that nothing
/// inherits Google's design language, on any of the four platforms.
/// WidgetsApp gives routing and text direction and stops there.
///
/// [device] decides which interface exists, and it is passed in rather than
/// looked up, because it is settled before the first frame in `main`. It is
/// not a breakpoint: nothing here reacts to a window resizing, because a
/// television does not become a phone.
class OpenTvApp extends StatelessWidget {
  OpenTvApp({super.key, required this.device});

  final DeviceClass device;

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
      textStyle: device.isTelevision ? OpenTvType.body : OpenTvTouchType.body,
      builder: (context, child) {
        final content = child ?? const SizedBox();
        if (!device.isTelevision) {
          // No canvas and no key handling. A phone reports its own pixels
          // honestly, and its back gesture is the system's to deliver
          // through the navigator rather than something to intercept.
          return content;
        }
        // Every television screen is authored on a 1920x1080 canvas and
        // scaled, because Apple TV and Android TV disagree about how many
        // logical pixels describe the same panel — 1920x1080 against 960x540.
        return BackKeys(onBack: _back, child: TvCanvas(child: content));
      },
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        // Without Material there is no default transition, and the right one
        // differs by device rather than by taste. A fade suits a ten-foot
        // interface, where a page sliding in reads as a gesture on a screen
        // nobody is touching. On a handset the opposite holds: a push that
        // does not travel leaves no sense of depth, and the back gesture then
        // has nothing to undo.
        if (device.isTelevision) {
          return PageRouteBuilder<T>(
            settings: settings,
            transitionDuration: OpenTvMotion.fade,
            pageBuilder: (context, animation, _) => builder(context),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          );
        }
        return PageRouteBuilder<T>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            final slide = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));
            return SlideTransition(
              position: animation.drive(slide),
              child: child,
            );
          },
        );
      },
      home: _Root(device: device),
    );
  }
}

/// Decides what the viewer sees first: onboarding, or their catalogue.
class _Root extends StatefulWidget {
  const _Root({required this.device});

  final DeviceClass device;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  static const _host = Host();

  /// The tunnel, held here because it is app-wide and follows the app's own
  /// lifecycle rather than any one screen's.
  final _vpn = VpnService(host: _host);

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

  /// Held until the splash has had its beat, whatever the app is ready to
  /// show underneath.
  ///
  /// A minimum rather than a delay: opening the database and reading the
  /// catalogue often takes longer than this, in which case nothing is spent
  /// waiting. What it buys is a start that always looks the same — a splash
  /// that flashes for eighty milliseconds on one boot and sits for two
  /// seconds on the next reads as a fault rather than as the app opening.
  static const _splashFor = Duration(seconds: 2);
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
    Future<void>.delayed(_splashFor, () {
      if (mounted) setState(() => _splashDone = true);
    });
    // On launch, if there is a tunnel and permission was granted when it was
    // set up, it comes up on its own. A tunnel somebody configured and then
    // has to switch on by hand every time is one they will forget to switch
    // on, and the point of it is that it is carrying the traffic.
    _vpn.connectIfConfigured();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vpn.dispose();
    _service?.dispose();
    _db?.close();
    super.dispose();
  }

  /// Brings the tunnel down when the app is not on screen, and back up when
  /// it is.
  ///
  /// Down, because a tunnel routing a television's traffic while the app that
  /// asked for it is not running is not something anybody agreed to — and on
  /// Android a VpnService left up is a permanent notification and a key icon
  /// for an app that is doing nothing.
  ///
  /// [AppLifecycleState.inactive] is deliberately not acted on. It fires for
  /// a transient loss of focus — a volume overlay, a system toast — and
  /// tearing a tunnel down and rebuilding it for those would interrupt
  /// playback repeatedly for no reason.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Not while the OS is showing the permission dialog this app asked for.
    // That dialog is another activity, so it backgrounds this one — and
    // disconnecting there would undo the thing the viewer is agreeing to.
    if (_vpn.isAwaitingPermission) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _vpn.disconnect();
      case AppLifecycleState.resumed:
        _vpn.connectIfConfigured();
      case AppLifecycleState.inactive:
        break;
    }
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

    // And the tunnel comes up, asking for permission if it has to.
    //
    // This is the one moment that dialog belongs: somebody has just finished
    // setting the television up and is standing in front of it. Every other
    // path deliberately stays quiet, which meant a tunnel configured during
    // setup was never connected and never explained itself — the permission
    // it was waiting for could only be granted by a prompt nothing ever
    // showed.
    await _vpn.connectIfConfigured(mayAsk: true);
  }

  Future<void> _removeSource(Source source) async {
    await _service!.forget(source);
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
    // Before anything else, including the failure below: a television that
    // cannot open its own store should still look like it started.
    if (!_splashDone) return const SplashScreen();

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
        vpn: _vpn,
        onDone: () async {
          setState(() => _usingPhone = false);
          await _adopt();
        },
        onCancel: () => setState(() => _usingPhone = false),
      );
    }

    final source = _source;
    if (source == null || _addingSource) {
      if (!widget.device.isTelevision) {
        return MobileOnboarding(
          progress: service.progress,
          onCancel: _addingSource
              ? () => setState(() => _addingSource = false)
              : null,
          onSubmit: (draft) async {
            final failure = await service.add(draft);
            if (failure == null) await _adopt();
            return failure;
          },
        );
      }
      return OnboardingScreen(
        // Offered only where typing is the problem it solves. A phone has a
        // keyboard; serving itself a form to fill in from a second device
        // would be an imitation of something this device already does better.
        onUsePhone: widget.device.isTelevision
            ? () => setState(() => _usingPhone = true)
            : null,
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

    if (!widget.device.isTelevision) {
      return MobileHome(
        db: db,
        source: source,
        resolver: _resolver!,
        service: service,
        sources: _sources,
        vpn: _vpn,
        onSwitchSource: (next) => setState(() => _source = next),
        onAddSource: () => setState(() => _addingSource = true),
        onRemoveSource: _removeSource,
      );
    }

    return BrowseScreen(
      db: db,
      vpn: _vpn,
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

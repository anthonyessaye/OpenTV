import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'home_screen.dart';
import 'host.dart';
import 'source_service.dart';
import 'stream_resolver.dart';

/// The application.
///
/// No MaterialApp anywhere: the point of the redesign is that nothing
/// inherits Google's design language, on either television. WidgetsApp gives
/// routing and text direction and stops there.
class OpenTvApp extends StatelessWidget {
  const OpenTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: OpenTvColors.ground,
      debugShowCheckedModeBanner: false,
      // WidgetsApp has no default text style; without this a Text with no
      // style of its own renders as the debug red-on-yellow.
      textStyle: OpenTvType.body,
      // Every screen is authored on a 1920x1080 canvas and scaled, because
      // Apple TV and Android TV disagree about how many logical pixels
      // describe the same panel — 1920x1080 against 960x540.
      builder: (context, child) => TvCanvas(child: child ?? const SizedBox()),
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
  Source? _source;
  String? _failure;

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
        _source = sources.isEmpty ? null : sources.first;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _failure = '$error');
    }
  }

  /// Called when onboarding has finished a first sync.
  Future<void> _adopt() async {
    final sources = await _db!.allSources();
    if (!mounted || sources.isEmpty) return;
    setState(() => _source = sources.first);
  }

  @override
  Widget build(BuildContext context) {
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

    final source = _source;
    if (source == null) {
      return OnboardingScreen(
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

    return HomeScreen(db: db, source: source, resolver: _resolver!);
  }
}

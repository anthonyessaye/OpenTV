import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:opentv_core/opentv_core.dart';
import 'package:opentv_ui/opentv_ui.dart';

import 'catalogue_screen.dart';
import 'player_screen.dart';
import 'core_probe.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the point of M4 is that nothing inherits Google's
    // design language. WidgetsApp gives routing and text direction, no more.
    return WidgetsApp(
      color: OpenTvColors.ground,
      debugShowCheckedModeBanner: false,
      // WidgetsApp has no default text style; without this every Text below
      // would need its own, and a missing one renders as the debug red-on-
      // yellow rather than failing loudly.
      textStyle: OpenTvType.body,
      // Without Material there is no default route transition, so one has to
      // be supplied. A plain fade suits a ten-foot interface: sliding pages
      // read as phone gestures on a screen nobody touches.
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          transitionDuration: OpenTvMotion.fade,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeTransition(opacity: animation, child: child),
        );
      },
      home: const Boot(),
    );
  }
}

class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  CoreProbeResult? _probe;
  List<Channel> _channels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final probe = await runCoreProbe();
    var channels = const <Channel>[];
    if (probe.ok && probe.db != null && probe.sourceId != null) {
      channels = await probe.db!.channelsIn(probe.sourceId!, limit: 40);
    }
    if (mounted) {
      setState(() {
        _probe = probe;
        _channels = channels;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final probe = _probe;

    if (probe == null) {
      return Container(
        color: OpenTvColors.ground,
        alignment: Alignment.center,
        child: const Text('Loading catalogue…', style: OpenTvType.body),
      );
    }

    if (!probe.ok || _channels.isEmpty) {
      return Container(
        color: OpenTvColors.ground,
        padding: OpenTvSpace.safe,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Core probe failed', style: OpenTvType.title),
            const SizedBox(height: OpenTvSpace.md),
            for (final line in probe.lines)
              Text(line, style: OpenTvType.bodyMuted),
          ],
        ),
      );
    }

    if (const bool.fromEnvironment('SHOW_DETAIL')) {
      final channel = _channels.first;
      return DetailScreen(
        content: DetailContent(
          kind: DetailKind.film,
          title: 'The Weight of Water',
          subtitle: '2019  ·  Drama, Thriller',
          synopsis:
              'A marine archaeologist returns to a coastal town to survey a '
              'wreck, and finds the community has its own reasons for wanting '
              'it left undisturbed.',
          facts: const [
            (label: 'container', value: 'mkv'),
            (label: 'resolution', value: '1080p'),
            (label: 'rating', value: '7.4'),
            (label: 'added', value: '2023-11-14'),
            (label: 'source', value: 'Portal'),
          ],
          resumePosition: const Duration(minutes: 42, seconds: 18),
          duration: const Duration(hours: 2, minutes: 6),
          isFavourite: true,
        ),
        onPlay: () {},
        onToggleFavourite: () {},
        onBack: () {},
        trailing: SizedBox(
          height: EpisodeTile.preferredHeight + 88,
          child: FocusRow(
            height: EpisodeTile.preferredHeight,
            itemExtent: EpisodeTile.preferredWidth,
            itemCount: _channels.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) => EpisodeTile(
              title: _channels[index].name,
              season: 1,
              episodeNumber: index + 1,
              duration: Duration(minutes: 38 + (index % 5) * 4),
              watched: index < 2,
              onSelect: () {},
            ),
          ),
        ),
      );
    }

    // --dart-define=SHOW_PLAYER=true swaps the catalogue for the player, so
    // both screens can be captured from one build.
    if (const bool.fromEnvironment('SHOW_PLAYER')) {
      return PlayerScreen(
        streamUrl: const String.fromEnvironment(
          'STREAM_URL',
          defaultValue: 'http://127.0.0.1:8123/test_stream.ts',
        ),
        channelName: _channels.first.name,
        channelNumber: _channels.first.number,
        nowTitle: 'Evening News',
        nowStart: DateTime.now().toUtc().subtract(const Duration(minutes: 18)),
        nowEnd: DateTime.now().toUtc().add(const Duration(minutes: 42)),
      );
    }

    return FocusDriver(
      child: CatalogueScreen(
        channels: _channels,
      totalChannels: probe.channelCount,
      totalFilms: probe.filmCount,
        stats: 'SQLITE VIA ${probe.executor}  ·  '
            '${probe.channelCount + probe.filmCount} ROWS ON DEVICE',
      ),
    );
  }
}

/// Walks focus downward on a timer, when asked to.
///
/// Off unless built with --dart-define=AUTO_FOCUS_DEMO=true. It exists so a
/// screenshot can show vertical navigation without a remote in hand, and it
/// drives the same directional traversal the Siri Remote does rather than
/// jumping focus synthetically.
class FocusDriver extends StatefulWidget {
  const FocusDriver({super.key, required this.child});

  final Widget child;

  @override
  State<FocusDriver> createState() => _FocusDriverState();
}

class _FocusDriverState extends State<FocusDriver> {
  Timer? _timer;
  var _steps = 0;

  static const _enabled = bool.fromEnvironment('AUTO_FOCUS_DEMO');

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _steps >= 3) {
        timer.cancel();
        return;
      }
      _steps++;
      FocusManager.instance.primaryFocus?.focusInDirection(
        TraversalDirection.down,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

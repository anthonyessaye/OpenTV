import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../focus/focusable_tile.dart';
import '../tokens/tokens.dart';
import 'player_chrome.dart' show PlayerButton;
import 'system_text_input.dart';
import 'text_entry.dart';
import 'tv_keyboard.dart';

/// The kinds of source a viewer can add.
///
/// Named apart from the core's own `SourceKind` on purpose. This package has
/// no dependency on the domain core — it is a design system, and staying free
/// of the catalogue is what lets it be tested on the VM without a database.
/// The app maps between the two, which is a line of code and keeps the two
/// meanings from being assumed identical when one of them later grows a case
/// the other does not want.
enum OnboardingSourceKind {
  /// An Xtream Codes portal: one host plus credentials, from which the
  /// catalogue, the categories and the guide are all derived.
  xtream,

  /// A plain playlist URL — M3U or M3U8. No account, no guide unless a
  /// separate XMLTV address is given later.
  m3u,
}

/// What the viewer has entered so far.
///
/// The password is held here for exactly as long as the flow runs and is
/// never written to the database; the caller hands it to the platform
/// keystore and stores only the resulting reference. That is why this is a
/// plain value passed once to [OnboardingScreen.onSubmit] rather than state
/// the interface keeps.
class OnboardingDraft {
  const OnboardingDraft({
    required this.kind,
    required this.url,
    this.username = '',
    this.password = '',
    this.name = '',
  });

  final OnboardingSourceKind kind;

  /// The portal address for Xtream, or the playlist address for M3U.
  final String url;

  final String username;
  final String password;

  /// What the viewer calls this provider.
  ///
  /// Asked for rather than derived, because deriving it put a portal hostname
  /// across the top of the home screen — which is both ugly and the one part
  /// of an address worth not reading aloud to a room.
  final String name;
}

/// One field the viewer fills in, in the order they are asked for it.
class _Field {
  const _Field({
    required this.label,
    required this.hint,
    this.obscure = false,
    this.validate,
  });

  final String label;
  final String hint;
  final bool obscure;

  /// Returns a stated problem, or null when the value will do.
  final String? Function(String)? validate;
}

/// Adding the first source: the only screen a viewer sees before the app has
/// anything to show.
///
/// It asks for one thing at a time. A form with several fields and a separate
/// keyboard means the viewer has to steer focus out of the keys, across the
/// screen, into a field, and back again for every value — which is the
/// standard way television sign-in is made miserable. Here the keyboard never
/// moves and never loses focus; the field above it changes.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onSubmit,
    this.progress,
    this.onCancel,
  });

  /// Performs the connection and the first sync. Returns null when the source
  /// is usable, or a sentence explaining why it is not — one the viewer can
  /// act on, not an exception's text.
  ///
  /// On success this screen stays on its progress stage rather than deciding
  /// what comes next: the caller navigates away, because only it knows where
  /// to. Return null without navigating and the viewer is left watching a
  /// finished import.
  final Future<String?> Function(OnboardingDraft) onSubmit;

  /// What the sync is doing, so a long first import is not a blank wait.
  final ValueListenable<String>? progress;

  final VoidCallback? onCancel;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Stage { kind, details, working, failed }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Stage _stage = _Stage.kind;
  OnboardingSourceKind _kind = OnboardingSourceKind.xtream;

  /// Values, one per field of the chosen kind.
  List<String> _values = const [];
  int _index = 0;

  String? _problem;
  String? _failure;

  List<_Field> get _fields => switch (_kind) {
    OnboardingSourceKind.xtream => const [
      _Field(
        label: 'Name this provider',
        hint: 'Living room, Dad’s, anything',
        validate: _validateNotEmpty,
      ),
      _Field(
        label: 'Portal address',
        hint: 'http://example.com:8080',
        validate: _validateUrl,
      ),
      _Field(label: 'Username', hint: '', validate: _validateNotEmpty),
      _Field(
        label: 'Password',
        hint: '',
        obscure: true,
        validate: _validateNotEmpty,
      ),
    ],
    OnboardingSourceKind.m3u => const [
      _Field(
        label: 'Name this playlist',
        hint: 'Sports, Kids, anything',
        validate: _validateNotEmpty,
      ),
      _Field(
        label: 'Playlist address',
        hint: 'http://example.com/playlist.m3u',
        validate: _validateUrl,
      ),
    ],
  };

  static String? _validateNotEmpty(String value) =>
      value.trim().isEmpty ? 'This cannot be empty.' : null;

  static String? _validateUrl(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'This cannot be empty.';
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'That is not a complete address. It needs to start with '
          'http:// or https://';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only http and https addresses work here.';
    }
    return null;
  }

  void _choose(OnboardingSourceKind kind) {
    setState(() {
      _kind = kind;
      _values = List.filled(_fields.length, '');
      _index = 0;
      _problem = null;
      _stage = _Stage.details;
    });
  }

  void _type(String character) {
    setState(() {
      _values[_index] += character;
      _problem = null;
    });
  }

  /// Takes a whole value at once, from the platform's own input.
  void _replace(String text) {
    if (_values[_index] == text) return;
    setState(() {
      _values[_index] = text;
      _problem = null;
    });
  }

  void _delete() {
    final current = _values[_index];
    if (current.isEmpty) {
      // Backing off the start of a field steps to the previous one, which is
      // the only way to correct an earlier answer without restarting.
      if (_index > 0) setState(() => _index--);
      return;
    }
    setState(() {
      _values[_index] = current.substring(0, current.length - 1);
      _problem = null;
    });
  }

  void _advance() {
    final problem = _fields[_index].validate?.call(_values[_index]);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    if (_index < _fields.length - 1) {
      setState(() {
        _index++;
        _problem = null;
      });
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    setState(() {
      _stage = _Stage.working;
      _failure = null;
    });

    final draft = switch (_kind) {
      OnboardingSourceKind.xtream => OnboardingDraft(
        kind: _kind,
        name: _values[0].trim(),
        url: _values[1].trim(),
        username: _values[2].trim(),
        password: _values[3],
      ),
      OnboardingSourceKind.m3u => OnboardingDraft(
        kind: _kind,
        name: _values[0].trim(),
        url: _values[1].trim(),
      ),
    };

    final failure = await widget.onSubmit(draft);
    if (!mounted) return;

    setState(() {
      _failure = failure;
      _stage = failure == null ? _Stage.working : _Stage.failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OpenTvColors.ground,
      padding: OpenTvSpace.safe,
      child: switch (_stage) {
        _Stage.kind => _KindStep(onChoose: _choose, onCancel: widget.onCancel),
        _Stage.details => _DetailsStep(
          field: _fields[_index],
          value: _values[_index],
          problem: _problem,
          step: _index + 1,
          of: _fields.length,
          isLast: _index == _fields.length - 1,
          onKey: _type,
          onDelete: _delete,
          onAdvance: _advance,
          onReplace: _replace,
        ),
        _Stage.working => _WorkingStep(progress: widget.progress),
        _Stage.failed => _FailedStep(
          reason: _failure ?? 'The source could not be added.',
          onRetry: () => setState(() {
            _stage = _Stage.details;
            // Back to the last field, which is where a credential mistake
            // almost always is.
            _index = _fields.length - 1;
          }),
          onStartOver: () => setState(() => _stage = _Stage.kind),
        ),
      },
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(width: 6, height: 34, color: OpenTvColors.tally),
            const SizedBox(width: OpenTvSpace.sm),
            const Text('OPENTV', style: OpenTvType.title),
          ],
        ),
        const SizedBox(height: OpenTvSpace.sm),
        Text(caption, style: OpenTvType.bodyMuted),
      ],
    );
  }
}

class _KindStep extends StatelessWidget {
  const _KindStep({required this.onChoose, this.onCancel});

  final ValueChanged<OnboardingSourceKind> onChoose;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    // The notice sits at the foot of the screen rather than in the flow of
    // the question. Two reasons: it reads as a standing statement about the
    // app rather than a step to get past, and it stops the choice above it
    // being pushed off a 1080-line screen, which is what happened when it
    // was simply appended to the column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _Masthead(caption: 'Nothing has been added yet.'),
              const SizedBox(height: OpenTvSpace.lg),
              const Text(
                'Where do your channels come from?',
                style: OpenTvType.hero,
              ),
              const SizedBox(height: OpenTvSpace.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KindCard(
                      title: 'A provider account',
                      detail: 'An Xtream Codes portal address with a username '
                          'and password. Brings channels, films, series and '
                          'the guide.',
                      autofocus: true,
                      onSelect: () => onChoose(OnboardingSourceKind.xtream),
                    ),
                    const SizedBox(width: OpenTvSpace.md),
                    _KindCard(
                      title: 'A playlist address',
                      detail: 'An M3U or M3U8 link. Brings whatever the '
                          'playlist lists; a guide can be added afterwards.',
                      onSelect: () => onChoose(OnboardingSourceKind.m3u),
                    ),
                  ],
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(height: OpenTvSpace.md),
                PlayerButton(label: 'BACK', onSelect: onCancel),
              ],
            ],
          ),
        ),
        const ContentDisclaimer(),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.title,
    required this.detail,
    required this.onSelect,
    this.autofocus = false,
  });

  final String title;
  final String detail;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      child: _SelectableCard(
        autofocus: autofocus,
        onSelect: onSelect,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: OpenTvType.section),
            const SizedBox(height: OpenTvSpace.sm),
            Text(detail, style: OpenTvType.bodyMuted),
          ],
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.child,
    required this.onSelect,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onSelect: onSelect,
      autofocus: autofocus,
      borderRadius: OpenTvRadius.panel,
      // A large card lifting as much as a small tile looks like it is
      // jumping at the viewer.
      scaleOnFocus: 1.03,
      child: Container(
        padding: const EdgeInsets.all(OpenTvSpace.lg),
        decoration: BoxDecoration(
          color: OpenTvColors.surface,
          borderRadius: OpenTvRadius.panel,
          border: Border.all(color: OpenTvColors.rule),
        ),
        child: child,
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.field,
    required this.value,
    required this.problem,
    required this.step,
    required this.of,
    required this.isLast,
    required this.onKey,
    required this.onDelete,
    required this.onAdvance,
    required this.onReplace,
  });

  final _Field field;
  final String value;
  final String? problem;
  final int step;
  final int of;
  final bool isLast;
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback onAdvance;

  /// Replaces the whole value, which is what arrives from a phone rather
  /// than one character at a time.
  final ValueChanged<String> onReplace;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Masthead(caption: 'Adding a source'),
            Text(
              'STEP $step OF $of',
              style: OpenTvType.data.copyWith(color: OpenTvColors.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: OpenTvSpace.lg),
        SizedBox(
          width: 900,
          child: TextEntryField(
            label: field.label,
            value: value,
            hint: field.hint,
            obscure: field.obscure,
            problem: problem,
            active: true,
          ),
        ),
        const SizedBox(height: OpenTvSpace.xs),
        // The second way in. A remote is a poor typewriter and an address is
        // long; this lets a phone or a paired keyboard finish it.
        SizedBox(
          width: 900,
          child: SystemTextInput(
            value: value,
            obscure: field.obscure,
            onChanged: onReplace,
            onDone: onAdvance,
          ),
        ),
        const SizedBox(height: OpenTvSpace.md),
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: TvKeyboard(
              autofocus: true,
              onKey: onKey,
              onDelete: onDelete,
              // Unavailable while there is nothing to commit — with the hint
              // showing, an empty field explains itself and needs no
              // sentence. Anything else is let through and answered with a
              // stated reason, because "that address is incomplete" is not
              // something a viewer can work out from a greyed-out key.
              onDone: value.isEmpty ? null : onAdvance,
              doneLabel: isLast ? 'CONNECT' : 'NEXT',
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkingStep extends StatelessWidget {
  const _WorkingStep({this.progress});

  final ValueListenable<String>? progress;

  @override
  Widget build(BuildContext context) {
    final listenable = progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Masthead(caption: 'Setting up'),
        const SizedBox(height: OpenTvSpace.xl),
        const Text('Reading your catalogue', style: OpenTvType.hero),
        const SizedBox(height: OpenTvSpace.md),
        // A real provider's first import is tens of thousands of rows and
        // takes a while. Saying which stage is running is the difference
        // between waiting and wondering whether it has hung.
        if (listenable != null)
          ValueListenableBuilder<String>(
            valueListenable: listenable,
            builder: (context, text, _) => Text(
              text,
              style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
            ),
          )
        else
          Text(
            'Working…',
            style: OpenTvType.data.copyWith(color: OpenTvColors.tally),
          ),
        const SizedBox(height: OpenTvSpace.lg),
        const SizedBox(
          width: 900,
          child: Text(
            'This happens once. Later updates only fetch what changed.',
            style: OpenTvType.bodyMuted,
          ),
        ),
      ],
    );
  }
}

class _FailedStep extends StatelessWidget {
  const _FailedStep({
    required this.reason,
    required this.onRetry,
    required this.onStartOver,
  });

  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Masthead(caption: 'That did not work'),
        const SizedBox(height: OpenTvSpace.xl),
        SizedBox(
          width: 1100,
          child: Text(reason, style: OpenTvType.section),
        ),
        const SizedBox(height: OpenTvSpace.lg),
        Row(
          children: [
            PlayerButton(
              label: 'TRY AGAIN',
              emphasis: true,
              autofocus: true,
              onSelect: onRetry,
            ),
            const SizedBox(width: OpenTvSpace.sm),
            PlayerButton(label: 'START OVER', onSelect: onStartOver),
          ],
        ),
      ],
    );
  }
}

/// States plainly that the app carries no content of its own.
///
/// This is a player. It ships with no channels, no films and no playlists, it
/// hosts nothing, and it transmits nothing — everything a viewer sees comes
/// from an address they typed in themselves, from a provider they chose and
/// pay. Saying so on the first screen, before any address is entered, is the
/// point: it is the moment the viewer is deciding what to connect, and it is
/// the only screen every viewer is guaranteed to see.
///
/// Deliberately not buried in an "about" page nobody opens, and deliberately
/// not a dialog to dismiss — a notice that must be clicked away teaches
/// people to click it away.
class ContentDisclaimer extends StatelessWidget {
  const ContentDisclaimer({super.key, this.width = 1180});

  final double width;

  static const text =
      'OpenTV supplies no channels, films or playlists. It hosts no content '
      'and transmits none. Everything you see comes from a provider you '
      'choose and an address you enter. You are responsible for holding the '
      'rights to whatever you connect it to.';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 56, color: OpenTvColors.rule),
          const SizedBox(width: OpenTvSpace.sm),
          const Expanded(
            child: Text(text, style: OpenTvType.bodyMuted),
          ),
        ],
      ),
    );
  }
}

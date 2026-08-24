import '../store/tables.dart' show SourceKind;

/// What somebody filled in on their phone.
///
/// A plain value with no behaviour, so the server can be tested without a
/// database and the app can accept one without knowing it came from a
/// browser rather than from a remote.
class SetupSubmission {
  const SetupSubmission({
    required this.kind,
    required this.name,
    required this.url,
    this.username,
    this.password,
    this.tmdbKey,
    this.wireGuardConfig,
  });

  final SourceKind kind;
  final String name;
  final String url;

  final String? username;

  /// Never stored by the server, never logged, never sent back out. It exists
  /// only long enough to be handed to the keystore.
  final String? password;

  final String? tmdbKey;
  final String? wireGuardConfig;

  /// What this looks like in a log or an error, which is the whole point of
  /// writing it out rather than letting the default do it.
  @override
  String toString() =>
      'SetupSubmission($name, ${kind.name}, $url, '
      'username: ${username == null ? 'none' : 'given'}, '
      'password: ${password == null ? 'none' : 'redacted'}, '
      'tmdbKey: ${tmdbKey == null ? 'none' : 'redacted'}, '
      'tunnel: ${wireGuardConfig == null ? 'none' : 'redacted'})';
}

/// What the browser is told about a submission it made.
enum SetupPhase {
  /// Waiting for someone to pair and fill the form in.
  waiting,

  /// The app is talking to the provider.
  working,

  /// Finished. The server is about to stop.
  done,

  /// The provider refused, and the form is offered again.
  failed,
}

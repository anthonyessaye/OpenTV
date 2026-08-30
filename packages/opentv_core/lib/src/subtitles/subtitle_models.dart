/// One subtitle file somebody could choose.
///
/// Flattened from what OpenSubtitles returns, which nests the part a viewer
/// cares about two levels inside the part the API cares about. Everything
/// here is something the chooser actually shows or sorts by; the rest of the
/// payload is discarded at the edge rather than carried around.
class SubtitleCandidate {
  const SubtitleCandidate({
    required this.fileId,
    required this.language,
    required this.release,
    this.downloads = 0,
    this.rating = 0,
    this.fromTrusted = false,
    this.hearingImpaired = false,
    this.fileName,
  });

  /// What a download is asked for by. Not the subtitle's id — a subtitle can
  /// carry several files and only a file can be fetched.
  final int fileId;

  /// Two-letter code as the API reports it, lowercased.
  final String language;

  /// The provider's own description of what this was ripped from —
  /// `BluRay 1080p`, `WEB-DL`. The one field that says whether the timing
  /// will match, which is the whole question when a subtitle is out of sync.
  final String release;

  final int downloads;
  final double rating;

  /// Uploaded by somebody the site vouches for.
  final bool fromTrusted;

  /// Carries sound description as well as speech. Worth saying rather than
  /// leaving somebody to discover it thirty seconds in.
  final bool hearingImpaired;

  final String? fileName;

  /// Best first: trusted, then rated, then downloaded.
  ///
  /// Downloads alone put a decade-old file for the wrong cut at the top of
  /// every list, because it has had ten years to accumulate them.
  static int compare(SubtitleCandidate a, SubtitleCandidate b) {
    if (a.fromTrusted != b.fromTrusted) return a.fromTrusted ? -1 : 1;
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    return b.downloads.compareTo(a.downloads);
  }

  @override
  String toString() => 'SubtitleCandidate($language, $release)';
}

/// What the service said when it would not serve.
///
/// Its own type because the two cases a viewer meets are different problems
/// with different answers, and "it failed" covers neither: a daily quota is
/// a wait, and a rejected key is a settings screen.
class SubtitleServiceException implements Exception {
  const SubtitleServiceException(this.message, {this.quotaExhausted = false});

  final String message;

  /// The free allowance is a small number of downloads a day. Hitting it is
  /// ordinary rather than exceptional, so it is said plainly.
  final bool quotaExhausted;

  @override
  String toString() => 'SubtitleServiceException: $message';
}

/// Provider-agnostic domain core for OpenTV.
///
/// Deliberately a plain Dart package with no Flutter dependency: it runs on
/// the VM, tests in milliseconds, and is unaffected by decisions about the
/// UI or the playback engine.
library;

export 'src/epg/epg_models.dart';
export 'src/epg/xmltv_parser.dart';
export 'src/legacy/legacy_import.dart';
export 'src/metadata/title_cleaner.dart';
export 'src/metadata/tmdb_client.dart';
export 'src/metadata/tmdb_models.dart';
export 'src/playlist/m3u_parser.dart';
export 'src/playlist/playlist_entry.dart';
export 'src/store/database.dart';
export 'src/store/search_text.dart';
export 'src/store/tables.dart';
export 'src/sync/m3u_fetcher.dart';
export 'src/sync/sync_engine.dart';
export 'src/sync/transport.dart';
export 'src/sync/xtream_fetcher.dart';
export 'src/setup/setup_server.dart';
export 'src/setup/setup_submission.dart';
export 'src/vpn/wireguard_config.dart';
export 'src/xtream/catchup.dart';
export 'src/xtream/coerce.dart';
export 'src/xtream/xtream_account.dart';
export 'src/xtream/xtream_credentials.dart';
export 'src/xtream/xtream_models.dart';
export 'src/xtream/xtream_urls.dart';
export 'src/handover/handover_transfer.dart';
export 'src/handover/handover_bundle.dart';
export 'src/handover/handover_pairing.dart';
export 'src/handover/handover_client.dart';
export 'src/store/region_filter.dart';
export 'src/handover/handover_frames.dart';

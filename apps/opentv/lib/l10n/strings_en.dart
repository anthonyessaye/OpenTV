// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class StringsEn extends Strings {
  StringsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'OpenTV';

  @override
  String get navLive => 'Live';

  @override
  String get navFilms => 'Films';

  @override
  String get navSeries => 'Series';

  @override
  String get navSearch => 'Search';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionBack => 'Back';

  @override
  String get actionPlay => 'Play';

  @override
  String get actionPause => 'Pause';

  @override
  String get actionCancel => 'Cancel';

  @override
  String resumeFrom(String position) {
    return 'Resume from $position';
  }

  @override
  String get onAir => 'ON AIR';

  @override
  String channelNumber(int number) {
    return 'Channel $number';
  }

  @override
  String episodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
      zero: 'No episodes',
    );
    return '$_temp0';
  }

  @override
  String get contentDisclaimer =>
      'OpenTV supplies no channels, films or playlists. Everything you see in it comes from a provider you choose and an address you enter.';

  @override
  String get handoverOffer => 'Hand this setup to another device';

  @override
  String get handoverExplain =>
      'Point the other device\'s camera at this code. It will carry your providers, their passwords, your catalogue and your history.';

  @override
  String get handoverExpires =>
      'The code stops working when you leave this screen.';

  @override
  String get providerPasswordGone =>
      'This provider\'s password is no longer stored on this device.';
}

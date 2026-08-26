import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'strings_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of Strings
/// returned by `Strings.of(context)`.
///
/// Applications need to include `Strings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: Strings.localizationsDelegates,
///   supportedLocales: Strings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the Strings.supportedLocales
/// property.
abstract class Strings {
  Strings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static Strings of(BuildContext context) {
    return Localizations.of<Strings>(context, Strings)!;
  }

  static const LocalizationsDelegate<Strings> delegate = _StringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application's name. Not translated — it is a mark.
  ///
  /// In en, this message translates to:
  /// **'OpenTV'**
  String get appName;

  /// Bottom bar: live channels.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get navLive;

  /// Bottom bar: films.
  ///
  /// In en, this message translates to:
  /// **'Films'**
  String get navFilms;

  /// Bottom bar: series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get navSeries;

  /// Bottom bar: search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Bottom bar: settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Returns to the previous screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Starts playback from the beginning.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// Pauses playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get actionPause;

  /// Dismisses without doing anything.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Continues a film or episode from where it stopped.
  ///
  /// In en, this message translates to:
  /// **'Resume from {position}'**
  String resumeFrom(String position);

  /// Badge on a live stream. Upper case in English; other languages should use whatever their own convention is for this emphasis rather than forcing capitals, which many scripts do not have.
  ///
  /// In en, this message translates to:
  /// **'ON AIR'**
  String get onAir;

  /// A channel's position in the provider's list.
  ///
  /// In en, this message translates to:
  /// **'Channel {number}'**
  String channelNumber(int number);

  /// How many episodes a series has. Written as a plural rather than 'N episode(s)' because Arabic has six plural forms and English's two are not a template for them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No episodes} =1{1 episode} other{{count} episodes}}'**
  String episodeCount(int count);

  /// Shown during setup and in settings. Legally load-bearing: translate the meaning exactly and do not soften it.
  ///
  /// In en, this message translates to:
  /// **'OpenTV supplies no channels, films or playlists. Everything you see in it comes from a provider you choose and an address you enter.'**
  String get contentDisclaimer;

  /// Starts offering this device's setup.
  ///
  /// In en, this message translates to:
  /// **'Hand this setup to another device'**
  String get handoverOffer;

  /// What the QR code will transfer.
  ///
  /// In en, this message translates to:
  /// **'Point the other device\'s camera at this code. It will carry your providers, their passwords, your catalogue and your history.'**
  String get handoverExplain;

  /// The offer window is the screen.
  ///
  /// In en, this message translates to:
  /// **'The code stops working when you leave this screen.'**
  String get handoverExpires;

  /// Shown when a keystore entry is missing, which happens after clearing app data or restoring a backup without the keystore.
  ///
  /// In en, this message translates to:
  /// **'This provider\'s password is no longer stored on this device.'**
  String get providerPasswordGone;
}

class _StringsDelegate extends LocalizationsDelegate<Strings> {
  const _StringsDelegate();

  @override
  Future<Strings> load(Locale locale) {
    return SynchronousFuture<Strings>(lookupStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_StringsDelegate old) => false;
}

Strings lookupStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return StringsEn();
  }

  throw FlutterError(
    'Strings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

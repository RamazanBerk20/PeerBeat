import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Local + LAN music player'**
  String get appTagline;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get commonDuplicate;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @nowPlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlayingTitle;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get repeatOne;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @volumePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% volume'**
  String volumePercent(int percent);

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get upNext;

  /// No description provided for @queueIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueIsEmpty;

  /// No description provided for @noLyricsFound.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found'**
  String get noLyricsFound;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerActive.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer: {remaining}'**
  String sleepTimerActive(String remaining);

  /// No description provided for @sleepTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get sleepTurnOff;

  /// No description provided for @sleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String sleepMinutes(int count);

  /// No description provided for @seekFailed.
  ///
  /// In en, this message translates to:
  /// **'Seek failed: {error}'**
  String seekFailed(Object error);

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Playback failed: {error}'**
  String playbackFailed(Object error);

  /// No description provided for @editMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit metadata'**
  String get editMetadata;

  /// No description provided for @batchEditHint.
  ///
  /// In en, this message translates to:
  /// **'Tick a field to apply it to all selected tracks; the rest stay as they are.'**
  String get batchEditHint;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @accentDefault.
  ///
  /// In en, this message translates to:
  /// **'Default accent'**
  String get accentDefault;

  /// No description provided for @positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position {time}'**
  String positionLabel(String time);

  /// No description provided for @setPinFirst.
  ///
  /// In en, this message translates to:
  /// **'Set a 4–6 digit PIN first'**
  String get setPinFirst;

  /// No description provided for @pinMustBeDigits.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4–6 digits'**
  String get pinMustBeDigits;

  /// No description provided for @sharingNamed.
  ///
  /// In en, this message translates to:
  /// **'Sharing \"{name}\"'**
  String sharingNamed(String name);

  /// No description provided for @stoppedSharingNamed.
  ///
  /// In en, this message translates to:
  /// **'Stopped sharing \"{name}\"'**
  String stoppedSharingNamed(String name);

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist (\";\"-separated)'**
  String get fieldArtist;

  /// No description provided for @fieldAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get fieldAlbum;

  /// No description provided for @fieldAlbumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album artist'**
  String get fieldAlbumArtist;

  /// No description provided for @fieldGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre (\";\"-separated)'**
  String get fieldGenre;

  /// No description provided for @fieldYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get fieldYear;

  /// No description provided for @fieldTrackNo.
  ///
  /// In en, this message translates to:
  /// **'Track #'**
  String get fieldTrackNo;

  /// No description provided for @editNTracks.
  ///
  /// In en, this message translates to:
  /// **'Edit {count} tracks'**
  String editNTracks(int count);

  /// No description provided for @couldNotReadTags.
  ///
  /// In en, this message translates to:
  /// **'Could not read tags: {error}'**
  String couldNotReadTags(Object error);

  /// No description provided for @tracksNotUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} track could not be updated} other{{count} tracks could not be updated}}'**
  String tracksNotUpdated(int count);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(Object error);

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @dynamicTheme.
  ///
  /// In en, this message translates to:
  /// **'Dynamic theme from album art'**
  String get dynamicTheme;

  /// No description provided for @dynamicThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tint the app with the current track\'s colors'**
  String get dynamicThemeSubtitle;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentDynamicHint.
  ///
  /// In en, this message translates to:
  /// **'Fallback when album art has no strong colour'**
  String get accentDynamicHint;

  /// No description provided for @accentPickHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the app accent'**
  String get accentPickHint;

  /// No description provided for @stereoWidening.
  ///
  /// In en, this message translates to:
  /// **'Stereo widening'**
  String get stereoWidening;

  /// No description provided for @stereoWideningHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust mid/side width on desktop output. 100% leaves the file unchanged.'**
  String get stereoWideningHint;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @crossfade.
  ///
  /// In en, this message translates to:
  /// **'Crossfade'**
  String get crossfade;

  /// No description provided for @crossfadeHint.
  ///
  /// In en, this message translates to:
  /// **'Overlap the end of one track with the start of the next (desktop). 0 disables it.'**
  String get crossfadeHint;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @outputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get outputDevice;

  /// No description provided for @outputDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the desktop audio output. Android routing follows the system output.'**
  String get outputDeviceHint;

  /// No description provided for @couldNotListDevices.
  ///
  /// In en, this message translates to:
  /// **'Could not list devices: {error}'**
  String couldNotListDevices(Object error);

  /// No description provided for @refreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get refreshDevices;

  /// No description provided for @audioOutput.
  ///
  /// In en, this message translates to:
  /// **'Audio output'**
  String get audioOutput;

  /// No description provided for @replayGain.
  ///
  /// In en, this message translates to:
  /// **'ReplayGain'**
  String get replayGain;

  /// No description provided for @replayGainHint.
  ///
  /// In en, this message translates to:
  /// **'Even out perceived loudness between tracks using gain tags.'**
  String get replayGainHint;

  /// No description provided for @equalizerHint.
  ///
  /// In en, this message translates to:
  /// **'Desktop playback applies EQ live. Android EQ uses the same saved settings and will be active with the Android audio-effects pass.'**
  String get equalizerHint;

  /// No description provided for @replayGainOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get replayGainOff;

  /// No description provided for @replayGainTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get replayGainTrack;

  /// No description provided for @replayGainAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get replayGainAlbum;

  /// No description provided for @preamp.
  ///
  /// In en, this message translates to:
  /// **'Pre-amp'**
  String get preamp;

  /// No description provided for @equalizer10Band.
  ///
  /// In en, this message translates to:
  /// **'10-band equalizer'**
  String get equalizer10Band;

  /// No description provided for @saveCustom.
  ///
  /// In en, this message translates to:
  /// **'Save custom'**
  String get saveCustom;

  /// No description provided for @eqPre.
  ///
  /// In en, this message translates to:
  /// **'Pre'**
  String get eqPre;

  /// No description provided for @saveEqPreset.
  ///
  /// In en, this message translates to:
  /// **'Save EQ preset'**
  String get saveEqPreset;

  /// No description provided for @presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get presetName;

  /// No description provided for @couldNotSavePreset.
  ///
  /// In en, this message translates to:
  /// **'Could not save preset: {error}'**
  String couldNotSavePreset(Object error);

  /// No description provided for @couldNotDeletePreset.
  ///
  /// In en, this message translates to:
  /// **'Could not delete preset: {error}'**
  String couldNotDeletePreset(Object error);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @updatesManaged.
  ///
  /// In en, this message translates to:
  /// **'Managed by your package manager (AUR / .deb / AppImage).'**
  String get updatesManaged;

  /// No description provided for @checkAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get checkAutomatically;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @onLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version'**
  String get onLatestVersion;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed: {error}'**
  String updateCheckFailed(Object error);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'PeerBeat {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get updateSkip;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateToVersion.
  ///
  /// In en, this message translates to:
  /// **'Update to {version}'**
  String updateToVersion(String version);

  /// No description provided for @downloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String downloadingPercent(int percent);

  /// No description provided for @startingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Starting installer…'**
  String get startingInstaller;

  /// No description provided for @downloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & install'**
  String get downloadAndInstall;

  /// No description provided for @invalidRules.
  ///
  /// In en, this message translates to:
  /// **'Invalid rules: {error}'**
  String invalidRules(Object error);

  /// No description provided for @enterAName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get enterAName;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String couldNotSave(Object error);

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @ruleMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get ruleMatch;

  /// No description provided for @ruleMatchAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ruleMatchAll;

  /// No description provided for @ruleMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get ruleMatchAny;

  /// No description provided for @ofTheseRules.
  ///
  /// In en, this message translates to:
  /// **'of these rules'**
  String get ofTheseRules;

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// No description provided for @newSmartPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New smart playlist'**
  String get newSmartPlaylist;

  /// No description provided for @editSmartPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Edit smart playlist'**
  String get editSmartPlaylist;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @matchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} match} other{{count} matches}}'**
  String matchesCount(int count);

  /// No description provided for @limitOptional.
  ///
  /// In en, this message translates to:
  /// **'Limit (optional)'**
  String get limitOptional;

  /// No description provided for @ruleValueHint.
  ///
  /// In en, this message translates to:
  /// **'value'**
  String get ruleValueHint;

  /// No description provided for @removeRule.
  ///
  /// In en, this message translates to:
  /// **'Remove rule'**
  String get removeRule;

  /// No description provided for @noTracksMatchRules.
  ///
  /// In en, this message translates to:
  /// **'No tracks match these rules'**
  String get noTracksMatchRules;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playAll;

  /// No description provided for @sharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get sharingTitle;

  /// No description provided for @sharingHint.
  ///
  /// In en, this message translates to:
  /// **'Pick what peers on your network can stream or download. Changes apply immediately while you are sharing.'**
  String get sharingHint;

  /// No description provided for @wholeLibrary.
  ///
  /// In en, this message translates to:
  /// **'Whole library'**
  String get wholeLibrary;

  /// No description provided for @noPlaylistsYet.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylistsYet;

  /// No description provided for @couldNotUpdateSharing.
  ///
  /// In en, this message translates to:
  /// **'Could not update sharing: {error}'**
  String couldNotUpdateSharing(Object error);

  /// No description provided for @accessLabel.
  ///
  /// In en, this message translates to:
  /// **'Access: '**
  String get accessLabel;

  /// No description provided for @accessOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get accessOpen;

  /// No description provided for @accessPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get accessPin;

  /// No description provided for @accessApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get accessApproved;

  /// No description provided for @peersCanLabel.
  ///
  /// In en, this message translates to:
  /// **'Peers can: '**
  String get peersCanLabel;

  /// No description provided for @streamOnly.
  ///
  /// In en, this message translates to:
  /// **'Stream only'**
  String get streamOnly;

  /// No description provided for @streamAndDownload.
  ///
  /// In en, this message translates to:
  /// **'Stream + download'**
  String get streamAndDownload;

  /// No description provided for @notShared.
  ///
  /// In en, this message translates to:
  /// **'Not shared'**
  String get notShared;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN (leave blank to keep)'**
  String get changePin;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set a 4–6 digit PIN'**
  String get setPin;

  /// No description provided for @approvedModeHint.
  ///
  /// In en, this message translates to:
  /// **'Each new device asks to connect; you allow or deny it on the Network screen (tick \"Always\" to remember a device).'**
  String get approvedModeHint;

  /// No description provided for @downloadedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Downloaded \"{title}\" to your library'**
  String downloadedToLibrary(String title);

  /// No description provided for @downloadedBulk.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {done} of {total} tracks{failed} to your library'**
  String downloadedBulk(int done, int total, String failed);

  /// No description provided for @bulkFailedSuffix.
  ///
  /// In en, this message translates to:
  /// **' ({count} failed)'**
  String bulkFailedSuffix(int count);

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(Object error);

  /// No description provided for @joinedParty.
  ///
  /// In en, this message translates to:
  /// **'Joined party — following the host'**
  String get joinedParty;

  /// No description provided for @couldNotJoinParty.
  ///
  /// In en, this message translates to:
  /// **'Could not join party: {error}'**
  String couldNotJoinParty(Object error);

  /// No description provided for @downloadAllToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Download all to my library'**
  String get downloadAllToLibrary;

  /// No description provided for @downloadToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Download to my library'**
  String get downloadToLibrary;

  /// No description provided for @reconnectingToParty.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting to party… (tap to leave)'**
  String get reconnectingToParty;

  /// No description provided for @leaveParty.
  ///
  /// In en, this message translates to:
  /// **'Leave party'**
  String get leaveParty;

  /// No description provided for @joinPartySync.
  ///
  /// In en, this message translates to:
  /// **'Join party (sync to host)'**
  String get joinPartySync;

  /// No description provided for @nothingSharedHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared here'**
  String get nothingSharedHere;

  /// No description provided for @requestedTrack.
  ///
  /// In en, this message translates to:
  /// **'Requested \"{title}\"'**
  String requestedTrack(String title);

  /// No description provided for @joinToRequest.
  ///
  /// In en, this message translates to:
  /// **'Join the party to request tracks'**
  String get joinToRequest;

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkTitle;

  /// No description provided for @lanOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'Local network only — nothing leaves your Wi-Fi. No cloud, no accounts.'**
  String get lanOnlyBanner;

  /// No description provided for @sharingOnPort.
  ///
  /// In en, this message translates to:
  /// **'Sharing on port {port} as \"{name}\"'**
  String sharingOnPort(String port, String name);

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @manageWhatIShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Playlists or the whole library, with access mode & PIN'**
  String get manageWhatIShareSubtitle;

  /// No description provided for @revokeAllSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect everyone; they must re-authenticate'**
  String get revokeAllSubtitle;

  /// No description provided for @partyModeOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connected peers follow your playback in sync'**
  String get partyModeOnSubtitle;

  /// No description provided for @partyModeOffSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a synchronized session for peers'**
  String get partyModeOffSubtitle;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @approvalRequests.
  ///
  /// In en, this message translates to:
  /// **'Approval requests'**
  String get approvalRequests;

  /// No description provided for @partyRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Party requests'**
  String get partyRequestsTitle;

  /// No description provided for @peerAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed {peer}'**
  String peerAllowed(String peer);

  /// No description provided for @peerDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied {peer}'**
  String peerDenied(String peer);

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get incorrectPin;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — wait a moment and retry'**
  String get tooManyAttempts;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied: {detail}'**
  String accessDenied(String detail);

  /// No description provided for @pinDigitsHint.
  ///
  /// In en, this message translates to:
  /// **'4–6 digits'**
  String get pinDigitsHint;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @ipExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.42:54213'**
  String get ipExampleHint;

  /// No description provided for @hostNotSharing.
  ///
  /// In en, this message translates to:
  /// **'{name} isn\'t sharing anything right now'**
  String hostNotSharing(String name);

  /// No description provided for @sharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by {name}'**
  String sharedBy(String name);

  /// No description provided for @couldNotReachHost.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {name}: {error}'**
  String couldNotReachHost(String name, Object error);

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to allow you…'**
  String get waitingForHost;

  /// No description provided for @hostDenied.
  ///
  /// In en, this message translates to:
  /// **'The host denied your request'**
  String get hostDenied;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @connectByIp.
  ///
  /// In en, this message translates to:
  /// **'Connect by IP'**
  String get connectByIp;

  /// No description provided for @enterAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter address and port, e.g. 192.168.1.42:54213'**
  String get enterAddressHint;

  /// No description provided for @shareMyLibrary.
  ///
  /// In en, this message translates to:
  /// **'Share my library'**
  String get shareMyLibrary;

  /// No description provided for @manageWhatIShare.
  ///
  /// In en, this message translates to:
  /// **'Manage what I share'**
  String get manageWhatIShare;

  /// No description provided for @revokeAllPeerAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke all peer access'**
  String get revokeAllPeerAccess;

  /// No description provided for @allSessionsRevoked.
  ///
  /// In en, this message translates to:
  /// **'All peer sessions revoked'**
  String get allSessionsRevoked;

  /// No description provided for @partyMode.
  ///
  /// In en, this message translates to:
  /// **'Party mode'**
  String get partyMode;

  /// No description provided for @discoveredHosts.
  ///
  /// In en, this message translates to:
  /// **'Discovered hosts'**
  String get discoveredHosts;

  /// No description provided for @connectByIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Connect by IP address'**
  String get connectByIpAddress;

  /// No description provided for @reachHostManually.
  ///
  /// In en, this message translates to:
  /// **'Reach a host manually if it isn\'t discovered'**
  String get reachHostManually;

  /// No description provided for @noHostsFound.
  ///
  /// In en, this message translates to:
  /// **'No hosts found on the network'**
  String get noHostsFound;

  /// No description provided for @connectionsAndActivity.
  ///
  /// In en, this message translates to:
  /// **'Connections & activity'**
  String get connectionsAndActivity;

  /// No description provided for @noPeersConnected.
  ///
  /// In en, this message translates to:
  /// **'No peers connected'**
  String get noPeersConnected;

  /// No description provided for @activeSession.
  ///
  /// In en, this message translates to:
  /// **'Active session'**
  String get activeSession;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @clearActivity.
  ///
  /// In en, this message translates to:
  /// **'Clear activity'**
  String get clearActivity;

  /// No description provided for @peerWantsToConnect.
  ///
  /// In en, this message translates to:
  /// **'{peer} wants to connect to \"{label}\"'**
  String peerWantsToConnect(String peer, String label);

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get allowOnce;

  /// No description provided for @alwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get alwaysAllow;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @requestedByPeer.
  ///
  /// In en, this message translates to:
  /// **'Requested by {peer}'**
  String requestedByPeer(String peer);

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String scanFailed(Object error);

  /// No description provided for @scanSummary.
  ///
  /// In en, this message translates to:
  /// **'Scanned: {added} added, {updated} updated, {skipped} unchanged, {errors} errors'**
  String scanSummary(int added, int updated, int skipped, int errors);

  /// No description provided for @dropFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Drop a folder to add it to your library'**
  String get dropFolderHint;

  /// No description provided for @scanMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Scan a music folder'**
  String get scanMusicFolder;

  /// No description provided for @folderPath.
  ///
  /// In en, this message translates to:
  /// **'Folder path'**
  String get folderPath;

  /// No description provided for @libraryFolders.
  ///
  /// In en, this message translates to:
  /// **'Library folders'**
  String get libraryFolders;

  /// No description provided for @scanFolder.
  ///
  /// In en, this message translates to:
  /// **'Scan folder'**
  String get scanFolder;

  /// No description provided for @rescanSummary.
  ///
  /// In en, this message translates to:
  /// **'Rescan: {added} added, {updated} updated, {removed} removed'**
  String rescanSummary(int added, int updated, int removed);

  /// No description provided for @removeFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Forget \"{path}\" and remove its tracks from the library? Files on disk are not deleted.'**
  String removeFolderBody(String path);

  /// No description provided for @watchingForChanges.
  ///
  /// In en, this message translates to:
  /// **'Watching for changes'**
  String get watchingForChanges;

  /// No description provided for @notWatchingManual.
  ///
  /// In en, this message translates to:
  /// **'Not watching (scan manually)'**
  String get notWatchingManual;

  /// No description provided for @watchingTapToStop.
  ///
  /// In en, this message translates to:
  /// **'Watching — tap to stop'**
  String get watchingTapToStop;

  /// No description provided for @notWatchingTapToWatch.
  ///
  /// In en, this message translates to:
  /// **'Not watching — tap to watch'**
  String get notWatchingTapToWatch;

  /// No description provided for @rescanFailed.
  ///
  /// In en, this message translates to:
  /// **'Rescan failed: {error}'**
  String rescanFailed(Object error);

  /// No description provided for @couldNotChangeWatching.
  ///
  /// In en, this message translates to:
  /// **'Could not change watching: {error}'**
  String couldNotChangeWatching(Object error);

  /// No description provided for @removeFolderQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove folder?'**
  String get removeFolderQuestion;

  /// No description provided for @rescanAll.
  ///
  /// In en, this message translates to:
  /// **'Rescan all'**
  String get rescanAll;

  /// No description provided for @noFoldersYet.
  ///
  /// In en, this message translates to:
  /// **'No folders yet — use \"Scan folder\".'**
  String get noFoldersYet;

  /// No description provided for @findDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Find duplicates'**
  String get findDuplicates;

  /// No description provided for @couldNotRemove.
  ///
  /// In en, this message translates to:
  /// **'Could not remove: {error}'**
  String couldNotRemove(Object error);

  /// No description provided for @duplicateTracks.
  ///
  /// In en, this message translates to:
  /// **'Duplicate tracks'**
  String get duplicateTracks;

  /// No description provided for @copiesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} copies · {title}'**
  String copiesCount(int count, String title);

  /// No description provided for @noDuplicatesFound.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found.'**
  String get noDuplicatesFound;

  /// No description provided for @removeExtras.
  ///
  /// In en, this message translates to:
  /// **'Remove extras'**
  String get removeExtras;

  /// No description provided for @kept.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get kept;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists, albums…'**
  String get searchHint;

  /// No description provided for @nowPlayingSemantic.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get nowPlayingSemantic;

  /// No description provided for @addedToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added {count} to queue'**
  String addedToQueue(int count);

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get addToQueue;

  /// No description provided for @editTags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get editTags;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @trackActions.
  ///
  /// In en, this message translates to:
  /// **'Track actions'**
  String get trackActions;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @queuedTrack.
  ///
  /// In en, this message translates to:
  /// **'Queued \"{title}\"'**
  String queuedTrack(String title);

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String failedToLoad(Object error);

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmpty;

  /// No description provided for @libraryEmptyHintDrop.
  ///
  /// In en, this message translates to:
  /// **'Drag a music folder here, or use the scan button in the top bar to add one.'**
  String get libraryEmptyHintDrop;

  /// No description provided for @libraryEmptyHintTap.
  ///
  /// In en, this message translates to:
  /// **'Tap the scan button in the top bar to add a music folder.'**
  String get libraryEmptyHintTap;

  /// No description provided for @importPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Import playlist (M3U / PLS)'**
  String get importPlaylistTitle;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @importedTracks.
  ///
  /// In en, this message translates to:
  /// **'Imported {matched}/{total} tracks'**
  String importedTracks(int matched, int total);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(Object error);

  /// No description provided for @deleteSmartPlaylistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete smart playlist?'**
  String get deleteSmartPlaylistQuestion;

  /// No description provided for @deleteNamedPermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" permanently?'**
  String deleteNamedPermanently(String name);

  /// No description provided for @smart.
  ///
  /// In en, this message translates to:
  /// **'Smart'**
  String get smart;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @autoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Auto playlists'**
  String get autoPlaylists;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get mostPlayed;

  /// No description provided for @neverPlayed.
  ///
  /// In en, this message translates to:
  /// **'Never Played'**
  String get neverPlayed;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @smartPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Smart playlists'**
  String get smartPlaylists;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} track} other{{count} tracks}}'**
  String trackCount(int count);

  /// No description provided for @exportEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Export…'**
  String get exportEllipsis;

  /// No description provided for @couldNotRemoveTrack.
  ///
  /// In en, this message translates to:
  /// **'Could not remove track: {error}'**
  String couldNotRemoveTrack(Object error);

  /// No description provided for @couldNotReorderPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Could not reorder playlist: {error}'**
  String couldNotReorderPlaylist(Object error);

  /// No description provided for @playPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Play playlist'**
  String get playPlaylist;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get unknownArtist;

  /// No description provided for @exportPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Export playlist'**
  String get exportPlaylistTitle;

  /// No description provided for @noTracksInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'No tracks in this playlist'**
  String get noTracksInPlaylist;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get renamePlaylist;

  /// No description provided for @duplicatePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Duplicate playlist'**
  String get duplicatePlaylist;

  /// No description provided for @exportedPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Exported \"{name}\"'**
  String exportedPlaylist(String name);

  /// No description provided for @deletePlaylistQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist?'**
  String get deletePlaylistQuestion;

  /// No description provided for @addedTrackToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added \"{title}\" to {playlist}'**
  String addedTrackToPlaylist(String title, String playlist);

  /// No description provided for @noAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums'**
  String get noAlbums;

  /// No description provided for @noArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists'**
  String get noArtists;

  /// No description provided for @artistSummary.
  ///
  /// In en, this message translates to:
  /// **'{albums} albums • {tracks} tracks'**
  String artistSummary(int albums, int tracks);

  /// No description provided for @noGenres.
  ///
  /// In en, this message translates to:
  /// **'No genres'**
  String get noGenres;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

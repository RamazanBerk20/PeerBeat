// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Local + LAN music player';

  @override
  String get trayShow => 'Show PeerBeat';

  @override
  String get trayQuit => 'Quit';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDone => 'Done';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonDuplicate => 'Duplicate';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonNext => 'Next';

  @override
  String get nowPlayingTitle => 'Now Playing';

  @override
  String get pause => 'Pause';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAll => 'Repeat all';

  @override
  String get repeatOne => 'Repeat one';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String volumePercent(int percent) {
    return '$percent% volume';
  }

  @override
  String get shuffle => 'Shuffle';

  @override
  String get queue => 'Queue';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get upNext => 'Up next';

  @override
  String get queueIsEmpty => 'Queue is empty';

  @override
  String get noLyricsFound => 'No lyrics found';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String sleepTimerActive(String remaining) {
    return 'Sleep timer: $remaining';
  }

  @override
  String get sleepTurnOff => 'Turn off';

  @override
  String sleepMinutes(int count) {
    return '$count minutes';
  }

  @override
  String seekFailed(Object error) {
    return 'Seek failed: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Playback failed: $error';
  }

  @override
  String get editMetadata => 'Edit metadata';

  @override
  String get batchEditHint =>
      'Tick a field to apply it to all selected tracks; the rest stay as they are.';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get accentDefault => 'Default accent';

  @override
  String positionLabel(String time) {
    return 'Position $time';
  }

  @override
  String get setPinFirst => 'Set a 4–6 digit PIN first';

  @override
  String get pinMustBeDigits => 'PIN must be 4–6 digits';

  @override
  String sharingNamed(String name) {
    return 'Sharing \"$name\"';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'Stopped sharing \"$name\"';
  }

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldArtist => 'Artist (\";\"-separated)';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Album artist';

  @override
  String get fieldGenre => 'Genre (\";\"-separated)';

  @override
  String get fieldYear => 'Year';

  @override
  String get fieldTrackNo => 'Track #';

  @override
  String editNTracks(int count) {
    return 'Edit $count tracks';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'Could not read tags: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks could not be updated',
      one: '$count track could not be updated',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get dynamicTheme => 'Dynamic theme from album art';

  @override
  String get dynamicThemeSubtitle =>
      'Tint the app with the current track\'s colors';

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentDynamicHint =>
      'Fallback when album art has no strong colour';

  @override
  String get accentPickHint => 'Pick the app accent';

  @override
  String get stereoWidening => 'Stereo widening';

  @override
  String get stereoWideningHint =>
      'Adjust mid/side width on desktop output. 100% leaves the file unchanged.';

  @override
  String get width => 'Width';

  @override
  String get crossfade => 'Crossfade';

  @override
  String get crossfadeHint =>
      'Overlap the end of one track with the start of the next (desktop). 0 disables it.';

  @override
  String get duration => 'Duration';

  @override
  String get outputDevice => 'Output device';

  @override
  String get outputDeviceHint =>
      'Choose the desktop audio output. Android routing follows the system output.';

  @override
  String couldNotListDevices(Object error) {
    return 'Could not list devices: $error';
  }

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get audioOutput => 'Audio output';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Even out perceived loudness between tracks using gain tags.';

  @override
  String get equalizerHint =>
      'Desktop playback applies EQ live. Android EQ uses the same saved settings and will be active with the Android audio-effects pass.';

  @override
  String get replayGainOff => 'Off';

  @override
  String get replayGainTrack => 'Track';

  @override
  String get replayGainAlbum => 'Album';

  @override
  String get preamp => 'Pre-amp';

  @override
  String get equalizer10Band => '10-band equalizer';

  @override
  String get saveCustom => 'Save custom';

  @override
  String get eqPre => 'Pre';

  @override
  String get saveEqPreset => 'Save EQ preset';

  @override
  String get presetName => 'Preset name';

  @override
  String couldNotSavePreset(Object error) {
    return 'Could not save preset: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'Could not delete preset: $error';
  }

  @override
  String get version => 'Version';

  @override
  String get updates => 'Updates';

  @override
  String get updatesManaged =>
      'Managed by your package manager (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'Check for updates automatically';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get onLatestVersion => 'You\'re on the latest version';

  @override
  String updateCheckFailed(Object error) {
    return 'Update check failed: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version is available';
  }

  @override
  String get updateSkip => 'Skip';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update';

  @override
  String updateToVersion(String version) {
    return 'Update to $version';
  }

  @override
  String downloadingPercent(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get startingInstaller => 'Starting installer…';

  @override
  String get downloadAndInstall => 'Download & install';

  @override
  String invalidRules(Object error) {
    return 'Invalid rules: $error';
  }

  @override
  String get enterAName => 'Enter a name';

  @override
  String couldNotSave(Object error) {
    return 'Could not save: $error';
  }

  @override
  String get name => 'Name';

  @override
  String get rfTitle => 'Title';

  @override
  String get rfArtist => 'Artist';

  @override
  String get rfAlbum => 'Album';

  @override
  String get rfGenre => 'Genre';

  @override
  String get rfYear => 'Year';

  @override
  String get rfRating => 'Rating';

  @override
  String get rfPlayCount => 'Play count';

  @override
  String get rfDuration => 'Duration (ms)';

  @override
  String get rfDateAdded => 'Date added';

  @override
  String get opContains => 'contains';

  @override
  String get opIs => 'is';

  @override
  String get opIsNot => 'is not';

  @override
  String get opStartsWith => 'starts with';

  @override
  String get opEndsWith => 'ends with';

  @override
  String get opNotContains => 'doesn\'t contain';

  @override
  String get opInLastDays => 'in last N days';

  @override
  String get ruleMatch => 'Match';

  @override
  String get ruleMatchAll => 'All';

  @override
  String get ruleMatchAny => 'Any';

  @override
  String get ofTheseRules => 'of these rules';

  @override
  String get addRule => 'Add rule';

  @override
  String get newSmartPlaylist => 'New smart playlist';

  @override
  String get editSmartPlaylist => 'Edit smart playlist';

  @override
  String get preview => 'Preview';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '$count match',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Limit (optional)';

  @override
  String get ruleValueHint => 'value';

  @override
  String get removeRule => 'Remove rule';

  @override
  String get noTracksMatchRules => 'No tracks match these rules';

  @override
  String get playAll => 'Play all';

  @override
  String get sharingTitle => 'Sharing';

  @override
  String get sharingHint =>
      'Pick what peers on your network can stream or download. Changes apply immediately while you are sharing.';

  @override
  String get wholeLibrary => 'Whole library';

  @override
  String get noPlaylistsYet => 'No playlists yet';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'Could not update sharing: $error';
  }

  @override
  String get accessLabel => 'Access: ';

  @override
  String get accessOpen => 'Open';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'Approved';

  @override
  String get peersCanLabel => 'Peers can: ';

  @override
  String get streamOnly => 'Stream only';

  @override
  String get streamAndDownload => 'Stream + download';

  @override
  String get notShared => 'Not shared';

  @override
  String get changePin => 'Change PIN (leave blank to keep)';

  @override
  String get setPin => 'Set a 4–6 digit PIN';

  @override
  String get approvedModeHint =>
      'Each new device asks to connect; you allow or deny it on the Network screen (tick \"Always\" to remember a device).';

  @override
  String downloadedToLibrary(String title) {
    return 'Downloaded \"$title\" to your library';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return 'Downloaded $done of $total tracks$failed to your library';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count failed)';
  }

  @override
  String downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get joinedParty => 'Joined party — following the host';

  @override
  String couldNotJoinParty(Object error) {
    return 'Could not join party: $error';
  }

  @override
  String get downloadAllToLibrary => 'Download all to my library';

  @override
  String get downloadToLibrary => 'Download to my library';

  @override
  String get reconnectingToParty => 'Reconnecting to party… (tap to leave)';

  @override
  String get leaveParty => 'Leave party';

  @override
  String get joinPartySync => 'Join party (sync to host)';

  @override
  String get nothingSharedHere => 'Nothing shared here';

  @override
  String requestedTrack(String title) {
    return 'Requested \"$title\"';
  }

  @override
  String get joinToRequest => 'Join the party to request tracks';

  @override
  String get networkTitle => 'Network';

  @override
  String get lanOnlyBanner =>
      'Local network only — nothing leaves your Wi-Fi. No cloud, no accounts.';

  @override
  String sharingOnPort(String port, String name) {
    return 'Sharing on port $port as \"$name\"';
  }

  @override
  String get off => 'Off';

  @override
  String get manageWhatIShareSubtitle =>
      'Playlists or the whole library, with access mode & PIN';

  @override
  String get revokeAllSubtitle =>
      'Disconnect everyone; they must re-authenticate';

  @override
  String get partyModeOnSubtitle =>
      'Connected peers follow your playback in sync';

  @override
  String get partyModeOffSubtitle => 'Start a synchronized session for peers';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get approvalRequests => 'Approval requests';

  @override
  String get partyRequestsTitle => 'Party requests';

  @override
  String peerAllowed(String peer) {
    return 'Allowed $peer';
  }

  @override
  String peerDenied(String peer) {
    return 'Denied $peer';
  }

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get tooManyAttempts => 'Too many attempts — wait a moment and retry';

  @override
  String accessDenied(String detail) {
    return 'Access denied: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 digits';

  @override
  String get connect => 'Connect';

  @override
  String get ipExampleHint => 'e.g. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name isn\'t sharing anything right now';
  }

  @override
  String sharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return 'Could not reach $name: $error';
  }

  @override
  String get waitingForHost => 'Waiting for the host to allow you…';

  @override
  String get hostDenied => 'The host denied your request';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get connectByIp => 'Connect by IP';

  @override
  String get enterAddressHint =>
      'Enter address and port, e.g. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Share my library';

  @override
  String get manageWhatIShare => 'Manage what I share';

  @override
  String get revokeAllPeerAccess => 'Revoke all peer access';

  @override
  String get allSessionsRevoked => 'All peer sessions revoked';

  @override
  String get partyMode => 'Party mode';

  @override
  String get discoveredHosts => 'Discovered hosts';

  @override
  String get connectByIpAddress => 'Connect by IP address';

  @override
  String get reachHostManually =>
      'Reach a host manually if it isn\'t discovered';

  @override
  String get noHostsFound => 'No hosts found on the network';

  @override
  String get connectionsAndActivity => 'Connections & activity';

  @override
  String get noPeersConnected => 'No peers connected';

  @override
  String get activeSession => 'Active session';

  @override
  String get revoke => 'Revoke';

  @override
  String get clearActivity => 'Clear activity';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer wants to connect to \"$label\"';
  }

  @override
  String get allowOnce => 'Allow once';

  @override
  String get alwaysAllow => 'Always allow';

  @override
  String get deny => 'Deny';

  @override
  String requestedByPeer(String peer) {
    return 'Requested by $peer';
  }

  @override
  String get dismiss => 'Dismiss';

  @override
  String scanFailed(Object error) {
    return 'Scan failed: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Scanned: $added added, $updated updated, $skipped unchanged, $errors errors';
  }

  @override
  String get dropFolderHint => 'Drop a folder to add it to your library';

  @override
  String get scanMusicFolder => 'Scan a music folder';

  @override
  String get folderPath => 'Folder path';

  @override
  String get libraryFolders => 'Library folders';

  @override
  String get scanFolder => 'Scan folder';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Rescan: $added added, $updated updated, $removed removed';
  }

  @override
  String removeFolderBody(String path) {
    return 'Forget \"$path\" and remove its tracks from the library? Files on disk are not deleted.';
  }

  @override
  String get watchingForChanges => 'Watching for changes';

  @override
  String get notWatchingManual => 'Not watching (scan manually)';

  @override
  String get watchingTapToStop => 'Watching — tap to stop';

  @override
  String get notWatchingTapToWatch => 'Not watching — tap to watch';

  @override
  String rescanFailed(Object error) {
    return 'Rescan failed: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'Could not change watching: $error';
  }

  @override
  String get removeFolderQuestion => 'Remove folder?';

  @override
  String get rescanAll => 'Rescan all';

  @override
  String get noFoldersYet => 'No folders yet — use \"Scan folder\".';

  @override
  String get findDuplicates => 'Find duplicates';

  @override
  String couldNotRemove(Object error) {
    return 'Could not remove: $error';
  }

  @override
  String get duplicateTracks => 'Duplicate tracks';

  @override
  String copiesCount(int count, String title) {
    return '$count copies · $title';
  }

  @override
  String get noDuplicatesFound => 'No duplicates found.';

  @override
  String get removeExtras => 'Remove extras';

  @override
  String get kept => 'Kept';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get searchHint => 'Search songs, artists, albums…';

  @override
  String get nowPlayingSemantic => 'Now playing';

  @override
  String addedToQueue(int count) {
    return 'Added $count to queue';
  }

  @override
  String get clearSelection => 'Clear selection';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get editTags => 'Edit tags';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get trackActions => 'Track actions';

  @override
  String get playNext => 'Play next';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get select => 'Select';

  @override
  String queuedTrack(String title) {
    return 'Queued \"$title\"';
  }

  @override
  String failedToLoad(Object error) {
    return 'Failed to load: $error';
  }

  @override
  String get libraryEmpty => 'Your library is empty';

  @override
  String get libraryEmptyHintDrop =>
      'Drag a music folder here, or use the scan button in the top bar to add one.';

  @override
  String get libraryEmptyHintTap =>
      'Tap the scan button in the top bar to add a music folder.';

  @override
  String get importPlaylistTitle => 'Import playlist (M3U / PLS)';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String importedTracks(int matched, int total) {
    return 'Imported $matched/$total tracks';
  }

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'Delete smart playlist?';

  @override
  String deleteNamedPermanently(String name) {
    return 'Delete \"$name\" permanently?';
  }

  @override
  String get smart => 'Smart';

  @override
  String get import => 'Import';

  @override
  String get autoPlaylists => 'Auto playlists';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String get mostPlayed => 'Most Played';

  @override
  String get neverPlayed => 'Never Played';

  @override
  String get favorites => 'Favorites';

  @override
  String get songs => 'Songs';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artists';

  @override
  String get genres => 'Genres';

  @override
  String get recent => 'Recent';

  @override
  String get settings => 'Settings';

  @override
  String get playlists => 'Playlists';

  @override
  String get smartPlaylists => 'Smart playlists';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '$count track',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Export…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'Could not remove track: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'Could not reorder playlist: $error';
  }

  @override
  String get playPlaylist => 'Play playlist';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get exportPlaylistTitle => 'Export playlist';

  @override
  String get noTracksInPlaylist => 'No tracks in this playlist';

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get duplicatePlaylist => 'Duplicate playlist';

  @override
  String duplicateCopyName(String name) {
    return '$name copy';
  }

  @override
  String exportedPlaylist(String name) {
    return 'Exported \"$name\"';
  }

  @override
  String get deletePlaylistQuestion => 'Delete playlist?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return 'Added \"$title\" to $playlist';
  }

  @override
  String get noAlbums => 'No albums';

  @override
  String get noArtists => 'No artists';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums albums • $tracks tracks';
  }

  @override
  String get noGenres => 'No genres';
}

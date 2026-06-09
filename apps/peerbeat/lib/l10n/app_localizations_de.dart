// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTagline => 'Lokaler + LAN-Musikplayer';

  @override
  String get trayShow => 'PeerBeat anzeigen';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonApply => 'Übernehmen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonPlay => 'Wiedergeben';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonDuplicate => 'Duplizieren';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonRefresh => 'Aktualisieren';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonPrevious => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get nowPlayingTitle => 'Aktuelle Wiedergabe';

  @override
  String get pause => 'Pause';

  @override
  String get repeatOff => 'Wiederholung aus';

  @override
  String get repeatAll => 'Alle wiederholen';

  @override
  String get repeatOne => 'Eine wiederholen';

  @override
  String get mute => 'Stummschalten';

  @override
  String get unmute => 'Ton ein';

  @override
  String volumePercent(int percent) {
    return '$percent % Lautstärke';
  }

  @override
  String get shuffle => 'Zufall';

  @override
  String get queue => 'Warteschlange';

  @override
  String get lyrics => 'Songtext';

  @override
  String get playbackSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get upNext => 'Als Nächstes';

  @override
  String get queueIsEmpty => 'Warteschlange ist leer';

  @override
  String get noLyricsFound => 'Kein Songtext gefunden';

  @override
  String get sleepTimer => 'Sleep-Timer';

  @override
  String sleepTimerActive(String remaining) {
    return 'Sleep-Timer: $remaining';
  }

  @override
  String get sleepTurnOff => 'Ausschalten';

  @override
  String sleepMinutes(int count) {
    return '$count Minuten';
  }

  @override
  String seekFailed(Object error) {
    return 'Suchen fehlgeschlagen: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Wiedergabe fehlgeschlagen: $error';
  }

  @override
  String get editMetadata => 'Metadaten bearbeiten';

  @override
  String get batchEditHint =>
      'Hake ein Feld an, um es auf alle ausgewählten Titel anzuwenden; der Rest bleibt unverändert.';

  @override
  String get addToFavorites => 'Zu Favoriten hinzufügen';

  @override
  String get removeFromFavorites => 'Aus Favoriten entfernen';

  @override
  String get accentDefault => 'Standard-Akzent';

  @override
  String positionLabel(String time) {
    return 'Position $time';
  }

  @override
  String get setPinFirst => 'Lege zuerst eine 4–6-stellige PIN fest';

  @override
  String get pinMustBeDigits => 'PIN muss 4–6 Ziffern haben';

  @override
  String sharingNamed(String name) {
    return '\"$name\" wird geteilt';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'Teilen von \"$name\" gestoppt';
  }

  @override
  String get fieldTitle => 'Titel';

  @override
  String get fieldArtist => 'Künstler (\";\"-getrennt)';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Album-Interpret';

  @override
  String get fieldGenre => 'Genre (\";\"-getrennt)';

  @override
  String get fieldYear => 'Jahr';

  @override
  String get fieldTrackNo => 'Titelnr.';

  @override
  String editNTracks(int count) {
    return '$count Titel bearbeiten';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'Tags konnten nicht gelesen werden: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel konnten nicht aktualisiert werden',
      one: '$count Titel konnte nicht aktualisiert werden',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsAbout => 'Über';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get language => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get dynamicTheme => 'Dynamisches Design vom Albumcover';

  @override
  String get dynamicThemeSubtitle =>
      'Färbt die App mit den Farben des aktuellen Titels';

  @override
  String get accentColor => 'Akzentfarbe';

  @override
  String get accentDynamicHint =>
      'Ersatz, wenn das Cover keine kräftige Farbe hat';

  @override
  String get accentPickHint => 'App-Akzent wählen';

  @override
  String get stereoWidening => 'Stereo-Verbreiterung';

  @override
  String get stereoWideningHint =>
      'Mitte/Seite-Breite an der Desktop-Ausgabe anpassen. 100 % lässt die Datei unverändert.';

  @override
  String get width => 'Breite';

  @override
  String get crossfade => 'Überblendung';

  @override
  String get crossfadeHint =>
      'Überlappt das Ende eines Titels mit dem Anfang des nächsten (Desktop). 0 deaktiviert es.';

  @override
  String get duration => 'Dauer';

  @override
  String get outputDevice => 'Ausgabegerät';

  @override
  String get outputDeviceHint =>
      'Wähle die Desktop-Audioausgabe. Auf Android folgt das Routing der Systemausgabe.';

  @override
  String couldNotListDevices(Object error) {
    return 'Geräte konnten nicht aufgelistet werden: $error';
  }

  @override
  String get refreshDevices => 'Geräte aktualisieren';

  @override
  String get audioOutput => 'Audioausgabe';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Gleicht die wahrgenommene Lautheit zwischen Titeln anhand der Gain-Tags an.';

  @override
  String get equalizerHint =>
      'Die Desktop-Wiedergabe wendet den EQ live an. Der Android-EQ nutzt dieselben gespeicherten Einstellungen und wird mit dem Android-Audioeffekte-Durchlauf aktiv.';

  @override
  String get replayGainOff => 'Aus';

  @override
  String get replayGainTrack => 'Titel';

  @override
  String get replayGainAlbum => 'Album';

  @override
  String get preamp => 'Vorverstärker';

  @override
  String get equalizer10Band => '10-Band-Equalizer';

  @override
  String get saveCustom => 'Eigenes speichern';

  @override
  String get eqPre => 'Vor';

  @override
  String get saveEqPreset => 'EQ-Voreinstellung speichern';

  @override
  String get presetName => 'Name der Voreinstellung';

  @override
  String couldNotSavePreset(Object error) {
    return 'Voreinstellung konnte nicht gespeichert werden: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'Voreinstellung konnte nicht gelöscht werden: $error';
  }

  @override
  String get version => 'Version';

  @override
  String get updates => 'Updates';

  @override
  String get updatesManaged =>
      'Verwaltet von deinem Paketmanager (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'Automatisch nach Updates suchen';

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get onLatestVersion => 'Du hast die neueste Version';

  @override
  String updateCheckFailed(Object error) {
    return 'Update-Suche fehlgeschlagen: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version ist verfügbar';
  }

  @override
  String get updateSkip => 'Überspringen';

  @override
  String get updateLater => 'Später';

  @override
  String get updateNow => 'Aktualisieren';

  @override
  String updateToVersion(String version) {
    return 'Auf $version aktualisieren';
  }

  @override
  String downloadingPercent(int percent) {
    return 'Wird heruntergeladen… $percent %';
  }

  @override
  String get startingInstaller => 'Installationsprogramm wird gestartet…';

  @override
  String get downloadAndInstall => 'Herunterladen und installieren';

  @override
  String invalidRules(Object error) {
    return 'Ungültige Regeln: $error';
  }

  @override
  String get enterAName => 'Namen eingeben';

  @override
  String couldNotSave(Object error) {
    return 'Konnte nicht gespeichert werden: $error';
  }

  @override
  String get name => 'Name';

  @override
  String get ruleMatch => 'Übereinstimmung';

  @override
  String get ruleMatchAll => 'Alle';

  @override
  String get ruleMatchAny => 'Beliebige';

  @override
  String get ofTheseRules => 'dieser Regeln';

  @override
  String get addRule => 'Regel hinzufügen';

  @override
  String get newSmartPlaylist => 'Neue intelligente Playlist';

  @override
  String get editSmartPlaylist => 'Intelligente Playlist bearbeiten';

  @override
  String get preview => 'Vorschau';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Treffer',
      one: '$count Treffer',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Limit (optional)';

  @override
  String get ruleValueHint => 'Wert';

  @override
  String get removeRule => 'Regel entfernen';

  @override
  String get noTracksMatchRules => 'Keine Titel entsprechen diesen Regeln';

  @override
  String get playAll => 'Alle wiedergeben';

  @override
  String get sharingTitle => 'Freigabe';

  @override
  String get sharingHint =>
      'Wähle, was Peers in deinem Netzwerk streamen oder herunterladen dürfen. Änderungen gelten sofort, während du teilst.';

  @override
  String get wholeLibrary => 'Ganze Bibliothek';

  @override
  String get noPlaylistsYet => 'Noch keine Playlists';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'Freigabe konnte nicht aktualisiert werden: $error';
  }

  @override
  String get accessLabel => 'Zugriff: ';

  @override
  String get accessOpen => 'Offen';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'Genehmigt';

  @override
  String get peersCanLabel => 'Peers können: ';

  @override
  String get streamOnly => 'Nur streamen';

  @override
  String get streamAndDownload => 'Streamen + herunterladen';

  @override
  String get notShared => 'Nicht geteilt';

  @override
  String get changePin => 'PIN ändern (leer lassen, um zu behalten)';

  @override
  String get setPin => 'Lege eine 4–6-stellige PIN fest';

  @override
  String get approvedModeHint =>
      'Jedes neue Gerät fragt nach einer Verbindung; du erlaubst oder verweigerst sie im Netzwerk-Bildschirm (hake \"Immer\" an, um ein Gerät zu merken).';

  @override
  String downloadedToLibrary(String title) {
    return '\"$title\" in deine Bibliothek heruntergeladen';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '$done von $total Titeln$failed in deine Bibliothek heruntergeladen';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count fehlgeschlagen)';
  }

  @override
  String downloadFailed(Object error) {
    return 'Download fehlgeschlagen: $error';
  }

  @override
  String get joinedParty => 'Der Party beigetreten — folge dem Host';

  @override
  String couldNotJoinParty(Object error) {
    return 'Beitritt zur Party fehlgeschlagen: $error';
  }

  @override
  String get downloadAllToLibrary => 'Alle in meine Bibliothek herunterladen';

  @override
  String get downloadToLibrary => 'In meine Bibliothek herunterladen';

  @override
  String get reconnectingToParty =>
      'Wiederverbindung zur Party… (zum Verlassen tippen)';

  @override
  String get leaveParty => 'Party verlassen';

  @override
  String get joinPartySync => 'Party beitreten (mit Host synchronisieren)';

  @override
  String get nothingSharedHere => 'Hier wird nichts geteilt';

  @override
  String requestedTrack(String title) {
    return '\"$title\" angefragt';
  }

  @override
  String get joinToRequest => 'Tritt der Party bei, um Titel anzufragen';

  @override
  String get networkTitle => 'Netzwerk';

  @override
  String get lanOnlyBanner =>
      'Nur lokales Netzwerk — nichts verlässt dein WLAN. Keine Cloud, keine Konten.';

  @override
  String sharingOnPort(String port, String name) {
    return 'Freigabe auf Port $port als \"$name\"';
  }

  @override
  String get off => 'Aus';

  @override
  String get manageWhatIShareSubtitle =>
      'Playlists oder die ganze Bibliothek, mit Zugriffsmodus & PIN';

  @override
  String get revokeAllSubtitle =>
      'Trennt alle; sie müssen sich erneut authentifizieren';

  @override
  String get partyModeOnSubtitle =>
      'Verbundene Peers folgen deiner Wiedergabe synchron';

  @override
  String get partyModeOffSubtitle =>
      'Starte eine synchronisierte Sitzung für Peers';

  @override
  String get recentActivity => 'Letzte Aktivität';

  @override
  String get approvalRequests => 'Genehmigungsanfragen';

  @override
  String get partyRequestsTitle => 'Party-Anfragen';

  @override
  String peerAllowed(String peer) {
    return '$peer erlaubt';
  }

  @override
  String peerDenied(String peer) {
    return '$peer abgelehnt';
  }

  @override
  String get incorrectPin => 'Falsche PIN';

  @override
  String get tooManyAttempts =>
      'Zu viele Versuche — warte einen Moment und versuche es erneut';

  @override
  String accessDenied(String detail) {
    return 'Zugriff verweigert: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 Ziffern';

  @override
  String get connect => 'Verbinden';

  @override
  String get ipExampleHint => 'z. B. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name teilt gerade nichts';
  }

  @override
  String sharedBy(String name) {
    return 'Geteilt von $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return '$name konnte nicht erreicht werden: $error';
  }

  @override
  String get waitingForHost => 'Warten auf Freigabe durch den Host…';

  @override
  String get hostDenied => 'Der Host hat deine Anfrage abgelehnt';

  @override
  String get enterPin => 'PIN eingeben';

  @override
  String get connectByIp => 'Per IP verbinden';

  @override
  String get enterAddressHint =>
      'Adresse und Port eingeben, z. B. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Meine Bibliothek teilen';

  @override
  String get manageWhatIShare => 'Verwalten, was ich teile';

  @override
  String get revokeAllPeerAccess => 'Allen Peer-Zugriff widerrufen';

  @override
  String get allSessionsRevoked => 'Alle Peer-Sitzungen widerrufen';

  @override
  String get partyMode => 'Party-Modus';

  @override
  String get discoveredHosts => 'Gefundene Hosts';

  @override
  String get connectByIpAddress => 'Per IP-Adresse verbinden';

  @override
  String get reachHostManually =>
      'Host manuell erreichen, wenn er nicht gefunden wird';

  @override
  String get noHostsFound => 'Keine Hosts im Netzwerk gefunden';

  @override
  String get connectionsAndActivity => 'Verbindungen & Aktivität';

  @override
  String get noPeersConnected => 'Keine Peers verbunden';

  @override
  String get activeSession => 'Aktive Sitzung';

  @override
  String get revoke => 'Widerrufen';

  @override
  String get clearActivity => 'Aktivität löschen';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer möchte sich mit \"$label\" verbinden';
  }

  @override
  String get allowOnce => 'Einmal erlauben';

  @override
  String get alwaysAllow => 'Immer erlauben';

  @override
  String get deny => 'Ablehnen';

  @override
  String requestedByPeer(String peer) {
    return 'Angefragt von $peer';
  }

  @override
  String get dismiss => 'Verwerfen';

  @override
  String scanFailed(Object error) {
    return 'Scan fehlgeschlagen: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Gescannt: $added hinzugefügt, $updated aktualisiert, $skipped unverändert, $errors Fehler';
  }

  @override
  String get dropFolderHint =>
      'Ordner ablegen, um ihn zur Bibliothek hinzuzufügen';

  @override
  String get scanMusicFolder => 'Musikordner scannen';

  @override
  String get folderPath => 'Ordnerpfad';

  @override
  String get libraryFolders => 'Bibliotheksordner';

  @override
  String get scanFolder => 'Ordner scannen';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Neuer Scan: $added hinzugefügt, $updated aktualisiert, $removed entfernt';
  }

  @override
  String removeFolderBody(String path) {
    return '\"$path\" vergessen und seine Titel aus der Bibliothek entfernen? Dateien auf der Festplatte werden nicht gelöscht.';
  }

  @override
  String get watchingForChanges => 'Überwacht Änderungen';

  @override
  String get notWatchingManual => 'Nicht überwacht (manuell scannen)';

  @override
  String get watchingTapToStop => 'Überwacht — zum Stoppen tippen';

  @override
  String get notWatchingTapToWatch => 'Nicht überwacht — zum Überwachen tippen';

  @override
  String rescanFailed(Object error) {
    return 'Erneuter Scan fehlgeschlagen: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'Überwachung konnte nicht geändert werden: $error';
  }

  @override
  String get removeFolderQuestion => 'Ordner entfernen?';

  @override
  String get rescanAll => 'Alle neu scannen';

  @override
  String get noFoldersYet => 'Noch keine Ordner — nutze „Ordner scannen“.';

  @override
  String get findDuplicates => 'Duplikate finden';

  @override
  String couldNotRemove(Object error) {
    return 'Konnte nicht entfernt werden: $error';
  }

  @override
  String get duplicateTracks => 'Doppelte Titel';

  @override
  String copiesCount(int count, String title) {
    return '$count Kopien · $title';
  }

  @override
  String get noDuplicatesFound => 'Keine Duplikate gefunden.';

  @override
  String get removeExtras => 'Überzählige entfernen';

  @override
  String get kept => 'Behalten';

  @override
  String get removeFromLibrary => 'Aus der Bibliothek entfernen';

  @override
  String get searchHint => 'Songs, Künstler, Alben suchen…';

  @override
  String get nowPlayingSemantic => 'Aktuelle Wiedergabe';

  @override
  String addedToQueue(int count) {
    return '$count zur Warteschlange hinzugefügt';
  }

  @override
  String get clearSelection => 'Auswahl aufheben';

  @override
  String selectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get addToQueue => 'Zur Warteschlange';

  @override
  String get editTags => 'Tags bearbeiten';

  @override
  String get nothingHereYet => 'Hier ist noch nichts';

  @override
  String get trackActions => 'Titelaktionen';

  @override
  String get playNext => 'Als Nächstes wiedergeben';

  @override
  String get addToPlaylist => 'Zur Playlist hinzufügen';

  @override
  String get select => 'Auswählen';

  @override
  String queuedTrack(String title) {
    return '\"$title\" eingereiht';
  }

  @override
  String failedToLoad(Object error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String get libraryEmpty => 'Deine Bibliothek ist leer';

  @override
  String get libraryEmptyHintDrop =>
      'Ziehe einen Musikordner hierher oder nutze die Scan-Schaltfläche oben, um einen hinzuzufügen.';

  @override
  String get libraryEmptyHintTap =>
      'Tippe oben auf die Scan-Schaltfläche, um einen Musikordner hinzuzufügen.';

  @override
  String get importPlaylistTitle => 'Playlist importieren (M3U / PLS)';

  @override
  String get newPlaylist => 'Neue Playlist';

  @override
  String importedTracks(int matched, int total) {
    return '$matched/$total Titel importiert';
  }

  @override
  String importFailed(Object error) {
    return 'Import fehlgeschlagen: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'Intelligente Playlist löschen?';

  @override
  String deleteNamedPermanently(String name) {
    return '„$name“ endgültig löschen?';
  }

  @override
  String get smart => 'Intelligent';

  @override
  String get import => 'Importieren';

  @override
  String get autoPlaylists => 'Automatische Playlists';

  @override
  String get recentlyPlayed => 'Zuletzt gespielt';

  @override
  String get mostPlayed => 'Meistgespielt';

  @override
  String get neverPlayed => 'Nie gespielt';

  @override
  String get favorites => 'Favoriten';

  @override
  String get songs => 'Titel';

  @override
  String get albums => 'Alben';

  @override
  String get artists => 'Künstler';

  @override
  String get genres => 'Genres';

  @override
  String get recent => 'Zuletzt';

  @override
  String get settings => 'Einstellungen';

  @override
  String get playlists => 'Playlists';

  @override
  String get smartPlaylists => 'Intelligente Playlists';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '$count Titel',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Exportieren…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'Titel konnte nicht entfernt werden: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'Playlist konnte nicht neu sortiert werden: $error';
  }

  @override
  String get playPlaylist => 'Playlist wiedergeben';

  @override
  String get unknownArtist => 'Unbekannter Künstler';

  @override
  String get exportPlaylistTitle => 'Playlist exportieren';

  @override
  String get noTracksInPlaylist => 'Keine Titel in dieser Playlist';

  @override
  String get renamePlaylist => 'Playlist umbenennen';

  @override
  String get duplicatePlaylist => 'Playlist duplizieren';

  @override
  String duplicateCopyName(String name) {
    return '$name Kopie';
  }

  @override
  String exportedPlaylist(String name) {
    return '„$name“ exportiert';
  }

  @override
  String get deletePlaylistQuestion => 'Playlist löschen?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '\"$title\" zu $playlist hinzugefügt';
  }

  @override
  String get noAlbums => 'Keine Alben';

  @override
  String get noArtists => 'Keine Künstler';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums Alben • $tracks Titel';
  }

  @override
  String get noGenres => 'Keine Genres';
}

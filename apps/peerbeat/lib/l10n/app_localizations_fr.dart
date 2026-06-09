// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTagline => 'Lecteur de musique local + LAN';

  @override
  String get trayShow => 'Afficher PeerBeat';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonPlay => 'Lire';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonDuplicate => 'Dupliquer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonRefresh => 'Actualiser';

  @override
  String get commonReset => 'Réinitialiser';

  @override
  String get commonPrevious => 'Précédent';

  @override
  String get commonNext => 'Suivant';

  @override
  String get nowPlayingTitle => 'Lecture en cours';

  @override
  String get pause => 'Pause';

  @override
  String get repeatOff => 'Répétition désactivée';

  @override
  String get repeatAll => 'Répéter tout';

  @override
  String get repeatOne => 'Répéter une';

  @override
  String get mute => 'Couper le son';

  @override
  String get unmute => 'Réactiver le son';

  @override
  String volumePercent(int percent) {
    return '$percent % de volume';
  }

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get queue => 'File d\'attente';

  @override
  String get lyrics => 'Paroles';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get upNext => 'À suivre';

  @override
  String get queueIsEmpty => 'La file d\'attente est vide';

  @override
  String get noLyricsFound => 'Aucune parole trouvée';

  @override
  String get sleepTimer => 'Minuteur de veille';

  @override
  String sleepTimerActive(String remaining) {
    return 'Minuteur de veille : $remaining';
  }

  @override
  String get sleepTurnOff => 'Désactiver';

  @override
  String sleepMinutes(int count) {
    return '$count minutes';
  }

  @override
  String seekFailed(Object error) {
    return 'Échec du déplacement : $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Échec de la lecture : $error';
  }

  @override
  String get editMetadata => 'Modifier les métadonnées';

  @override
  String get batchEditHint =>
      'Cochez un champ pour l\'appliquer à tous les titres sélectionnés ; le reste ne change pas.';

  @override
  String get addToFavorites => 'Ajouter aux favoris';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get accentDefault => 'Accent par défaut';

  @override
  String positionLabel(String time) {
    return 'Position $time';
  }

  @override
  String get setPinFirst => 'Définissez d\'abord un PIN de 4 à 6 chiffres';

  @override
  String get pinMustBeDigits => 'Le PIN doit comporter 4 à 6 chiffres';

  @override
  String sharingNamed(String name) {
    return 'Partage de « $name »';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'Partage de « $name » arrêté';
  }

  @override
  String get fieldTitle => 'Titre';

  @override
  String get fieldArtist => 'Artiste (séparé par « ; »)';

  @override
  String get fieldAlbum => 'Album';

  @override
  String get fieldAlbumArtist => 'Artiste de l\'album';

  @override
  String get fieldGenre => 'Genre (séparé par « ; »)';

  @override
  String get fieldYear => 'Année';

  @override
  String get fieldTrackNo => 'N° de piste';

  @override
  String editNTracks(int count) {
    return 'Modifier $count titres';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'Impossible de lire les étiquettes : $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres n\'ont pas pu être mis à jour',
      one: '$count titre n\'a pas pu être mis à jour',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get supportDevelopment => 'Soutenir le développement';

  @override
  String get sponsorOnGithub => 'Sponsoriser sur GitHub';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get language => 'Langue';

  @override
  String get languageSystemDefault => 'Par défaut du système';

  @override
  String get dynamicTheme => 'Thème dynamique d\'après la pochette';

  @override
  String get dynamicThemeSubtitle =>
      'Teinte l\'application avec les couleurs du titre en cours';

  @override
  String get accentColor => 'Couleur d\'accent';

  @override
  String get accentDynamicHint =>
      'Solution de repli quand la pochette n\'a pas de couleur marquée';

  @override
  String get accentPickHint => 'Choisir l\'accent de l\'application';

  @override
  String get stereoWidening => 'Élargissement stéréo';

  @override
  String get stereoWideningHint =>
      'Ajuste la largeur milieu/côté en sortie bureau. 100 % laisse le fichier inchangé.';

  @override
  String get width => 'Largeur';

  @override
  String get crossfade => 'Fondu enchaîné';

  @override
  String get crossfadeHint =>
      'Superpose la fin d\'un titre avec le début du suivant (bureau). 0 le désactive.';

  @override
  String get duration => 'Durée';

  @override
  String get outputDevice => 'Périphérique de sortie';

  @override
  String get outputDeviceHint =>
      'Choisissez la sortie audio du bureau. Sur Android, le routage suit la sortie système.';

  @override
  String couldNotListDevices(Object error) {
    return 'Impossible de lister les périphériques : $error';
  }

  @override
  String get refreshDevices => 'Actualiser les périphériques';

  @override
  String get audioOutput => 'Sortie audio';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Égalise le volume perçu entre les titres à l\'aide des étiquettes de gain.';

  @override
  String get equalizerHint =>
      'La lecture sur bureau applique l\'égaliseur en direct. L\'égaliseur Android utilise les mêmes réglages enregistrés et sera actif avec la passe d\'effets audio Android.';

  @override
  String get replayGainOff => 'Désactivé';

  @override
  String get replayGainTrack => 'Titre';

  @override
  String get replayGainAlbum => 'Album';

  @override
  String get preamp => 'Préampli';

  @override
  String get equalizer10Band => 'Égaliseur 10 bandes';

  @override
  String get saveCustom => 'Enregistrer personnalisé';

  @override
  String get eqPre => 'Préampli';

  @override
  String get saveEqPreset => 'Enregistrer le préréglage EQ';

  @override
  String get presetName => 'Nom du préréglage';

  @override
  String couldNotSavePreset(Object error) {
    return 'Impossible d\'enregistrer le préréglage : $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'Impossible de supprimer le préréglage : $error';
  }

  @override
  String get version => 'Version';

  @override
  String get updates => 'Mises à jour';

  @override
  String get updatesManaged =>
      'Gérées par votre gestionnaire de paquets (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically =>
      'Rechercher les mises à jour automatiquement';

  @override
  String get checkForUpdates => 'Rechercher les mises à jour';

  @override
  String get onLatestVersion => 'Vous avez la dernière version';

  @override
  String updateCheckFailed(Object error) {
    return 'Échec de la recherche de mise à jour : $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version est disponible';
  }

  @override
  String get updateSkip => 'Ignorer';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String updateToVersion(String version) {
    return 'Mettre à jour vers $version';
  }

  @override
  String downloadingPercent(int percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get startingInstaller => 'Démarrage de l\'installateur…';

  @override
  String get downloadAndInstall => 'Télécharger et installer';

  @override
  String invalidRules(Object error) {
    return 'Règles non valides : $error';
  }

  @override
  String get enterAName => 'Saisissez un nom';

  @override
  String couldNotSave(Object error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String get name => 'Nom';

  @override
  String get rfTitle => 'Titre';

  @override
  String get rfArtist => 'Artiste';

  @override
  String get rfAlbum => 'Album';

  @override
  String get rfGenre => 'Genre';

  @override
  String get rfYear => 'Année';

  @override
  String get rfRating => 'Note';

  @override
  String get rfPlayCount => 'Lectures';

  @override
  String get rfDuration => 'Durée (ms)';

  @override
  String get rfDateAdded => 'Date d\'ajout';

  @override
  String get opContains => 'contient';

  @override
  String get opIs => 'est';

  @override
  String get opIsNot => 'n\'est pas';

  @override
  String get opStartsWith => 'commence par';

  @override
  String get opEndsWith => 'se termine par';

  @override
  String get opNotContains => 'ne contient pas';

  @override
  String get opInLastDays => 'au cours des N derniers jours';

  @override
  String get ruleMatch => 'Correspondance';

  @override
  String get ruleMatchAll => 'Toutes';

  @override
  String get ruleMatchAny => 'N\'importe';

  @override
  String get ofTheseRules => 'de ces règles';

  @override
  String get addRule => 'Ajouter une règle';

  @override
  String get newSmartPlaylist => 'Nouvelle playlist intelligente';

  @override
  String get editSmartPlaylist => 'Modifier la playlist intelligente';

  @override
  String get preview => 'Aperçu';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count correspondances',
      one: '$count correspondance',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Limite (facultatif)';

  @override
  String get ruleValueHint => 'valeur';

  @override
  String get removeRule => 'Retirer la règle';

  @override
  String get noTracksMatchRules => 'Aucun titre ne correspond à ces règles';

  @override
  String get playAll => 'Tout lire';

  @override
  String get sharingTitle => 'Partage';

  @override
  String get sharingHint =>
      'Choisissez ce que les pairs de votre réseau peuvent diffuser ou télécharger. Les modifications s\'appliquent immédiatement pendant le partage.';

  @override
  String get wholeLibrary => 'Toute la bibliothèque';

  @override
  String get noPlaylistsYet => 'Aucune playlist pour l\'instant';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'Impossible de mettre à jour le partage : $error';
  }

  @override
  String get accessLabel => 'Accès : ';

  @override
  String get accessOpen => 'Ouvert';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'Approuvé';

  @override
  String get peersCanLabel => 'Les pairs peuvent : ';

  @override
  String get streamOnly => 'Diffusion seule';

  @override
  String get streamAndDownload => 'Diffusion + téléchargement';

  @override
  String get notShared => 'Non partagé';

  @override
  String get changePin => 'Changer le PIN (laisser vide pour conserver)';

  @override
  String get setPin => 'Définir un PIN de 4 à 6 chiffres';

  @override
  String get approvedModeHint =>
      'Chaque nouvel appareil demande à se connecter ; vous l\'autorisez ou le refusez sur l\'écran Réseau (cochez « Toujours » pour mémoriser un appareil).';

  @override
  String downloadedToLibrary(String title) {
    return '\"$title\" téléchargé dans votre bibliothèque';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '$done titres sur $total téléchargés$failed dans votre bibliothèque';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count échecs)';
  }

  @override
  String downloadFailed(Object error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get joinedParty => 'Vous avez rejoint la session — suivi de l\'hôte';

  @override
  String couldNotJoinParty(Object error) {
    return 'Impossible de rejoindre la session : $error';
  }

  @override
  String get downloadAllToLibrary => 'Tout télécharger dans ma bibliothèque';

  @override
  String get downloadToLibrary => 'Télécharger dans ma bibliothèque';

  @override
  String get reconnectingToParty =>
      'Reconnexion à la session… (touchez pour quitter)';

  @override
  String get leaveParty => 'Quitter la session';

  @override
  String get joinPartySync =>
      'Rejoindre la session (synchroniser avec l\'hôte)';

  @override
  String get nothingSharedHere => 'Rien de partagé ici';

  @override
  String requestedTrack(String title) {
    return '\"$title\" demandé';
  }

  @override
  String get joinToRequest => 'Rejoignez la session pour demander des titres';

  @override
  String get networkTitle => 'Réseau';

  @override
  String get lanOnlyBanner =>
      'Réseau local uniquement — rien ne quitte votre Wi-Fi. Pas de cloud, pas de comptes.';

  @override
  String sharingOnPort(String port, String name) {
    return 'Partage sur le port $port en tant que « $name »';
  }

  @override
  String get off => 'Désactivé';

  @override
  String get manageWhatIShareSubtitle =>
      'Playlists ou toute la bibliothèque, avec mode d\'accès et PIN';

  @override
  String get revokeAllSubtitle =>
      'Déconnecte tout le monde ; ils devront se réauthentifier';

  @override
  String get partyModeOnSubtitle =>
      'Les pairs connectés suivent votre lecture en synchronisation';

  @override
  String get partyModeOffSubtitle =>
      'Démarrer une session synchronisée pour les pairs';

  @override
  String get recentActivity => 'Activité récente';

  @override
  String get approvalRequests => 'Demandes d\'approbation';

  @override
  String get partyRequestsTitle => 'Demandes de la session';

  @override
  String peerAllowed(String peer) {
    return '$peer autorisé';
  }

  @override
  String peerDenied(String peer) {
    return '$peer refusé';
  }

  @override
  String get incorrectPin => 'PIN incorrect';

  @override
  String get tooManyAttempts =>
      'Trop de tentatives — patientez un instant et réessayez';

  @override
  String accessDenied(String detail) {
    return 'Accès refusé : $detail';
  }

  @override
  String get pinDigitsHint => '4 à 6 chiffres';

  @override
  String get connect => 'Connecter';

  @override
  String get ipExampleHint => 'p. ex. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name ne partage rien pour le moment';
  }

  @override
  String sharedBy(String name) {
    return 'Partagé par $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return 'Impossible de joindre $name : $error';
  }

  @override
  String get waitingForHost => 'En attente de l\'autorisation de l\'hôte…';

  @override
  String get hostDenied => 'L\'hôte a refusé votre demande';

  @override
  String get enterPin => 'Saisir le PIN';

  @override
  String get connectByIp => 'Connexion par IP';

  @override
  String get enterAddressHint =>
      'Saisissez l\'adresse et le port, p. ex. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Partager ma bibliothèque';

  @override
  String get manageWhatIShare => 'Gérer ce que je partage';

  @override
  String get revokeAllPeerAccess => 'Révoquer tous les accès des pairs';

  @override
  String get allSessionsRevoked => 'Toutes les sessions des pairs révoquées';

  @override
  String get partyMode => 'Mode session';

  @override
  String get discoveredHosts => 'Hôtes découverts';

  @override
  String get connectByIpAddress => 'Connexion par adresse IP';

  @override
  String get reachHostManually =>
      'Joindre un hôte manuellement s\'il n\'est pas découvert';

  @override
  String get noHostsFound => 'Aucun hôte trouvé sur le réseau';

  @override
  String get connectionsAndActivity => 'Connexions et activité';

  @override
  String get noPeersConnected => 'Aucun pair connecté';

  @override
  String get activeSession => 'Session active';

  @override
  String get revoke => 'Révoquer';

  @override
  String get clearActivity => 'Effacer l\'activité';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer veut se connecter à \"$label\"';
  }

  @override
  String get allowOnce => 'Autoriser une fois';

  @override
  String get alwaysAllow => 'Toujours autoriser';

  @override
  String get deny => 'Refuser';

  @override
  String requestedByPeer(String peer) {
    return 'Demandé par $peer';
  }

  @override
  String get dismiss => 'Ignorer';

  @override
  String scanFailed(Object error) {
    return 'Échec de l\'analyse : $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Analysé : $added ajoutés, $updated mis à jour, $skipped inchangés, $errors erreurs';
  }

  @override
  String get dropFolderHint =>
      'Déposez un dossier pour l\'ajouter à votre bibliothèque';

  @override
  String get scanMusicFolder => 'Analyser un dossier de musique';

  @override
  String get folderPath => 'Chemin du dossier';

  @override
  String get libraryFolders => 'Dossiers de la bibliothèque';

  @override
  String get scanFolder => 'Analyser un dossier';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Réanalyse : $added ajoutés, $updated mis à jour, $removed supprimés';
  }

  @override
  String removeFolderBody(String path) {
    return 'Oublier « $path » et retirer ses titres de la bibliothèque ? Les fichiers sur le disque ne sont pas supprimés.';
  }

  @override
  String get watchingForChanges => 'Surveillance des modifications';

  @override
  String get notWatchingManual => 'Non surveillé (analyse manuelle)';

  @override
  String get watchingTapToStop => 'Surveillé — touchez pour arrêter';

  @override
  String get notWatchingTapToWatch => 'Non surveillé — touchez pour surveiller';

  @override
  String rescanFailed(Object error) {
    return 'Échec de la nouvelle analyse : $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'Impossible de modifier la surveillance : $error';
  }

  @override
  String get removeFolderQuestion => 'Retirer le dossier ?';

  @override
  String get rescanAll => 'Tout réanalyser';

  @override
  String get noFoldersYet =>
      'Aucun dossier pour l\'instant — utilisez « Analyser un dossier ».';

  @override
  String get findDuplicates => 'Trouver les doublons';

  @override
  String couldNotRemove(Object error) {
    return 'Impossible de retirer : $error';
  }

  @override
  String get duplicateTracks => 'Titres en double';

  @override
  String copiesCount(int count, String title) {
    return '$count copies · $title';
  }

  @override
  String get noDuplicatesFound => 'Aucun doublon trouvé.';

  @override
  String get removeExtras => 'Retirer les surplus';

  @override
  String get kept => 'Conservé';

  @override
  String get removeFromLibrary => 'Retirer de la bibliothèque';

  @override
  String get searchHint => 'Rechercher titres, artistes, albums…';

  @override
  String get nowPlayingSemantic => 'Lecture en cours';

  @override
  String addedToQueue(int count) {
    return '$count ajoutés à la file';
  }

  @override
  String get clearSelection => 'Effacer la sélection';

  @override
  String selectedCount(int count) {
    return '$count sélectionnés';
  }

  @override
  String get addToQueue => 'Ajouter à la file';

  @override
  String get editTags => 'Modifier les étiquettes';

  @override
  String get nothingHereYet => 'Rien ici pour l\'instant';

  @override
  String get trackActions => 'Actions du titre';

  @override
  String get playNext => 'Lire ensuite';

  @override
  String get addToPlaylist => 'Ajouter à la playlist';

  @override
  String get select => 'Sélectionner';

  @override
  String queuedTrack(String title) {
    return '\"$title\" mis en file';
  }

  @override
  String failedToLoad(Object error) {
    return 'Échec du chargement : $error';
  }

  @override
  String get libraryEmpty => 'Votre bibliothèque est vide';

  @override
  String get libraryEmptyHintDrop =>
      'Glissez un dossier de musique ici, ou utilisez le bouton d\'analyse de la barre supérieure pour en ajouter un.';

  @override
  String get libraryEmptyHintTap =>
      'Touchez le bouton d\'analyse de la barre supérieure pour ajouter un dossier de musique.';

  @override
  String get importPlaylistTitle => 'Importer une playlist (M3U / PLS)';

  @override
  String get newPlaylist => 'Nouvelle playlist';

  @override
  String importedTracks(int matched, int total) {
    return '$matched/$total titres importés';
  }

  @override
  String importFailed(Object error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String get deleteSmartPlaylistQuestion =>
      'Supprimer la playlist intelligente ?';

  @override
  String deleteNamedPermanently(String name) {
    return 'Supprimer définitivement « $name » ?';
  }

  @override
  String get smart => 'Intelligente';

  @override
  String get import => 'Importer';

  @override
  String get autoPlaylists => 'Playlists automatiques';

  @override
  String get recentlyPlayed => 'Lus récemment';

  @override
  String get mostPlayed => 'Les plus lus';

  @override
  String get neverPlayed => 'Jamais lus';

  @override
  String get favorites => 'Favoris';

  @override
  String get songs => 'Titres';

  @override
  String get albums => 'Albums';

  @override
  String get artists => 'Artistes';

  @override
  String get genres => 'Genres';

  @override
  String get recent => 'Récents';

  @override
  String get settings => 'Réglages';

  @override
  String get playlists => 'Playlists';

  @override
  String get smartPlaylists => 'Playlists intelligentes';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titres',
      one: '$count titre',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Exporter…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'Impossible de retirer le titre : $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'Impossible de réorganiser la playlist : $error';
  }

  @override
  String get playPlaylist => 'Lire la playlist';

  @override
  String get unknownArtist => 'Artiste inconnu';

  @override
  String get exportPlaylistTitle => 'Exporter la playlist';

  @override
  String get noTracksInPlaylist => 'Aucun titre dans cette playlist';

  @override
  String get renamePlaylist => 'Renommer la playlist';

  @override
  String get duplicatePlaylist => 'Dupliquer la playlist';

  @override
  String duplicateCopyName(String name) {
    return '$name copie';
  }

  @override
  String exportedPlaylist(String name) {
    return '« $name » exportée';
  }

  @override
  String get deletePlaylistQuestion => 'Supprimer la playlist ?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '\"$title\" ajouté à $playlist';
  }

  @override
  String get noAlbums => 'Aucun album';

  @override
  String get noArtists => 'Aucun artiste';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums albums • $tracks titres';
  }

  @override
  String get noGenres => 'Aucun genre';
}

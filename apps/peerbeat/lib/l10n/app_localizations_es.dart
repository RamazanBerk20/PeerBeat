// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTagline => 'Reproductor de música local + LAN';

  @override
  String get trayShow => 'Mostrar PeerBeat';

  @override
  String get trayQuit => 'Salir';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRemove => 'Quitar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonPlay => 'Reproducir';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonRename => 'Cambiar nombre';

  @override
  String get commonDuplicate => 'Duplicar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonRefresh => 'Actualizar';

  @override
  String get commonReset => 'Restablecer';

  @override
  String get commonPrevious => 'Anterior';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get nowPlayingTitle => 'Reproduciendo ahora';

  @override
  String get pause => 'Pausar';

  @override
  String get repeatOff => 'Repetir desactivado';

  @override
  String get repeatAll => 'Repetir todo';

  @override
  String get repeatOne => 'Repetir una';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Activar sonido';

  @override
  String volumePercent(int percent) {
    return '$percent% de volumen';
  }

  @override
  String get shuffle => 'Aleatorio';

  @override
  String get queue => 'Cola';

  @override
  String get lyrics => 'Letras';

  @override
  String get playbackSpeed => 'Velocidad de reproducción';

  @override
  String get upNext => 'A continuación';

  @override
  String get queueIsEmpty => 'La cola está vacía';

  @override
  String get noLyricsFound => 'No se encontraron letras';

  @override
  String get sleepTimer => 'Temporizador';

  @override
  String sleepTimerActive(String remaining) {
    return 'Temporizador: $remaining';
  }

  @override
  String get sleepTurnOff => 'Apagar';

  @override
  String sleepMinutes(int count) {
    return '$count minutos';
  }

  @override
  String seekFailed(Object error) {
    return 'Error al buscar: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Error de reproducción: $error';
  }

  @override
  String get editMetadata => 'Editar metadatos';

  @override
  String get batchEditHint =>
      'Marca un campo para aplicarlo a todas las pistas seleccionadas; el resto queda igual.';

  @override
  String get addToFavorites => 'Añadir a Favoritos';

  @override
  String get removeFromFavorites => 'Quitar de Favoritos';

  @override
  String get accentDefault => 'Acento predeterminado';

  @override
  String positionLabel(String time) {
    return 'Posición $time';
  }

  @override
  String get setPinFirst => 'Primero establece un PIN de 4 a 6 dígitos';

  @override
  String get pinMustBeDigits => 'El PIN debe tener 4 a 6 dígitos';

  @override
  String sharingNamed(String name) {
    return 'Compartiendo \"$name\"';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'Se dejó de compartir \"$name\"';
  }

  @override
  String get fieldTitle => 'Título';

  @override
  String get fieldArtist => 'Artista (separado por \";\")';

  @override
  String get fieldAlbum => 'Álbum';

  @override
  String get fieldAlbumArtist => 'Artista del álbum';

  @override
  String get fieldGenre => 'Género (separado por \";\")';

  @override
  String get fieldYear => 'Año';

  @override
  String get fieldTrackNo => 'Pista n.º';

  @override
  String editNTracks(int count) {
    return 'Editar $count pistas';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'No se pudieron leer las etiquetas: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron actualizar $count pistas',
      one: 'No se pudo actualizar $count pista',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Error al guardar: $error';
  }

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get supportDevelopment => 'Apoyar el desarrollo';

  @override
  String get sponsorOnGithub => 'Patrocinar en GitHub';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get dynamicTheme => 'Tema dinámico desde la carátula';

  @override
  String get dynamicThemeSubtitle =>
      'Tiñe la app con los colores de la pista actual';

  @override
  String get accentColor => 'Color de acento';

  @override
  String get accentDynamicHint =>
      'Alternativa cuando la carátula no tiene color destacado';

  @override
  String get accentPickHint => 'Elige el acento de la app';

  @override
  String get stereoWidening => 'Ampliación estéreo';

  @override
  String get stereoWideningHint =>
      'Ajusta el ancho medio/lateral en la salida de escritorio. 100% deja el archivo intacto.';

  @override
  String get width => 'Ancho';

  @override
  String get crossfade => 'Fundido cruzado';

  @override
  String get crossfadeHint =>
      'Superpone el final de una pista con el inicio de la siguiente (escritorio). 0 lo desactiva.';

  @override
  String get duration => 'Duración';

  @override
  String get outputDevice => 'Dispositivo de salida';

  @override
  String get outputDeviceHint =>
      'Elige la salida de audio de escritorio. En Android el enrutamiento sigue la salida del sistema.';

  @override
  String couldNotListDevices(Object error) {
    return 'No se pudieron listar los dispositivos: $error';
  }

  @override
  String get refreshDevices => 'Actualizar dispositivos';

  @override
  String get audioOutput => 'Salida de audio';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Iguala el volumen percibido entre pistas usando las etiquetas de ganancia.';

  @override
  String get equalizerHint =>
      'La reproducción de escritorio aplica el EQ en vivo. El EQ de Android usa los mismos ajustes guardados y se activará con la fase de efectos de audio de Android.';

  @override
  String get replayGainOff => 'Desactivado';

  @override
  String get replayGainTrack => 'Pista';

  @override
  String get replayGainAlbum => 'Álbum';

  @override
  String get preamp => 'Preamplificador';

  @override
  String get equalizer10Band => 'Ecualizador de 10 bandas';

  @override
  String get saveCustom => 'Guardar personalizado';

  @override
  String get eqPre => 'Pre';

  @override
  String get saveEqPreset => 'Guardar ajuste de EQ';

  @override
  String get presetName => 'Nombre del ajuste';

  @override
  String couldNotSavePreset(Object error) {
    return 'No se pudo guardar el ajuste: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'No se pudo eliminar el ajuste: $error';
  }

  @override
  String get version => 'Versión';

  @override
  String get updates => 'Actualizaciones';

  @override
  String get updatesManaged =>
      'Gestionadas por tu gestor de paquetes (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'Buscar actualizaciones automáticamente';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get onLatestVersion => 'Tienes la versión más reciente';

  @override
  String updateCheckFailed(Object error) {
    return 'Error al buscar actualizaciones: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version está disponible';
  }

  @override
  String get updateSkip => 'Omitir';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateNow => 'Actualizar';

  @override
  String updateToVersion(String version) {
    return 'Actualizar a $version';
  }

  @override
  String downloadingPercent(int percent) {
    return 'Descargando… $percent%';
  }

  @override
  String get startingInstaller => 'Iniciando el instalador…';

  @override
  String get downloadAndInstall => 'Descargar e instalar';

  @override
  String invalidRules(Object error) {
    return 'Reglas no válidas: $error';
  }

  @override
  String get enterAName => 'Introduce un nombre';

  @override
  String couldNotSave(Object error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get name => 'Nombre';

  @override
  String get rfTitle => 'Título';

  @override
  String get rfArtist => 'Artista';

  @override
  String get rfAlbum => 'Álbum';

  @override
  String get rfGenre => 'Género';

  @override
  String get rfYear => 'Año';

  @override
  String get rfRating => 'Valoración';

  @override
  String get rfPlayCount => 'Reproducciones';

  @override
  String get rfDuration => 'Duración (ms)';

  @override
  String get rfDateAdded => 'Fecha de adición';

  @override
  String get opContains => 'contiene';

  @override
  String get opIs => 'es';

  @override
  String get opIsNot => 'no es';

  @override
  String get opStartsWith => 'empieza por';

  @override
  String get opEndsWith => 'termina en';

  @override
  String get opNotContains => 'no contiene';

  @override
  String get opInLastDays => 'en los últimos N días';

  @override
  String get ruleMatch => 'Coincidir';

  @override
  String get ruleMatchAll => 'Todas';

  @override
  String get ruleMatchAny => 'Cualquiera';

  @override
  String get ofTheseRules => 'de estas reglas';

  @override
  String get addRule => 'Añadir regla';

  @override
  String get newSmartPlaylist => 'Nueva lista inteligente';

  @override
  String get editSmartPlaylist => 'Editar lista inteligente';

  @override
  String get preview => 'Vista previa';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coincidencias',
      one: '$count coincidencia',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Límite (opcional)';

  @override
  String get ruleValueHint => 'valor';

  @override
  String get removeRule => 'Quitar regla';

  @override
  String get noTracksMatchRules => 'Ninguna pista coincide con estas reglas';

  @override
  String get playAll => 'Reproducir todo';

  @override
  String get sharingTitle => 'Compartir';

  @override
  String get sharingHint =>
      'Elige qué pueden transmitir o descargar los pares de tu red. Los cambios se aplican de inmediato mientras compartes.';

  @override
  String get wholeLibrary => 'Toda la biblioteca';

  @override
  String get noPlaylistsYet => 'Aún no hay listas de reproducción';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'No se pudo actualizar el uso compartido: $error';
  }

  @override
  String get accessLabel => 'Acceso: ';

  @override
  String get accessOpen => 'Abierto';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'Aprobado';

  @override
  String get peersCanLabel => 'Los pares pueden: ';

  @override
  String get streamOnly => 'Solo transmitir';

  @override
  String get streamAndDownload => 'Transmitir + descargar';

  @override
  String get notShared => 'No compartido';

  @override
  String get changePin => 'Cambiar PIN (déjalo vacío para mantenerlo)';

  @override
  String get setPin => 'Establece un PIN de 4 a 6 dígitos';

  @override
  String get approvedModeHint =>
      'Cada nuevo dispositivo pide conectarse; lo permites o lo deniegas en la pantalla de Red (marca \"Siempre\" para recordar un dispositivo).';

  @override
  String downloadedToLibrary(String title) {
    return '\"$title\" descargada a tu biblioteca';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return 'Se descargaron $done de $total pistas$failed a tu biblioteca';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count fallidas)';
  }

  @override
  String downloadFailed(Object error) {
    return 'Error de descarga: $error';
  }

  @override
  String get joinedParty => 'Te uniste a la fiesta — siguiendo al anfitrión';

  @override
  String couldNotJoinParty(Object error) {
    return 'No se pudo unir a la fiesta: $error';
  }

  @override
  String get downloadAllToLibrary => 'Descargar todo a mi biblioteca';

  @override
  String get downloadToLibrary => 'Descargar a mi biblioteca';

  @override
  String get reconnectingToParty =>
      'Reconectando a la fiesta… (toca para salir)';

  @override
  String get leaveParty => 'Salir de la fiesta';

  @override
  String get joinPartySync =>
      'Unirse a la fiesta (sincronizar con el anfitrión)';

  @override
  String get nothingSharedHere => 'Aquí no se comparte nada';

  @override
  String requestedTrack(String title) {
    return '\"$title\" solicitada';
  }

  @override
  String get joinToRequest => 'Únete a la fiesta para solicitar pistas';

  @override
  String get networkTitle => 'Red';

  @override
  String get lanOnlyBanner =>
      'Solo red local — nada sale de tu Wi-Fi. Sin nube, sin cuentas.';

  @override
  String sharingOnPort(String port, String name) {
    return 'Compartiendo en el puerto $port como \"$name\"';
  }

  @override
  String get off => 'Desactivado';

  @override
  String get manageWhatIShareSubtitle =>
      'Listas o toda la biblioteca, con modo de acceso y PIN';

  @override
  String get revokeAllSubtitle =>
      'Desconecta a todos; deberán volver a autenticarse';

  @override
  String get partyModeOnSubtitle =>
      'Los pares conectados siguen tu reproducción en sincronía';

  @override
  String get partyModeOffSubtitle =>
      'Inicia una sesión sincronizada para los pares';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get approvalRequests => 'Solicitudes de aprobación';

  @override
  String get partyRequestsTitle => 'Solicitudes de la fiesta';

  @override
  String peerAllowed(String peer) {
    return '$peer permitido';
  }

  @override
  String peerDenied(String peer) {
    return '$peer denegado';
  }

  @override
  String get incorrectPin => 'PIN incorrecto';

  @override
  String get tooManyAttempts =>
      'Demasiados intentos — espera un momento y reintenta';

  @override
  String accessDenied(String detail) {
    return 'Acceso denegado: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 dígitos';

  @override
  String get connect => 'Conectar';

  @override
  String get ipExampleHint => 'p. ej. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name no está compartiendo nada ahora mismo';
  }

  @override
  String sharedBy(String name) {
    return 'Compartido por $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return 'No se pudo conectar con $name: $error';
  }

  @override
  String get waitingForHost =>
      'Esperando que el anfitrión te permita el acceso…';

  @override
  String get hostDenied => 'El anfitrión denegó tu solicitud';

  @override
  String get enterPin => 'Introduce el PIN';

  @override
  String get connectByIp => 'Conectar por IP';

  @override
  String get enterAddressHint =>
      'Introduce dirección y puerto, p. ej. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Compartir mi biblioteca';

  @override
  String get manageWhatIShare => 'Gestionar lo que comparto';

  @override
  String get revokeAllPeerAccess => 'Revocar todo el acceso de los pares';

  @override
  String get allSessionsRevoked => 'Todas las sesiones de pares revocadas';

  @override
  String get partyMode => 'Modo fiesta';

  @override
  String get discoveredHosts => 'Anfitriones descubiertos';

  @override
  String get connectByIpAddress => 'Conectar por dirección IP';

  @override
  String get reachHostManually =>
      'Conecta manualmente con un anfitrión si no se detecta';

  @override
  String get noHostsFound => 'No se encontraron anfitriones en la red';

  @override
  String get connectionsAndActivity => 'Conexiones y actividad';

  @override
  String get noPeersConnected => 'No hay pares conectados';

  @override
  String get activeSession => 'Sesión activa';

  @override
  String get revoke => 'Revocar';

  @override
  String get clearActivity => 'Borrar actividad';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer quiere conectarse a \"$label\"';
  }

  @override
  String get allowOnce => 'Permitir una vez';

  @override
  String get alwaysAllow => 'Permitir siempre';

  @override
  String get deny => 'Denegar';

  @override
  String requestedByPeer(String peer) {
    return 'Solicitado por $peer';
  }

  @override
  String get dismiss => 'Descartar';

  @override
  String scanFailed(Object error) {
    return 'Error al escanear: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Escaneado: $added añadidas, $updated actualizadas, $skipped sin cambios, $errors errores';
  }

  @override
  String get dropFolderHint =>
      'Suelta una carpeta para añadirla a tu biblioteca';

  @override
  String get scanMusicFolder => 'Escanear una carpeta de música';

  @override
  String get folderPath => 'Ruta de la carpeta';

  @override
  String get libraryFolders => 'Carpetas de la biblioteca';

  @override
  String get scanFolder => 'Escanear carpeta';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Reescaneo: $added añadidas, $updated actualizadas, $removed eliminadas';
  }

  @override
  String removeFolderBody(String path) {
    return '¿Olvidar \"$path\" y quitar sus pistas de la biblioteca? Los archivos del disco no se eliminan.';
  }

  @override
  String get watchingForChanges => 'Vigilando cambios';

  @override
  String get notWatchingManual => 'Sin vigilar (escanea manualmente)';

  @override
  String get watchingTapToStop => 'Vigilando — toca para detener';

  @override
  String get notWatchingTapToWatch => 'Sin vigilar — toca para vigilar';

  @override
  String rescanFailed(Object error) {
    return 'Error al volver a escanear: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'No se pudo cambiar la supervisión: $error';
  }

  @override
  String get removeFolderQuestion => '¿Quitar carpeta?';

  @override
  String get rescanAll => 'Volver a escanear todo';

  @override
  String get noFoldersYet => 'Aún no hay carpetas — usa \"Escanear carpeta\".';

  @override
  String get findDuplicates => 'Buscar duplicados';

  @override
  String couldNotRemove(Object error) {
    return 'No se pudo quitar: $error';
  }

  @override
  String get duplicateTracks => 'Pistas duplicadas';

  @override
  String copiesCount(int count, String title) {
    return '$count copias · $title';
  }

  @override
  String get noDuplicatesFound => 'No se encontraron duplicados.';

  @override
  String get removeExtras => 'Quitar extras';

  @override
  String get kept => 'Conservada';

  @override
  String get removeFromLibrary => 'Quitar de la biblioteca';

  @override
  String get searchHint => 'Buscar canciones, artistas, álbumes…';

  @override
  String get nowPlayingSemantic => 'Reproduciendo ahora';

  @override
  String addedToQueue(int count) {
    return '$count añadidas a la cola';
  }

  @override
  String get clearSelection => 'Borrar selección';

  @override
  String selectedCount(int count) {
    return '$count seleccionadas';
  }

  @override
  String get addToQueue => 'Añadir a la cola';

  @override
  String get editTags => 'Editar etiquetas';

  @override
  String get nothingHereYet => 'Aún no hay nada aquí';

  @override
  String get trackActions => 'Acciones de la pista';

  @override
  String get playNext => 'Reproducir a continuación';

  @override
  String get addToPlaylist => 'Añadir a la lista';

  @override
  String get select => 'Seleccionar';

  @override
  String queuedTrack(String title) {
    return '\"$title\" en cola';
  }

  @override
  String failedToLoad(Object error) {
    return 'Error al cargar: $error';
  }

  @override
  String get libraryEmpty => 'Tu biblioteca está vacía';

  @override
  String get libraryEmptyHintDrop =>
      'Arrastra una carpeta de música aquí o usa el botón de escaneo de la barra superior para añadir una.';

  @override
  String get libraryEmptyHintTap =>
      'Toca el botón de escaneo de la barra superior para añadir una carpeta de música.';

  @override
  String get importPlaylistTitle => 'Importar lista (M3U / PLS)';

  @override
  String get newPlaylist => 'Nueva lista';

  @override
  String importedTracks(int matched, int total) {
    return 'Importadas $matched/$total pistas';
  }

  @override
  String importFailed(Object error) {
    return 'Error al importar: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => '¿Eliminar lista inteligente?';

  @override
  String deleteNamedPermanently(String name) {
    return '¿Eliminar \"$name\" permanentemente?';
  }

  @override
  String get smart => 'Inteligente';

  @override
  String get import => 'Importar';

  @override
  String get autoPlaylists => 'Listas automáticas';

  @override
  String get recentlyPlayed => 'Reproducidas recientemente';

  @override
  String get mostPlayed => 'Más reproducidas';

  @override
  String get neverPlayed => 'Nunca reproducidas';

  @override
  String get favorites => 'Favoritos';

  @override
  String get songs => 'Canciones';

  @override
  String get albums => 'Álbumes';

  @override
  String get artists => 'Artistas';

  @override
  String get genres => 'Géneros';

  @override
  String get recent => 'Reciente';

  @override
  String get settings => 'Ajustes';

  @override
  String get playlists => 'Listas de reproducción';

  @override
  String get smartPlaylists => 'Listas inteligentes';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '$count pista',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Exportar…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'No se pudo quitar la pista: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'No se pudo reordenar la lista: $error';
  }

  @override
  String get playPlaylist => 'Reproducir lista';

  @override
  String get unknownArtist => 'Artista desconocido';

  @override
  String get exportPlaylistTitle => 'Exportar lista';

  @override
  String get noTracksInPlaylist => 'No hay pistas en esta lista';

  @override
  String get renamePlaylist => 'Cambiar nombre de la lista';

  @override
  String get duplicatePlaylist => 'Duplicar lista';

  @override
  String duplicateCopyName(String name) {
    return '$name copia';
  }

  @override
  String exportedPlaylist(String name) {
    return '\"$name\" exportada';
  }

  @override
  String get deletePlaylistQuestion => '¿Eliminar lista?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '\"$title\" añadida a $playlist';
  }

  @override
  String get noAlbums => 'Sin álbumes';

  @override
  String get noArtists => 'Sin artistas';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums álbumes • $tracks pistas';
  }

  @override
  String get noGenres => 'Sin géneros';
}

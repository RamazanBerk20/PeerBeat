// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTagline => 'Локальный + LAN музыкальный плеер';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRemove => 'Убрать';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonApply => 'Применить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonPlay => 'Воспроизвести';

  @override
  String get commonEdit => 'Изменить';

  @override
  String get commonRename => 'Переименовать';

  @override
  String get commonDuplicate => 'Дублировать';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonRefresh => 'Обновить';

  @override
  String get commonReset => 'Сбросить';

  @override
  String get commonPrevious => 'Назад';

  @override
  String get commonNext => 'Вперёд';

  @override
  String get nowPlayingTitle => 'Сейчас играет';

  @override
  String get pause => 'Пауза';

  @override
  String get repeatOff => 'Повтор выключен';

  @override
  String get repeatAll => 'Повторять все';

  @override
  String get repeatOne => 'Повторять один';

  @override
  String get mute => 'Отключить звук';

  @override
  String get unmute => 'Включить звук';

  @override
  String volumePercent(int percent) {
    return '$percent% громкости';
  }

  @override
  String get shuffle => 'Перемешать';

  @override
  String get queue => 'Очередь';

  @override
  String get lyrics => 'Текст песни';

  @override
  String get playbackSpeed => 'Скорость воспроизведения';

  @override
  String get upNext => 'Далее';

  @override
  String get queueIsEmpty => 'Очередь пуста';

  @override
  String get noLyricsFound => 'Текст не найден';

  @override
  String get sleepTimer => 'Таймер сна';

  @override
  String sleepTimerActive(String remaining) {
    return 'Таймер сна: $remaining';
  }

  @override
  String get sleepTurnOff => 'Выключить';

  @override
  String sleepMinutes(int count) {
    return '$count минут';
  }

  @override
  String seekFailed(Object error) {
    return 'Не удалось перемотать: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Ошибка воспроизведения: $error';
  }

  @override
  String get editMetadata => 'Изменить метаданные';

  @override
  String get batchEditHint =>
      'Отметьте поле, чтобы применить его ко всем выбранным трекам; остальное останется как есть.';

  @override
  String get addToFavorites => 'В избранное';

  @override
  String get removeFromFavorites => 'Убрать из избранного';

  @override
  String get accentDefault => 'Акцент по умолчанию';

  @override
  String positionLabel(String time) {
    return 'Позиция $time';
  }

  @override
  String get setPinFirst => 'Сначала задайте PIN из 4–6 цифр';

  @override
  String get pinMustBeDigits => 'PIN должен быть из 4–6 цифр';

  @override
  String sharingNamed(String name) {
    return 'Раздаётся «$name»';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'Раздача «$name» остановлена';
  }

  @override
  String get fieldTitle => 'Название';

  @override
  String get fieldArtist => 'Исполнитель (через \";\")';

  @override
  String get fieldAlbum => 'Альбом';

  @override
  String get fieldAlbumArtist => 'Исполнитель альбома';

  @override
  String get fieldGenre => 'Жанр (через \";\")';

  @override
  String get fieldYear => 'Год';

  @override
  String get fieldTrackNo => '№ трека';

  @override
  String editNTracks(int count) {
    return 'Изменить треков: $count';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'Не удалось прочитать теги: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось обновить $count трека',
      many: 'Не удалось обновить $count треков',
      few: 'Не удалось обновить $count трека',
      one: 'Не удалось обновить $count трек',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get settingsAudio => 'Звук';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get language => 'Язык';

  @override
  String get languageSystemDefault => 'По умолчанию (система)';

  @override
  String get dynamicTheme => 'Динамическая тема по обложке';

  @override
  String get dynamicThemeSubtitle =>
      'Окрашивать приложение в цвета текущего трека';

  @override
  String get accentColor => 'Акцентный цвет';

  @override
  String get accentDynamicHint =>
      'Запасной вариант, когда у обложки нет яркого цвета';

  @override
  String get accentPickHint => 'Выберите акцент приложения';

  @override
  String get stereoWidening => 'Расширение стерео';

  @override
  String get stereoWideningHint =>
      'Регулировка ширины mid/side на выходе ПК. 100% оставляет файл без изменений.';

  @override
  String get width => 'Ширина';

  @override
  String get crossfade => 'Кроссфейд';

  @override
  String get crossfadeHint =>
      'Накладывает конец одного трека на начало следующего (ПК). 0 отключает.';

  @override
  String get duration => 'Длительность';

  @override
  String get outputDevice => 'Устройство вывода';

  @override
  String get outputDeviceHint =>
      'Выберите аудиовыход на ПК. На Android маршрутизация следует за системным выходом.';

  @override
  String couldNotListDevices(Object error) {
    return 'Не удалось получить список устройств: $error';
  }

  @override
  String get refreshDevices => 'Обновить устройства';

  @override
  String get audioOutput => 'Аудиовыход';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Выравнивает воспринимаемую громкость между треками по тегам gain.';

  @override
  String get equalizerHint =>
      'На ПК эквалайзер применяется в реальном времени. На Android эквалайзер использует те же сохранённые настройки и заработает с этапом аудиоэффектов Android.';

  @override
  String get replayGainOff => 'Выкл.';

  @override
  String get replayGainTrack => 'Трек';

  @override
  String get replayGainAlbum => 'Альбом';

  @override
  String get preamp => 'Предусиление';

  @override
  String get equalizer10Band => '10-полосный эквалайзер';

  @override
  String get saveCustom => 'Сохранить свой';

  @override
  String get eqPre => 'Пред.';

  @override
  String get saveEqPreset => 'Сохранить пресет EQ';

  @override
  String get presetName => 'Название пресета';

  @override
  String couldNotSavePreset(Object error) {
    return 'Не удалось сохранить пресет: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'Не удалось удалить пресет: $error';
  }

  @override
  String get version => 'Версия';

  @override
  String get updates => 'Обновления';

  @override
  String get updatesManaged =>
      'Управляются вашим менеджером пакетов (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'Автоматически проверять обновления';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get onLatestVersion => 'У вас последняя версия';

  @override
  String updateCheckFailed(Object error) {
    return 'Не удалось проверить обновления: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'Доступна PeerBeat $version';
  }

  @override
  String get updateSkip => 'Пропустить';

  @override
  String get updateLater => 'Позже';

  @override
  String get updateNow => 'Обновить';

  @override
  String updateToVersion(String version) {
    return 'Обновить до $version';
  }

  @override
  String downloadingPercent(int percent) {
    return 'Загрузка… $percent%';
  }

  @override
  String get startingInstaller => 'Запуск установщика…';

  @override
  String get downloadAndInstall => 'Скачать и установить';

  @override
  String invalidRules(Object error) {
    return 'Недопустимые правила: $error';
  }

  @override
  String get enterAName => 'Введите название';

  @override
  String couldNotSave(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get name => 'Название';

  @override
  String get ruleMatch => 'Совпадение';

  @override
  String get ruleMatchAll => 'Все';

  @override
  String get ruleMatchAny => 'Любое';

  @override
  String get ofTheseRules => 'из этих правил';

  @override
  String get addRule => 'Добавить правило';

  @override
  String get newSmartPlaylist => 'Новый умный плейлист';

  @override
  String get editSmartPlaylist => 'Изменить умный плейлист';

  @override
  String get preview => 'Предпросмотр';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count совпадения',
      many: '$count совпадений',
      few: '$count совпадения',
      one: '$count совпадение',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Лимит (необязательно)';

  @override
  String get ruleValueHint => 'значение';

  @override
  String get removeRule => 'Убрать правило';

  @override
  String get noTracksMatchRules => 'Нет треков, подходящих под эти правила';

  @override
  String get playAll => 'Воспроизвести всё';

  @override
  String get sharingTitle => 'Общий доступ';

  @override
  String get sharingHint =>
      'Выберите, что участники вашей сети могут транслировать или скачивать. Изменения применяются сразу во время раздачи.';

  @override
  String get wholeLibrary => 'Вся библиотека';

  @override
  String get noPlaylistsYet => 'Плейлистов пока нет';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'Не удалось обновить общий доступ: $error';
  }

  @override
  String get accessLabel => 'Доступ: ';

  @override
  String get accessOpen => 'Открытый';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'По одобрению';

  @override
  String get peersCanLabel => 'Участники могут: ';

  @override
  String get streamOnly => 'Только поток';

  @override
  String get streamAndDownload => 'Поток + загрузка';

  @override
  String get notShared => 'Не предоставлено';

  @override
  String get changePin => 'Изменить PIN (оставьте пустым, чтобы сохранить)';

  @override
  String get setPin => 'Задайте PIN из 4–6 цифр';

  @override
  String get approvedModeHint =>
      'Каждое новое устройство запрашивает подключение; вы разрешаете или отклоняете его на экране «Сеть» (отметьте «Всегда», чтобы запомнить устройство).';

  @override
  String downloadedToLibrary(String title) {
    return '«$title» загружен в вашу библиотеку';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return 'Загружено $done из $total треков$failed в вашу библиотеку';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count с ошибкой)';
  }

  @override
  String downloadFailed(Object error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get joinedParty =>
      'Вы присоединились к вечеринке — следуете за хостом';

  @override
  String couldNotJoinParty(Object error) {
    return 'Не удалось присоединиться к вечеринке: $error';
  }

  @override
  String get downloadAllToLibrary => 'Загрузить всё в мою библиотеку';

  @override
  String get downloadToLibrary => 'Загрузить в мою библиотеку';

  @override
  String get reconnectingToParty =>
      'Переподключение к вечеринке… (нажмите, чтобы выйти)';

  @override
  String get leaveParty => 'Покинуть вечеринку';

  @override
  String get joinPartySync => 'Присоединиться (синхронизация с хостом)';

  @override
  String get nothingSharedHere => 'Здесь ничего не предоставлено';

  @override
  String requestedTrack(String title) {
    return 'Запрошен «$title»';
  }

  @override
  String get joinToRequest =>
      'Присоединитесь к вечеринке, чтобы запрашивать треки';

  @override
  String get networkTitle => 'Сеть';

  @override
  String get lanOnlyBanner =>
      'Только локальная сеть — ничего не покидает ваш Wi-Fi. Без облака и аккаунтов.';

  @override
  String sharingOnPort(String port, String name) {
    return 'Раздача на порту $port как «$name»';
  }

  @override
  String get off => 'Выкл.';

  @override
  String get manageWhatIShareSubtitle =>
      'Плейлисты или вся библиотека, с режимом доступа и PIN';

  @override
  String get revokeAllSubtitle =>
      'Отключить всех; им придётся пройти аутентификацию заново';

  @override
  String get partyModeOnSubtitle =>
      'Подключённые участники синхронно следуют за вашим воспроизведением';

  @override
  String get partyModeOffSubtitle =>
      'Запустить синхронную сессию для участников';

  @override
  String get recentActivity => 'Недавняя активность';

  @override
  String get approvalRequests => 'Запросы на одобрение';

  @override
  String get partyRequestsTitle => 'Запросы вечеринки';

  @override
  String peerAllowed(String peer) {
    return '$peer разрешён';
  }

  @override
  String peerDenied(String peer) {
    return '$peer отклонён';
  }

  @override
  String get incorrectPin => 'Неверный PIN';

  @override
  String get tooManyAttempts =>
      'Слишком много попыток — подождите немного и повторите';

  @override
  String accessDenied(String detail) {
    return 'Доступ запрещён: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 цифр';

  @override
  String get connect => 'Подключиться';

  @override
  String get ipExampleHint => 'напр. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name сейчас ничего не предоставляет';
  }

  @override
  String sharedBy(String name) {
    return 'Предоставил $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return 'Не удалось связаться с $name: $error';
  }

  @override
  String get waitingForHost => 'Ожидание разрешения от хоста…';

  @override
  String get hostDenied => 'Хост отклонил ваш запрос';

  @override
  String get enterPin => 'Введите PIN';

  @override
  String get connectByIp => 'Подключиться по IP';

  @override
  String get enterAddressHint =>
      'Введите адрес и порт, напр. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Поделиться библиотекой';

  @override
  String get manageWhatIShare => 'Управление тем, чем делюсь';

  @override
  String get revokeAllPeerAccess => 'Отозвать доступ всех участников';

  @override
  String get allSessionsRevoked => 'Все сессии участников отозваны';

  @override
  String get partyMode => 'Режим вечеринки';

  @override
  String get discoveredHosts => 'Найденные хосты';

  @override
  String get connectByIpAddress => 'Подключиться по IP-адресу';

  @override
  String get reachHostManually =>
      'Подключитесь к хосту вручную, если он не найден';

  @override
  String get noHostsFound => 'В сети не найдено хостов';

  @override
  String get connectionsAndActivity => 'Подключения и активность';

  @override
  String get noPeersConnected => 'Нет подключённых участников';

  @override
  String get activeSession => 'Активная сессия';

  @override
  String get revoke => 'Отозвать';

  @override
  String get clearActivity => 'Очистить активность';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer хочет подключиться к «$label»';
  }

  @override
  String get allowOnce => 'Разрешить один раз';

  @override
  String get alwaysAllow => 'Всегда разрешать';

  @override
  String get deny => 'Отклонить';

  @override
  String requestedByPeer(String peer) {
    return 'Запросил $peer';
  }

  @override
  String get dismiss => 'Закрыть';

  @override
  String scanFailed(Object error) {
    return 'Ошибка сканирования: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Просканировано: $added добавлено, $updated обновлено, $skipped без изменений, $errors ошибок';
  }

  @override
  String get dropFolderHint =>
      'Перетащите папку, чтобы добавить её в библиотеку';

  @override
  String get scanMusicFolder => 'Сканировать папку с музыкой';

  @override
  String get folderPath => 'Путь к папке';

  @override
  String get libraryFolders => 'Папки библиотеки';

  @override
  String get scanFolder => 'Сканировать папку';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Повторное сканирование: добавлено $added, обновлено $updated, удалено $removed';
  }

  @override
  String removeFolderBody(String path) {
    return 'Забыть «$path» и убрать его треки из библиотеки? Файлы на диске не удаляются.';
  }

  @override
  String get watchingForChanges => 'Отслеживает изменения';

  @override
  String get notWatchingManual => 'Не отслеживается (сканируйте вручную)';

  @override
  String get watchingTapToStop => 'Отслеживается — нажмите, чтобы остановить';

  @override
  String get notWatchingTapToWatch =>
      'Не отслеживается — нажмите, чтобы отслеживать';

  @override
  String rescanFailed(Object error) {
    return 'Ошибка повторного сканирования: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'Не удалось изменить отслеживание: $error';
  }

  @override
  String get removeFolderQuestion => 'Убрать папку?';

  @override
  String get rescanAll => 'Пересканировать всё';

  @override
  String get noFoldersYet =>
      'Папок пока нет — используйте «Сканировать папку».';

  @override
  String get findDuplicates => 'Найти дубликаты';

  @override
  String couldNotRemove(Object error) {
    return 'Не удалось убрать: $error';
  }

  @override
  String get duplicateTracks => 'Дубликаты треков';

  @override
  String copiesCount(int count, String title) {
    return '$count копий · $title';
  }

  @override
  String get noDuplicatesFound => 'Дубликаты не найдены.';

  @override
  String get removeExtras => 'Убрать лишние';

  @override
  String get kept => 'Оставлен';

  @override
  String get removeFromLibrary => 'Убрать из библиотеки';

  @override
  String get searchHint => 'Поиск песен, исполнителей, альбомов…';

  @override
  String get nowPlayingSemantic => 'Сейчас играет';

  @override
  String addedToQueue(int count) {
    return 'Добавлено в очередь: $count';
  }

  @override
  String get clearSelection => 'Снять выделение';

  @override
  String selectedCount(int count) {
    return '$count выбрано';
  }

  @override
  String get addToQueue => 'Добавить в очередь';

  @override
  String get editTags => 'Изменить теги';

  @override
  String get nothingHereYet => 'Здесь пока ничего нет';

  @override
  String get trackActions => 'Действия с треком';

  @override
  String get playNext => 'Воспроизвести следующим';

  @override
  String get addToPlaylist => 'Добавить в плейлист';

  @override
  String get select => 'Выбрать';

  @override
  String queuedTrack(String title) {
    return '«$title» в очереди';
  }

  @override
  String failedToLoad(Object error) {
    return 'Не удалось загрузить: $error';
  }

  @override
  String get libraryEmpty => 'Ваша библиотека пуста';

  @override
  String get libraryEmptyHintDrop =>
      'Перетащите сюда папку с музыкой или добавьте её кнопкой сканирования на верхней панели.';

  @override
  String get libraryEmptyHintTap =>
      'Нажмите кнопку сканирования на верхней панели, чтобы добавить папку с музыкой.';

  @override
  String get importPlaylistTitle => 'Импорт плейлиста (M3U / PLS)';

  @override
  String get newPlaylist => 'Новый плейлист';

  @override
  String importedTracks(int matched, int total) {
    return 'Импортировано треков: $matched/$total';
  }

  @override
  String importFailed(Object error) {
    return 'Ошибка импорта: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'Удалить умный плейлист?';

  @override
  String deleteNamedPermanently(String name) {
    return 'Удалить «$name» навсегда?';
  }

  @override
  String get smart => 'Умный';

  @override
  String get import => 'Импорт';

  @override
  String get autoPlaylists => 'Авто-плейлисты';

  @override
  String get recentlyPlayed => 'Недавно проигранные';

  @override
  String get mostPlayed => 'Чаще всего';

  @override
  String get neverPlayed => 'Ни разу';

  @override
  String get favorites => 'Избранное';

  @override
  String get songs => 'Песни';

  @override
  String get albums => 'Альбомы';

  @override
  String get artists => 'Исполнители';

  @override
  String get genres => 'Жанры';

  @override
  String get recent => 'Недавние';

  @override
  String get settings => 'Настройки';

  @override
  String get playlists => 'Плейлисты';

  @override
  String get smartPlaylists => 'Умные плейлисты';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count трека',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Экспорт…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'Не удалось убрать трек: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'Не удалось изменить порядок плейлиста: $error';
  }

  @override
  String get playPlaylist => 'Воспроизвести плейлист';

  @override
  String get unknownArtist => 'Неизвестный исполнитель';

  @override
  String get exportPlaylistTitle => 'Экспорт плейлиста';

  @override
  String get noTracksInPlaylist => 'В этом плейлисте нет треков';

  @override
  String get renamePlaylist => 'Переименовать плейлист';

  @override
  String get duplicatePlaylist => 'Дублировать плейлист';

  @override
  String duplicateCopyName(String name) {
    return '$name копия';
  }

  @override
  String exportedPlaylist(String name) {
    return '«$name» экспортирован';
  }

  @override
  String get deletePlaylistQuestion => 'Удалить плейлист?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '«$title» добавлен в $playlist';
  }

  @override
  String get noAlbums => 'Нет альбомов';

  @override
  String get noArtists => 'Нет исполнителей';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums альбомов • $tracks треков';
  }

  @override
  String get noGenres => 'Нет жанров';
}

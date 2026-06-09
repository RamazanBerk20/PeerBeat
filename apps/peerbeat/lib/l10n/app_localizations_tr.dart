// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTagline => 'Yerel + LAN müzik çalar';

  @override
  String get trayShow => 'PeerBeat\'i göster';

  @override
  String get trayQuit => 'Çık';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonSave => 'Kaydet';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonRemove => 'Kaldır';

  @override
  String get commonDone => 'Bitti';

  @override
  String get commonApply => 'Uygula';

  @override
  String get commonRetry => 'Yeniden dene';

  @override
  String get commonPlay => 'Çal';

  @override
  String get commonEdit => 'Düzenle';

  @override
  String get commonRename => 'Yeniden adlandır';

  @override
  String get commonDuplicate => 'Çoğalt';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonRefresh => 'Yenile';

  @override
  String get commonReset => 'Sıfırla';

  @override
  String get commonPrevious => 'Önceki';

  @override
  String get commonNext => 'Sonraki';

  @override
  String get nowPlayingTitle => 'Şimdi Çalıyor';

  @override
  String get pause => 'Duraklat';

  @override
  String get repeatOff => 'Tekrar kapalı';

  @override
  String get repeatAll => 'Tümünü tekrarla';

  @override
  String get repeatOne => 'Birini tekrarla';

  @override
  String get mute => 'Sessize al';

  @override
  String get unmute => 'Sesi aç';

  @override
  String volumePercent(int percent) {
    return '%$percent ses';
  }

  @override
  String get shuffle => 'Karıştır';

  @override
  String get queue => 'Sıra';

  @override
  String get lyrics => 'Şarkı sözleri';

  @override
  String get playbackSpeed => 'Oynatma hızı';

  @override
  String get upNext => 'Sırada';

  @override
  String get queueIsEmpty => 'Sıra boş';

  @override
  String get noLyricsFound => 'Şarkı sözü bulunamadı';

  @override
  String get sleepTimer => 'Uyku zamanlayıcısı';

  @override
  String sleepTimerActive(String remaining) {
    return 'Uyku zamanlayıcısı: $remaining';
  }

  @override
  String get sleepTurnOff => 'Kapat';

  @override
  String sleepMinutes(int count) {
    return '$count dakika';
  }

  @override
  String seekFailed(Object error) {
    return 'Sarma başarısız: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'Oynatma başarısız: $error';
  }

  @override
  String get editMetadata => 'Üst veriyi düzenle';

  @override
  String get batchEditHint =>
      'Tüm seçili parçalara uygulamak için bir alanı işaretleyin; gerisi olduğu gibi kalır.';

  @override
  String get addToFavorites => 'Favorilere ekle';

  @override
  String get removeFromFavorites => 'Favorilerden çıkar';

  @override
  String get accentDefault => 'Varsayılan vurgu';

  @override
  String positionLabel(String time) {
    return 'Konum $time';
  }

  @override
  String get setPinFirst => 'Önce 4–6 haneli bir PIN belirleyin';

  @override
  String get pinMustBeDigits => 'PIN 4–6 hane olmalı';

  @override
  String sharingNamed(String name) {
    return '\"$name\" paylaşılıyor';
  }

  @override
  String stoppedSharingNamed(String name) {
    return '\"$name\" paylaşımı durduruldu';
  }

  @override
  String get fieldTitle => 'Başlık';

  @override
  String get fieldArtist => 'Sanatçı (\";\" ayraçlı)';

  @override
  String get fieldAlbum => 'Albüm';

  @override
  String get fieldAlbumArtist => 'Albüm sanatçısı';

  @override
  String get fieldGenre => 'Tür (\";\" ayraçlı)';

  @override
  String get fieldYear => 'Yıl';

  @override
  String get fieldTrackNo => 'Parça no';

  @override
  String editNTracks(int count) {
    return '$count parçayı düzenle';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'Etiketler okunamadı: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parça güncellenemedi',
      one: '$count parça güncellenemedi',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'Kaydetme başarısız: $error';
  }

  @override
  String get settingsAudio => 'Ses';

  @override
  String get settingsAppearance => 'Görünüm';

  @override
  String get settingsAbout => 'Hakkında';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistem';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get language => 'Dil';

  @override
  String get languageSystemDefault => 'Sistem varsayılanı';

  @override
  String get dynamicTheme => 'Albüm kapağından dinamik tema';

  @override
  String get dynamicThemeSubtitle =>
      'Uygulamayı mevcut parçanın renkleriyle renklendir';

  @override
  String get accentColor => 'Vurgu rengi';

  @override
  String get accentDynamicHint =>
      'Albüm kapağında belirgin renk yoksa kullanılır';

  @override
  String get accentPickHint => 'Uygulama vurgu rengini seç';

  @override
  String get stereoWidening => 'Stereo genişletme';

  @override
  String get stereoWideningHint =>
      'Masaüstü çıkışında orta/yan genişliğini ayarla. %100 dosyayı değiştirmez.';

  @override
  String get width => 'Genişlik';

  @override
  String get crossfade => 'Çapraz geçiş';

  @override
  String get crossfadeHint =>
      'Bir parçanın sonunu sonrakinin başlangıcıyla üst üste bindir (masaüstü). 0 devre dışı bırakır.';

  @override
  String get duration => 'Süre';

  @override
  String get outputDevice => 'Çıkış aygıtı';

  @override
  String get outputDeviceHint =>
      'Masaüstü ses çıkışını seçin. Android yönlendirmesi sistem çıkışını izler.';

  @override
  String couldNotListDevices(Object error) {
    return 'Aygıtlar listelenemedi: $error';
  }

  @override
  String get refreshDevices => 'Aygıtları yenile';

  @override
  String get audioOutput => 'Ses çıkışı';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'Gain etiketlerini kullanarak parçalar arasındaki algılanan ses düzeyini eşitle.';

  @override
  String get equalizerHint =>
      'Masaüstü oynatma EQ\'yu canlı uygular. Android EQ aynı kayıtlı ayarları kullanır ve Android ses efektleri katmanıyla etkinleşir.';

  @override
  String get replayGainOff => 'Kapalı';

  @override
  String get replayGainTrack => 'Parça';

  @override
  String get replayGainAlbum => 'Albüm';

  @override
  String get preamp => 'Ön yükselteç';

  @override
  String get equalizer10Band => '10 bantlı ekolayzır';

  @override
  String get saveCustom => 'Özel kaydet';

  @override
  String get eqPre => 'Ön';

  @override
  String get saveEqPreset => 'EQ ön ayarını kaydet';

  @override
  String get presetName => 'Ön ayar adı';

  @override
  String couldNotSavePreset(Object error) {
    return 'Ön ayar kaydedilemedi: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'Ön ayar silinemedi: $error';
  }

  @override
  String get version => 'Sürüm';

  @override
  String get updates => 'Güncellemeler';

  @override
  String get updatesManaged =>
      'Paket yöneticiniz tarafından yönetilir (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'Güncellemeleri otomatik denetle';

  @override
  String get checkForUpdates => 'Güncellemeleri denetle';

  @override
  String get onLatestVersion => 'En son sürümü kullanıyorsunuz';

  @override
  String updateCheckFailed(Object error) {
    return 'Güncelleme denetimi başarısız: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version kullanılabilir';
  }

  @override
  String get updateSkip => 'Atla';

  @override
  String get updateLater => 'Sonra';

  @override
  String get updateNow => 'Güncelle';

  @override
  String updateToVersion(String version) {
    return '$version sürümüne güncelle';
  }

  @override
  String downloadingPercent(int percent) {
    return 'İndiriliyor… %$percent';
  }

  @override
  String get startingInstaller => 'Yükleyici başlatılıyor…';

  @override
  String get downloadAndInstall => 'İndir ve yükle';

  @override
  String invalidRules(Object error) {
    return 'Geçersiz kurallar: $error';
  }

  @override
  String get enterAName => 'Bir ad girin';

  @override
  String couldNotSave(Object error) {
    return 'Kaydedilemedi: $error';
  }

  @override
  String get name => 'Ad';

  @override
  String get ruleMatch => 'Eşleştir';

  @override
  String get ruleMatchAll => 'Tümü';

  @override
  String get ruleMatchAny => 'Herhangi';

  @override
  String get ofTheseRules => 'bu kurallardan';

  @override
  String get addRule => 'Kural ekle';

  @override
  String get newSmartPlaylist => 'Yeni akıllı çalma listesi';

  @override
  String get editSmartPlaylist => 'Akıllı çalma listesini düzenle';

  @override
  String get preview => 'Önizleme';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eşleşme',
      one: '$count eşleşme',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'Sınır (isteğe bağlı)';

  @override
  String get ruleValueHint => 'değer';

  @override
  String get removeRule => 'Kuralı kaldır';

  @override
  String get noTracksMatchRules => 'Bu kurallara uyan parça yok';

  @override
  String get playAll => 'Tümünü çal';

  @override
  String get sharingTitle => 'Paylaşım';

  @override
  String get sharingHint =>
      'Ağınızdaki eşlerin neyi akış yapabileceğini veya indirebileceğini seçin. Değişiklikler paylaşım sırasında anında uygulanır.';

  @override
  String get wholeLibrary => 'Tüm kitaplık';

  @override
  String get noPlaylistsYet => 'Henüz çalma listesi yok';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'Paylaşım güncellenemedi: $error';
  }

  @override
  String get accessLabel => 'Erişim: ';

  @override
  String get accessOpen => 'Açık';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => 'Onaylı';

  @override
  String get peersCanLabel => 'Eşler şunu yapabilir: ';

  @override
  String get streamOnly => 'Yalnızca akış';

  @override
  String get streamAndDownload => 'Akış + indirme';

  @override
  String get notShared => 'Paylaşılmıyor';

  @override
  String get changePin => 'PIN değiştir (korumak için boş bırak)';

  @override
  String get setPin => '4–6 haneli bir PIN belirle';

  @override
  String get approvedModeHint =>
      'Her yeni cihaz bağlanmak için izin ister; Ağ ekranında izin verir veya reddedersin (cihazı hatırlamak için \"Her zaman\"ı işaretle).';

  @override
  String downloadedToLibrary(String title) {
    return '\"$title\" kitaplığınıza indirildi';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '$total parçadan $done tanesi$failed kitaplığınıza indirildi';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count başarısız)';
  }

  @override
  String downloadFailed(Object error) {
    return 'İndirme başarısız: $error';
  }

  @override
  String get joinedParty => 'Partiye katıldınız — sunucu takip ediliyor';

  @override
  String couldNotJoinParty(Object error) {
    return 'Partiye katılınamadı: $error';
  }

  @override
  String get downloadAllToLibrary => 'Tümünü kitaplığıma indir';

  @override
  String get downloadToLibrary => 'Kitaplığıma indir';

  @override
  String get reconnectingToParty =>
      'Partiye yeniden bağlanılıyor… (ayrılmak için dokunun)';

  @override
  String get leaveParty => 'Partiden ayrıl';

  @override
  String get joinPartySync => 'Partiye katıl (sunucuyla eşitle)';

  @override
  String get nothingSharedHere => 'Burada paylaşılan bir şey yok';

  @override
  String requestedTrack(String title) {
    return '\"$title\" istendi';
  }

  @override
  String get joinToRequest => 'Parça istemek için partiye katılın';

  @override
  String get networkTitle => 'Ağ';

  @override
  String get lanOnlyBanner =>
      'Yalnızca yerel ağ — hiçbir şey Wi-Fi\'nizden çıkmaz. Bulut yok, hesap yok.';

  @override
  String sharingOnPort(String port, String name) {
    return '$port bağlantı noktasında \"$name\" olarak paylaşılıyor';
  }

  @override
  String get off => 'Kapalı';

  @override
  String get manageWhatIShareSubtitle =>
      'Çalma listeleri veya tüm kitaplık; erişim modu ve PIN ile';

  @override
  String get revokeAllSubtitle =>
      'Herkesin bağlantısını kes; yeniden kimlik doğrulamaları gerekir';

  @override
  String get partyModeOnSubtitle => 'Bağlı eşler oynatmanızı eşzamanlı izler';

  @override
  String get partyModeOffSubtitle => 'Eşler için eşzamanlı bir oturum başlat';

  @override
  String get recentActivity => 'Son etkinlik';

  @override
  String get approvalRequests => 'Onay istekleri';

  @override
  String get partyRequestsTitle => 'Parti istekleri';

  @override
  String peerAllowed(String peer) {
    return '$peer izin verildi';
  }

  @override
  String peerDenied(String peer) {
    return '$peer reddedildi';
  }

  @override
  String get incorrectPin => 'Yanlış PIN';

  @override
  String get tooManyAttempts =>
      'Çok fazla deneme — biraz bekleyip yeniden deneyin';

  @override
  String accessDenied(String detail) {
    return 'Erişim reddedildi: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 hane';

  @override
  String get connect => 'Bağlan';

  @override
  String get ipExampleHint => 'örn. 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name şu anda hiçbir şey paylaşmıyor';
  }

  @override
  String sharedBy(String name) {
    return '$name tarafından paylaşıldı';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return '$name sunucusuna ulaşılamadı: $error';
  }

  @override
  String get waitingForHost => 'Sunucunun izin vermesi bekleniyor…';

  @override
  String get hostDenied => 'Sunucu isteğinizi reddetti';

  @override
  String get enterPin => 'PIN girin';

  @override
  String get connectByIp => 'IP ile bağlan';

  @override
  String get enterAddressHint =>
      'Adres ve bağlantı noktası girin, örn. 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'Kitaplığımı paylaş';

  @override
  String get manageWhatIShare => 'Paylaştıklarımı yönet';

  @override
  String get revokeAllPeerAccess => 'Tüm eş erişimlerini iptal et';

  @override
  String get allSessionsRevoked => 'Tüm eş oturumları iptal edildi';

  @override
  String get partyMode => 'Parti modu';

  @override
  String get discoveredHosts => 'Bulunan sunucular';

  @override
  String get connectByIpAddress => 'IP adresiyle bağlan';

  @override
  String get reachHostManually => 'Bulunamayan bir sunucuya elle ulaşın';

  @override
  String get noHostsFound => 'Ağda sunucu bulunamadı';

  @override
  String get connectionsAndActivity => 'Bağlantılar ve etkinlik';

  @override
  String get noPeersConnected => 'Bağlı eş yok';

  @override
  String get activeSession => 'Etkin oturum';

  @override
  String get revoke => 'İptal et';

  @override
  String get clearActivity => 'Etkinliği temizle';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer, \"$label\" için bağlanmak istiyor';
  }

  @override
  String get allowOnce => 'Bir kez izin ver';

  @override
  String get alwaysAllow => 'Her zaman izin ver';

  @override
  String get deny => 'Reddet';

  @override
  String requestedByPeer(String peer) {
    return '$peer tarafından istendi';
  }

  @override
  String get dismiss => 'Kapat';

  @override
  String scanFailed(Object error) {
    return 'Tarama başarısız: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'Tarandı: $added eklendi, $updated güncellendi, $skipped değişmedi, $errors hata';
  }

  @override
  String get dropFolderHint => 'Kitaplığınıza eklemek için bir klasör bırakın';

  @override
  String get scanMusicFolder => 'Bir müzik klasörü tara';

  @override
  String get folderPath => 'Klasör yolu';

  @override
  String get libraryFolders => 'Kitaplık klasörleri';

  @override
  String get scanFolder => 'Klasör tara';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'Yeniden tarama: $added eklendi, $updated güncellendi, $removed kaldırıldı';
  }

  @override
  String removeFolderBody(String path) {
    return '\"$path\" unutulsun ve parçaları kitaplıktan kaldırılsın mı? Diskteki dosyalar silinmez.';
  }

  @override
  String get watchingForChanges => 'Değişiklikler izleniyor';

  @override
  String get notWatchingManual => 'İzlenmiyor (elle tara)';

  @override
  String get watchingTapToStop => 'İzleniyor — durdurmak için dokun';

  @override
  String get notWatchingTapToWatch => 'İzlenmiyor — izlemek için dokun';

  @override
  String rescanFailed(Object error) {
    return 'Yeniden tarama başarısız: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'İzleme değiştirilemedi: $error';
  }

  @override
  String get removeFolderQuestion => 'Klasör kaldırılsın mı?';

  @override
  String get rescanAll => 'Tümünü yeniden tara';

  @override
  String get noFoldersYet => 'Henüz klasör yok — \"Klasör tara\" kullanın.';

  @override
  String get findDuplicates => 'Yinelenenleri bul';

  @override
  String couldNotRemove(Object error) {
    return 'Kaldırılamadı: $error';
  }

  @override
  String get duplicateTracks => 'Yinelenen parçalar';

  @override
  String copiesCount(int count, String title) {
    return '$count kopya · $title';
  }

  @override
  String get noDuplicatesFound => 'Yinelenen bulunamadı.';

  @override
  String get removeExtras => 'Fazlaları kaldır';

  @override
  String get kept => 'Tutuldu';

  @override
  String get removeFromLibrary => 'Kitaplıktan kaldır';

  @override
  String get searchHint => 'Şarkı, sanatçı, albüm ara…';

  @override
  String get nowPlayingSemantic => 'Şimdi çalıyor';

  @override
  String addedToQueue(int count) {
    return '$count sıraya eklendi';
  }

  @override
  String get clearSelection => 'Seçimi temizle';

  @override
  String selectedCount(int count) {
    return '$count seçildi';
  }

  @override
  String get addToQueue => 'Sıraya ekle';

  @override
  String get editTags => 'Etiketleri düzenle';

  @override
  String get nothingHereYet => 'Burada henüz bir şey yok';

  @override
  String get trackActions => 'Parça işlemleri';

  @override
  String get playNext => 'Sıradakini çal';

  @override
  String get addToPlaylist => 'Çalma listesine ekle';

  @override
  String get select => 'Seç';

  @override
  String queuedTrack(String title) {
    return '\"$title\" sıraya alındı';
  }

  @override
  String failedToLoad(Object error) {
    return 'Yüklenemedi: $error';
  }

  @override
  String get libraryEmpty => 'Kitaplığınız boş';

  @override
  String get libraryEmptyHintDrop =>
      'Buraya bir müzik klasörü sürükleyin veya üst çubuktaki tarama düğmesiyle ekleyin.';

  @override
  String get libraryEmptyHintTap =>
      'Bir müzik klasörü eklemek için üst çubuktaki tarama düğmesine dokunun.';

  @override
  String get importPlaylistTitle => 'Çalma listesi içe aktar (M3U / PLS)';

  @override
  String get newPlaylist => 'Yeni çalma listesi';

  @override
  String importedTracks(int matched, int total) {
    return '$total parçadan $matched tanesi içe aktarıldı';
  }

  @override
  String importFailed(Object error) {
    return 'İçe aktarma başarısız: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'Akıllı çalma listesi silinsin mi?';

  @override
  String deleteNamedPermanently(String name) {
    return '\"$name\" kalıcı olarak silinsin mi?';
  }

  @override
  String get smart => 'Akıllı';

  @override
  String get import => 'İçe aktar';

  @override
  String get autoPlaylists => 'Otomatik listeler';

  @override
  String get recentlyPlayed => 'Son Çalınanlar';

  @override
  String get mostPlayed => 'En Çok Çalınanlar';

  @override
  String get neverPlayed => 'Hiç Çalınmamış';

  @override
  String get favorites => 'Favoriler';

  @override
  String get songs => 'Şarkılar';

  @override
  String get albums => 'Albümler';

  @override
  String get artists => 'Sanatçılar';

  @override
  String get genres => 'Türler';

  @override
  String get recent => 'Son';

  @override
  String get settings => 'Ayarlar';

  @override
  String get playlists => 'Çalma listeleri';

  @override
  String get smartPlaylists => 'Akıllı çalma listeleri';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parça',
      one: '$count parça',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'Dışa aktar…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'Parça kaldırılamadı: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'Çalma listesi yeniden sıralanamadı: $error';
  }

  @override
  String get playPlaylist => 'Çalma listesini çal';

  @override
  String get unknownArtist => 'Bilinmeyen sanatçı';

  @override
  String get exportPlaylistTitle => 'Çalma listesini dışa aktar';

  @override
  String get noTracksInPlaylist => 'Bu çalma listesinde parça yok';

  @override
  String get renamePlaylist => 'Çalma listesini yeniden adlandır';

  @override
  String get duplicatePlaylist => 'Çalma listesini çoğalt';

  @override
  String duplicateCopyName(String name) {
    return '$name kopya';
  }

  @override
  String exportedPlaylist(String name) {
    return '\"$name\" dışa aktarıldı';
  }

  @override
  String get deletePlaylistQuestion => 'Çalma listesi silinsin mi?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '\"$title\", $playlist listesine eklendi';
  }

  @override
  String get noAlbums => 'Albüm yok';

  @override
  String get noArtists => 'Sanatçı yok';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums albüm • $tracks parça';
  }

  @override
  String get noGenres => 'Tür yok';
}

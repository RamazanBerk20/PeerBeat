// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTagline => 'مشغّل موسيقى محلي + شبكة محلية';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRemove => 'إزالة';

  @override
  String get commonDone => 'تم';

  @override
  String get commonApply => 'تطبيق';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonPlay => 'تشغيل';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonRename => 'إعادة تسمية';

  @override
  String get commonDuplicate => 'تكرار';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonRefresh => 'تحديث';

  @override
  String get commonReset => 'إعادة تعيين';

  @override
  String get commonPrevious => 'السابق';

  @override
  String get commonNext => 'التالي';

  @override
  String get nowPlayingTitle => 'قيد التشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get repeatOff => 'إيقاف التكرار';

  @override
  String get repeatAll => 'تكرار الكل';

  @override
  String get repeatOne => 'تكرار واحد';

  @override
  String get mute => 'كتم الصوت';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String volumePercent(int percent) {
    return 'مستوى الصوت $percent%';
  }

  @override
  String get shuffle => 'خلط';

  @override
  String get queue => 'قائمة الانتظار';

  @override
  String get lyrics => 'كلمات الأغنية';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get upNext => 'التالي';

  @override
  String get queueIsEmpty => 'قائمة الانتظار فارغة';

  @override
  String get noLyricsFound => 'لم يُعثر على كلمات';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String sleepTimerActive(String remaining) {
    return 'مؤقت النوم: $remaining';
  }

  @override
  String get sleepTurnOff => 'إيقاف';

  @override
  String sleepMinutes(int count) {
    return '$count دقيقة';
  }

  @override
  String seekFailed(Object error) {
    return 'فشل التقديم: $error';
  }

  @override
  String playbackFailed(Object error) {
    return 'فشل التشغيل: $error';
  }

  @override
  String get editMetadata => 'تعديل البيانات الوصفية';

  @override
  String get batchEditHint =>
      'حدِّد حقلًا لتطبيقه على كل المقاطع المحددة؛ يبقى الباقي كما هو.';

  @override
  String get addToFavorites => 'إضافة إلى المفضلة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get accentDefault => 'التمييز الافتراضي';

  @override
  String positionLabel(String time) {
    return 'الموضع $time';
  }

  @override
  String get setPinFirst => 'عيّن أولًا رمز PIN من 4 إلى 6 أرقام';

  @override
  String get pinMustBeDigits => 'يجب أن يكون رمز PIN من 4 إلى 6 أرقام';

  @override
  String sharingNamed(String name) {
    return 'تتم مشاركة «$name»';
  }

  @override
  String stoppedSharingNamed(String name) {
    return 'تم إيقاف مشاركة «$name»';
  }

  @override
  String get fieldTitle => 'العنوان';

  @override
  String get fieldArtist => 'الفنان (مفصول بـ \";\")';

  @override
  String get fieldAlbum => 'الألبوم';

  @override
  String get fieldAlbumArtist => 'فنان الألبوم';

  @override
  String get fieldGenre => 'النوع (مفصول بـ \";\")';

  @override
  String get fieldYear => 'السنة';

  @override
  String get fieldTrackNo => 'رقم المقطع';

  @override
  String editNTracks(int count) {
    return 'تعديل $count مقطعًا';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'تعذّرت قراءة الوسوم: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذّر تحديث $count مقطع',
      many: 'تعذّر تحديث $count مقطعًا',
      few: 'تعذّر تحديث $count مقاطع',
      two: 'تعذّر تحديث مقطعين',
      one: 'تعذّر تحديث مقطع واحد',
    );
    return '$_temp0';
  }

  @override
  String saveFailed(Object error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String get settingsAudio => 'الصوت';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsAbout => 'حول';

  @override
  String get settingsTheme => 'السمة';

  @override
  String get themeSystem => 'النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystemDefault => 'افتراضي النظام';

  @override
  String get dynamicTheme => 'سمة ديناميكية من غلاف الألبوم';

  @override
  String get dynamicThemeSubtitle => 'تلوين التطبيق بألوان المقطع الحالي';

  @override
  String get accentColor => 'لون التمييز';

  @override
  String get accentDynamicHint => 'بديل عندما لا يحتوي الغلاف على لون بارز';

  @override
  String get accentPickHint => 'اختر لون تمييز التطبيق';

  @override
  String get stereoWidening => 'توسيع الاستريو';

  @override
  String get stereoWideningHint =>
      'اضبط عرض الوسط/الجانب في خرج سطح المكتب. 100% يترك الملف دون تغيير.';

  @override
  String get width => 'العرض';

  @override
  String get crossfade => 'التلاشي المتقاطع';

  @override
  String get crossfadeHint =>
      'يداخل نهاية مقطع مع بداية التالي (سطح المكتب). القيمة 0 تعطّله.';

  @override
  String get duration => 'المدة';

  @override
  String get outputDevice => 'جهاز الإخراج';

  @override
  String get outputDeviceHint =>
      'اختر خرج الصوت لسطح المكتب. على أندرويد يتبع التوجيه خرج النظام.';

  @override
  String couldNotListDevices(Object error) {
    return 'تعذّر سرد الأجهزة: $error';
  }

  @override
  String get refreshDevices => 'تحديث الأجهزة';

  @override
  String get audioOutput => 'خرج الصوت';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint =>
      'يوازن مستوى الصوت المُدرَك بين المقاطع باستخدام وسوم الكسب.';

  @override
  String get equalizerHint =>
      'يطبّق تشغيل سطح المكتب المعادل مباشرةً. يستخدم معادل أندرويد نفس الإعدادات المحفوظة وسيُفعَّل مع مرحلة مؤثرات الصوت في أندرويد.';

  @override
  String get replayGainOff => 'إيقاف';

  @override
  String get replayGainTrack => 'المقطع';

  @override
  String get replayGainAlbum => 'الألبوم';

  @override
  String get preamp => 'مضخّم أولي';

  @override
  String get equalizer10Band => 'معادل صوت بعشرة نطاقات';

  @override
  String get saveCustom => 'حفظ مخصص';

  @override
  String get eqPre => 'أولي';

  @override
  String get saveEqPreset => 'حفظ إعداد المعادل';

  @override
  String get presetName => 'اسم الإعداد';

  @override
  String couldNotSavePreset(Object error) {
    return 'تعذّر حفظ الإعداد: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'تعذّر حذف الإعداد: $error';
  }

  @override
  String get version => 'الإصدار';

  @override
  String get updates => 'التحديثات';

  @override
  String get updatesManaged =>
      'تُدار بواسطة مدير الحزم لديك (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => 'التحقق من التحديثات تلقائيًا';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get onLatestVersion => 'أنت تستخدم أحدث إصدار';

  @override
  String updateCheckFailed(Object error) {
    return 'فشل التحقق من التحديث: $error';
  }

  @override
  String updateAvailable(String version) {
    return '‏PeerBeat $version متاح';
  }

  @override
  String get updateSkip => 'تخطّي';

  @override
  String get updateLater => 'لاحقًا';

  @override
  String get updateNow => 'تحديث';

  @override
  String updateToVersion(String version) {
    return 'التحديث إلى $version';
  }

  @override
  String downloadingPercent(int percent) {
    return 'جارٍ التنزيل… $percent%';
  }

  @override
  String get startingInstaller => 'بدء المثبّت…';

  @override
  String get downloadAndInstall => 'تنزيل وتثبيت';

  @override
  String invalidRules(Object error) {
    return 'قواعد غير صالحة: $error';
  }

  @override
  String get enterAName => 'أدخل اسمًا';

  @override
  String couldNotSave(Object error) {
    return 'تعذّر الحفظ: $error';
  }

  @override
  String get name => 'الاسم';

  @override
  String get ruleMatch => 'المطابقة';

  @override
  String get ruleMatchAll => 'الكل';

  @override
  String get ruleMatchAny => 'أي';

  @override
  String get ofTheseRules => 'من هذه القواعد';

  @override
  String get addRule => 'إضافة قاعدة';

  @override
  String get newSmartPlaylist => 'قائمة تشغيل ذكية جديدة';

  @override
  String get editSmartPlaylist => 'تعديل قائمة التشغيل الذكية';

  @override
  String get preview => 'معاينة';

  @override
  String matchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تطابق',
      many: '$count تطابقًا',
      few: '$count تطابقات',
      two: 'تطابقان',
      one: 'تطابق واحد',
      zero: 'لا تطابقات',
    );
    return '$_temp0';
  }

  @override
  String get limitOptional => 'الحد (اختياري)';

  @override
  String get ruleValueHint => 'القيمة';

  @override
  String get removeRule => 'إزالة القاعدة';

  @override
  String get noTracksMatchRules => 'لا توجد مقاطع مطابقة لهذه القواعد';

  @override
  String get playAll => 'تشغيل الكل';

  @override
  String get sharingTitle => 'المشاركة';

  @override
  String get sharingHint =>
      'اختر ما يمكن للأقران في شبكتك بثّه أو تنزيله. تُطبَّق التغييرات فورًا أثناء المشاركة.';

  @override
  String get wholeLibrary => 'المكتبة كاملة';

  @override
  String get noPlaylistsYet => 'لا توجد قوائم تشغيل بعد';

  @override
  String couldNotUpdateSharing(Object error) {
    return 'تعذّر تحديث المشاركة: $error';
  }

  @override
  String get accessLabel => 'الوصول: ';

  @override
  String get accessOpen => 'مفتوح';

  @override
  String get accessPin => 'رمز PIN';

  @override
  String get accessApproved => 'بموافقة';

  @override
  String get peersCanLabel => 'يمكن للأقران: ';

  @override
  String get streamOnly => 'بث فقط';

  @override
  String get streamAndDownload => 'بث + تنزيل';

  @override
  String get notShared => 'غير مُشارك';

  @override
  String get changePin => 'تغيير رمز PIN (اتركه فارغًا للإبقاء عليه)';

  @override
  String get setPin => 'عيّن رمز PIN من 4 إلى 6 أرقام';

  @override
  String get approvedModeHint =>
      'يطلب كل جهاز جديد الاتصال؛ تسمح به أو ترفضه من شاشة الشبكة (حدِّد \"دائمًا\" لتذكّر الجهاز).';

  @override
  String downloadedToLibrary(String title) {
    return 'تم تنزيل «$title» إلى مكتبتك';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return 'تم تنزيل $done من $total مقطعًا$failed إلى مكتبتك';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count فشل)';
  }

  @override
  String downloadFailed(Object error) {
    return 'فشل التنزيل: $error';
  }

  @override
  String get joinedParty => 'انضممت إلى الحفلة — تتابع المضيف';

  @override
  String couldNotJoinParty(Object error) {
    return 'تعذّر الانضمام إلى الحفلة: $error';
  }

  @override
  String get downloadAllToLibrary => 'تنزيل الكل إلى مكتبتي';

  @override
  String get downloadToLibrary => 'تنزيل إلى مكتبتي';

  @override
  String get reconnectingToParty => 'إعادة الاتصال بالحفلة… (انقر للمغادرة)';

  @override
  String get leaveParty => 'مغادرة الحفلة';

  @override
  String get joinPartySync => 'انضمام إلى الحفلة (مزامنة مع المضيف)';

  @override
  String get nothingSharedHere => 'لا شيء مُشارك هنا';

  @override
  String requestedTrack(String title) {
    return 'تم طلب «$title»';
  }

  @override
  String get joinToRequest => 'انضم إلى الحفلة لطلب المقاطع';

  @override
  String get networkTitle => 'الشبكة';

  @override
  String get lanOnlyBanner =>
      'الشبكة المحلية فقط — لا شيء يغادر شبكة Wi-Fi لديك. لا سحابة ولا حسابات.';

  @override
  String sharingOnPort(String port, String name) {
    return 'تتم المشاركة على المنفذ $port باسم «$name»';
  }

  @override
  String get off => 'إيقاف';

  @override
  String get manageWhatIShareSubtitle =>
      'قوائم التشغيل أو المكتبة كاملة، مع وضع الوصول ورمز PIN';

  @override
  String get revokeAllSubtitle => 'افصل الجميع؛ سيتعيّن عليهم إعادة المصادقة';

  @override
  String get partyModeOnSubtitle => 'يتابع الأقران المتصلون تشغيلك بشكل متزامن';

  @override
  String get partyModeOffSubtitle => 'ابدأ جلسة متزامنة للأقران';

  @override
  String get recentActivity => 'النشاط الأخير';

  @override
  String get approvalRequests => 'طلبات الموافقة';

  @override
  String get partyRequestsTitle => 'طلبات الحفلة';

  @override
  String peerAllowed(String peer) {
    return 'سُمح لـ $peer';
  }

  @override
  String peerDenied(String peer) {
    return 'رُفض $peer';
  }

  @override
  String get incorrectPin => 'رمز PIN غير صحيح';

  @override
  String get tooManyAttempts =>
      'محاولات كثيرة جدًا — انتظر لحظة ثم أعد المحاولة';

  @override
  String accessDenied(String detail) {
    return 'تم رفض الوصول: $detail';
  }

  @override
  String get pinDigitsHint => '4–6 أرقام';

  @override
  String get connect => 'اتصال';

  @override
  String get ipExampleHint => 'مثال 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name لا يشارك أي شيء الآن';
  }

  @override
  String sharedBy(String name) {
    return 'تمت المشاركة بواسطة $name';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return 'تعذّر الوصول إلى $name: $error';
  }

  @override
  String get waitingForHost => 'في انتظار سماح المضيف لك…';

  @override
  String get hostDenied => 'رفض المضيف طلبك';

  @override
  String get enterPin => 'أدخل رمز PIN';

  @override
  String get connectByIp => 'الاتصال عبر IP';

  @override
  String get enterAddressHint =>
      'أدخل العنوان والمنفذ، مثال 192.168.1.42:54213';

  @override
  String get shareMyLibrary => 'مشاركة مكتبتي';

  @override
  String get manageWhatIShare => 'إدارة ما أشاركه';

  @override
  String get revokeAllPeerAccess => 'إلغاء وصول جميع الأقران';

  @override
  String get allSessionsRevoked => 'تم إلغاء جميع جلسات الأقران';

  @override
  String get partyMode => 'وضع الحفلة';

  @override
  String get discoveredHosts => 'المضيفون المكتشفون';

  @override
  String get connectByIpAddress => 'الاتصال عبر عنوان IP';

  @override
  String get reachHostManually => 'تواصل مع مضيف يدويًا إذا لم يُكتشف';

  @override
  String get noHostsFound => 'لم يُعثر على مضيفين في الشبكة';

  @override
  String get connectionsAndActivity => 'الاتصالات والنشاط';

  @override
  String get noPeersConnected => 'لا يوجد أقران متصلون';

  @override
  String get activeSession => 'جلسة نشطة';

  @override
  String get revoke => 'إلغاء';

  @override
  String get clearActivity => 'مسح النشاط';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer يريد الاتصال بـ «$label»';
  }

  @override
  String get allowOnce => 'السماح مرة واحدة';

  @override
  String get alwaysAllow => 'السماح دائمًا';

  @override
  String get deny => 'رفض';

  @override
  String requestedByPeer(String peer) {
    return 'طلبه $peer';
  }

  @override
  String get dismiss => 'تجاهل';

  @override
  String scanFailed(Object error) {
    return 'فشل المسح: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'تم المسح: $added مُضاف، $updated مُحدَّث، $skipped دون تغيير، $errors أخطاء';
  }

  @override
  String get dropFolderHint => 'أفلت مجلدًا لإضافته إلى مكتبتك';

  @override
  String get scanMusicFolder => 'مسح مجلد موسيقى';

  @override
  String get folderPath => 'مسار المجلد';

  @override
  String get libraryFolders => 'مجلدات المكتبة';

  @override
  String get scanFolder => 'مسح مجلد';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return 'إعادة المسح: $added مُضاف، $updated مُحدَّث، $removed مُزال';
  }

  @override
  String removeFolderBody(String path) {
    return 'هل تريد نسيان «$path» وإزالة مقاطعه من المكتبة؟ لا تُحذف الملفات على القرص.';
  }

  @override
  String get watchingForChanges => 'يراقب التغييرات';

  @override
  String get notWatchingManual => 'لا يراقب (امسح يدويًا)';

  @override
  String get watchingTapToStop => 'يراقب — انقر للإيقاف';

  @override
  String get notWatchingTapToWatch => 'لا يراقب — انقر للمراقبة';

  @override
  String rescanFailed(Object error) {
    return 'فشل إعادة المسح: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return 'تعذّر تغيير المراقبة: $error';
  }

  @override
  String get removeFolderQuestion => 'إزالة المجلد؟';

  @override
  String get rescanAll => 'إعادة مسح الكل';

  @override
  String get noFoldersYet => 'لا توجد مجلدات بعد — استخدم «مسح مجلد».';

  @override
  String get findDuplicates => 'البحث عن التكرارات';

  @override
  String couldNotRemove(Object error) {
    return 'تعذّرت الإزالة: $error';
  }

  @override
  String get duplicateTracks => 'مقاطع مكررة';

  @override
  String copiesCount(int count, String title) {
    return '$count نسخ · $title';
  }

  @override
  String get noDuplicatesFound => 'لم يُعثر على تكرارات.';

  @override
  String get removeExtras => 'إزالة الزائدة';

  @override
  String get kept => 'محتفظ به';

  @override
  String get removeFromLibrary => 'إزالة من المكتبة';

  @override
  String get searchHint => 'ابحث عن أغانٍ أو فنانين أو ألبومات…';

  @override
  String get nowPlayingSemantic => 'قيد التشغيل';

  @override
  String addedToQueue(int count) {
    return 'تمت إضافة $count إلى قائمة الانتظار';
  }

  @override
  String get clearSelection => 'مسح التحديد';

  @override
  String selectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get addToQueue => 'إضافة إلى قائمة الانتظار';

  @override
  String get editTags => 'تعديل الوسوم';

  @override
  String get nothingHereYet => 'لا شيء هنا بعد';

  @override
  String get trackActions => 'إجراءات المقطع';

  @override
  String get playNext => 'تشغيل التالي';

  @override
  String get addToPlaylist => 'إضافة إلى قائمة التشغيل';

  @override
  String get select => 'تحديد';

  @override
  String queuedTrack(String title) {
    return '«$title» في قائمة الانتظار';
  }

  @override
  String failedToLoad(Object error) {
    return 'فشل التحميل: $error';
  }

  @override
  String get libraryEmpty => 'مكتبتك فارغة';

  @override
  String get libraryEmptyHintDrop =>
      'اسحب مجلد موسيقى إلى هنا، أو استخدم زر المسح في الشريط العلوي لإضافة واحد.';

  @override
  String get libraryEmptyHintTap =>
      'انقر زر المسح في الشريط العلوي لإضافة مجلد موسيقى.';

  @override
  String get importPlaylistTitle => 'استيراد قائمة تشغيل (M3U / PLS)';

  @override
  String get newPlaylist => 'قائمة تشغيل جديدة';

  @override
  String importedTracks(int matched, int total) {
    return 'تم استيراد $matched/$total مقطع';
  }

  @override
  String importFailed(Object error) {
    return 'فشل الاستيراد: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'حذف قائمة التشغيل الذكية؟';

  @override
  String deleteNamedPermanently(String name) {
    return 'حذف «$name» نهائيًا؟';
  }

  @override
  String get smart => 'ذكية';

  @override
  String get import => 'استيراد';

  @override
  String get autoPlaylists => 'قوائم تلقائية';

  @override
  String get recentlyPlayed => 'شُغّلت مؤخرًا';

  @override
  String get mostPlayed => 'الأكثر تشغيلًا';

  @override
  String get neverPlayed => 'لم تُشغَّل';

  @override
  String get favorites => 'المفضلة';

  @override
  String get songs => 'الأغاني';

  @override
  String get albums => 'الألبومات';

  @override
  String get artists => 'الفنانون';

  @override
  String get genres => 'الأنواع';

  @override
  String get recent => 'الأحدث';

  @override
  String get settings => 'الإعدادات';

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String get smartPlaylists => 'قوائم التشغيل الذكية';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع',
      many: '$count مقطعًا',
      few: '$count مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
      zero: 'لا مقاطع',
    );
    return '$_temp0';
  }

  @override
  String get exportEllipsis => 'تصدير…';

  @override
  String couldNotRemoveTrack(Object error) {
    return 'تعذّرت إزالة المقطع: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'تعذّر إعادة ترتيب قائمة التشغيل: $error';
  }

  @override
  String get playPlaylist => 'تشغيل قائمة التشغيل';

  @override
  String get unknownArtist => 'فنان غير معروف';

  @override
  String get exportPlaylistTitle => 'تصدير قائمة التشغيل';

  @override
  String get noTracksInPlaylist => 'لا توجد مقاطع في قائمة التشغيل هذه';

  @override
  String get renamePlaylist => 'إعادة تسمية قائمة التشغيل';

  @override
  String get duplicatePlaylist => 'تكرار قائمة التشغيل';

  @override
  String duplicateCopyName(String name) {
    return '$name نسخة';
  }

  @override
  String exportedPlaylist(String name) {
    return 'تم تصدير «$name»';
  }

  @override
  String get deletePlaylistQuestion => 'حذف قائمة التشغيل؟';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return 'تمت إضافة «$title» إلى $playlist';
  }

  @override
  String get noAlbums => 'لا ألبومات';

  @override
  String get noArtists => 'لا فنانين';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums ألبوم • $tracks مقطع';
  }

  @override
  String get noGenres => 'لا أنواع';
}

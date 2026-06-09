// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTagline => '本地 + 局域网音乐播放器';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRemove => '移除';

  @override
  String get commonDone => '完成';

  @override
  String get commonApply => '应用';

  @override
  String get commonRetry => '重试';

  @override
  String get commonPlay => '播放';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRename => '重命名';

  @override
  String get commonDuplicate => '复制';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonReset => '重置';

  @override
  String get commonPrevious => '上一首';

  @override
  String get commonNext => '下一首';

  @override
  String get nowPlayingTitle => '正在播放';

  @override
  String get pause => '暂停';

  @override
  String get repeatOff => '关闭重复';

  @override
  String get repeatAll => '全部重复';

  @override
  String get repeatOne => '单曲重复';

  @override
  String get mute => '静音';

  @override
  String get unmute => '取消静音';

  @override
  String volumePercent(int percent) {
    return '音量 $percent%';
  }

  @override
  String get shuffle => '随机播放';

  @override
  String get queue => '队列';

  @override
  String get lyrics => '歌词';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get upNext => '即将播放';

  @override
  String get queueIsEmpty => '队列为空';

  @override
  String get noLyricsFound => '未找到歌词';

  @override
  String get sleepTimer => '睡眠定时器';

  @override
  String sleepTimerActive(String remaining) {
    return '睡眠定时器：$remaining';
  }

  @override
  String get sleepTurnOff => '关闭';

  @override
  String sleepMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String seekFailed(Object error) {
    return '跳转失败：$error';
  }

  @override
  String playbackFailed(Object error) {
    return '播放失败：$error';
  }

  @override
  String get editMetadata => '编辑元数据';

  @override
  String get batchEditHint => '勾选某字段以应用到所有所选曲目；其余保持不变。';

  @override
  String get addToFavorites => '加入收藏';

  @override
  String get removeFromFavorites => '取消收藏';

  @override
  String get accentDefault => '默认强调色';

  @override
  String positionLabel(String time) {
    return '位置 $time';
  }

  @override
  String get setPinFirst => '请先设置 4–6 位 PIN';

  @override
  String get pinMustBeDigits => 'PIN 必须为 4–6 位数字';

  @override
  String sharingNamed(String name) {
    return '正在共享“$name”';
  }

  @override
  String stoppedSharingNamed(String name) {
    return '已停止共享“$name”';
  }

  @override
  String get fieldTitle => '标题';

  @override
  String get fieldArtist => '艺人（用“;”分隔）';

  @override
  String get fieldAlbum => '专辑';

  @override
  String get fieldAlbumArtist => '专辑艺人';

  @override
  String get fieldGenre => '流派（用“;”分隔）';

  @override
  String get fieldYear => '年份';

  @override
  String get fieldTrackNo => '曲目编号';

  @override
  String editNTracks(int count) {
    return '编辑 $count 首曲目';
  }

  @override
  String couldNotReadTags(Object error) {
    return '无法读取标签：$error';
  }

  @override
  String tracksNotUpdated(int count) {
    return '$count 首曲目无法更新';
  }

  @override
  String saveFailed(Object error) {
    return '保存失败：$error';
  }

  @override
  String get settingsAudio => '音频';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageSystemDefault => '系统默认';

  @override
  String get dynamicTheme => '根据专辑封面动态主题';

  @override
  String get dynamicThemeSubtitle => '用当前曲目的颜色为应用着色';

  @override
  String get accentColor => '强调色';

  @override
  String get accentDynamicHint => '当封面没有鲜明颜色时的备用色';

  @override
  String get accentPickHint => '选择应用强调色';

  @override
  String get stereoWidening => '立体声扩展';

  @override
  String get stereoWideningHint => '在桌面输出上调整中/侧宽度。100% 不改变文件。';

  @override
  String get width => '宽度';

  @override
  String get crossfade => '交叉淡入淡出';

  @override
  String get crossfadeHint => '将一首曲目的结尾与下一首的开头重叠（桌面端）。0 表示关闭。';

  @override
  String get duration => '时长';

  @override
  String get outputDevice => '输出设备';

  @override
  String get outputDeviceHint => '选择桌面端音频输出。Android 的路由跟随系统输出。';

  @override
  String couldNotListDevices(Object error) {
    return '无法列出设备：$error';
  }

  @override
  String get refreshDevices => '刷新设备';

  @override
  String get audioOutput => '音频输出';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint => '使用增益标签均衡各曲目的感知响度。';

  @override
  String get equalizerHint =>
      '桌面播放实时应用 EQ。Android EQ 使用相同的已保存设置，并将在 Android 音频效果阶段生效。';

  @override
  String get replayGainOff => '关闭';

  @override
  String get replayGainTrack => '曲目';

  @override
  String get replayGainAlbum => '专辑';

  @override
  String get preamp => '前置放大';

  @override
  String get equalizer10Band => '10 段均衡器';

  @override
  String get saveCustom => '保存自定义';

  @override
  String get eqPre => '前置';

  @override
  String get saveEqPreset => '保存 EQ 预设';

  @override
  String get presetName => '预设名称';

  @override
  String couldNotSavePreset(Object error) {
    return '无法保存预设：$error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return '无法删除预设：$error';
  }

  @override
  String get version => '版本';

  @override
  String get updates => '更新';

  @override
  String get updatesManaged => '由你的包管理器管理（AUR / .deb / AppImage）。';

  @override
  String get checkAutomatically => '自动检查更新';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get onLatestVersion => '你已使用最新版本';

  @override
  String updateCheckFailed(Object error) {
    return '检查更新失败：$error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version 可用';
  }

  @override
  String get updateSkip => '跳过';

  @override
  String get updateLater => '稍后';

  @override
  String get updateNow => '更新';

  @override
  String updateToVersion(String version) {
    return '更新到 $version';
  }

  @override
  String downloadingPercent(int percent) {
    return '正在下载… $percent%';
  }

  @override
  String get startingInstaller => '正在启动安装程序…';

  @override
  String get downloadAndInstall => '下载并安装';

  @override
  String invalidRules(Object error) {
    return '规则无效：$error';
  }

  @override
  String get enterAName => '请输入名称';

  @override
  String couldNotSave(Object error) {
    return '无法保存：$error';
  }

  @override
  String get name => '名称';

  @override
  String get ruleMatch => '匹配';

  @override
  String get ruleMatchAll => '全部';

  @override
  String get ruleMatchAny => '任一';

  @override
  String get ofTheseRules => '条规则';

  @override
  String get addRule => '添加规则';

  @override
  String get newSmartPlaylist => '新建智能播放列表';

  @override
  String get editSmartPlaylist => '编辑智能播放列表';

  @override
  String get preview => '预览';

  @override
  String matchesCount(int count) {
    return '$count 项匹配';
  }

  @override
  String get limitOptional => '限制（可选）';

  @override
  String get ruleValueHint => '值';

  @override
  String get removeRule => '移除规则';

  @override
  String get noTracksMatchRules => '没有符合这些规则的曲目';

  @override
  String get playAll => '播放全部';

  @override
  String get sharingTitle => '共享';

  @override
  String get sharingHint => '选择网络中的对端可以串流或下载的内容。共享期间更改会立即生效。';

  @override
  String get wholeLibrary => '整个音乐库';

  @override
  String get noPlaylistsYet => '还没有播放列表';

  @override
  String couldNotUpdateSharing(Object error) {
    return '无法更新共享：$error';
  }

  @override
  String get accessLabel => '访问：';

  @override
  String get accessOpen => '开放';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => '需批准';

  @override
  String get peersCanLabel => '对端可以：';

  @override
  String get streamOnly => '仅串流';

  @override
  String get streamAndDownload => '串流 + 下载';

  @override
  String get notShared => '未共享';

  @override
  String get changePin => '更改 PIN（留空则保留）';

  @override
  String get setPin => '设置 4–6 位 PIN';

  @override
  String get approvedModeHint => '每台新设备都会请求连接；你在网络界面上允许或拒绝（勾选“始终”以记住设备）。';

  @override
  String downloadedToLibrary(String title) {
    return '已将“$title”下载到你的音乐库';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '已将 $total 首中的 $done 首$failed下载到你的音乐库';
  }

  @override
  String bulkFailedSuffix(int count) {
    return '（$count 首失败）';
  }

  @override
  String downloadFailed(Object error) {
    return '下载失败：$error';
  }

  @override
  String get joinedParty => '已加入派对 — 正在跟随主机';

  @override
  String couldNotJoinParty(Object error) {
    return '无法加入派对：$error';
  }

  @override
  String get downloadAllToLibrary => '全部下载到我的音乐库';

  @override
  String get downloadToLibrary => '下载到我的音乐库';

  @override
  String get reconnectingToParty => '正在重新连接派对…（点按以离开）';

  @override
  String get leaveParty => '离开派对';

  @override
  String get joinPartySync => '加入派对（与主机同步）';

  @override
  String get nothingSharedHere => '这里没有共享内容';

  @override
  String requestedTrack(String title) {
    return '已请求“$title”';
  }

  @override
  String get joinToRequest => '加入派对以请求曲目';

  @override
  String get networkTitle => '网络';

  @override
  String get lanOnlyBanner => '仅限本地网络 — 任何内容都不会离开你的 Wi-Fi。无云端、无账户。';

  @override
  String sharingOnPort(String port, String name) {
    return '正在端口 $port 上以“$name”共享';
  }

  @override
  String get off => '关闭';

  @override
  String get manageWhatIShareSubtitle => '播放列表或整个音乐库，可设访问模式和 PIN';

  @override
  String get revokeAllSubtitle => '断开所有人；他们需要重新认证';

  @override
  String get partyModeOnSubtitle => '已连接的对端会同步跟随你的播放';

  @override
  String get partyModeOffSubtitle => '为对端启动同步会话';

  @override
  String get recentActivity => '最近活动';

  @override
  String get approvalRequests => '批准请求';

  @override
  String get partyRequestsTitle => '派对请求';

  @override
  String peerAllowed(String peer) {
    return '已允许 $peer';
  }

  @override
  String peerDenied(String peer) {
    return '已拒绝 $peer';
  }

  @override
  String get incorrectPin => 'PIN 不正确';

  @override
  String get tooManyAttempts => '尝试次数过多 — 请稍候再试';

  @override
  String accessDenied(String detail) {
    return '访问被拒绝：$detail';
  }

  @override
  String get pinDigitsHint => '4–6 位数字';

  @override
  String get connect => '连接';

  @override
  String get ipExampleHint => '例如 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name 当前未共享任何内容';
  }

  @override
  String sharedBy(String name) {
    return '由 $name 共享';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return '无法连接 $name：$error';
  }

  @override
  String get waitingForHost => '正在等待主机允许…';

  @override
  String get hostDenied => '主机拒绝了你的请求';

  @override
  String get enterPin => '输入 PIN';

  @override
  String get connectByIp => '通过 IP 连接';

  @override
  String get enterAddressHint => '输入地址和端口，例如 192.168.1.42:54213';

  @override
  String get shareMyLibrary => '共享我的音乐库';

  @override
  String get manageWhatIShare => '管理我共享的内容';

  @override
  String get revokeAllPeerAccess => '撤销所有对端访问';

  @override
  String get allSessionsRevoked => '已撤销所有对端会话';

  @override
  String get partyMode => '派对模式';

  @override
  String get discoveredHosts => '发现的主机';

  @override
  String get connectByIpAddress => '通过 IP 地址连接';

  @override
  String get reachHostManually => '如果未被发现，可手动连接主机';

  @override
  String get noHostsFound => '网络中未找到主机';

  @override
  String get connectionsAndActivity => '连接与活动';

  @override
  String get noPeersConnected => '没有已连接的对端';

  @override
  String get activeSession => '活动会话';

  @override
  String get revoke => '撤销';

  @override
  String get clearActivity => '清除活动';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer 想要连接到“$label”';
  }

  @override
  String get allowOnce => '允许一次';

  @override
  String get alwaysAllow => '始终允许';

  @override
  String get deny => '拒绝';

  @override
  String requestedByPeer(String peer) {
    return '由 $peer 请求';
  }

  @override
  String get dismiss => '忽略';

  @override
  String scanFailed(Object error) {
    return '扫描失败：$error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return '扫描完成：新增 $added，更新 $updated，未变 $skipped，错误 $errors';
  }

  @override
  String get dropFolderHint => '拖放文件夹以添加到你的音乐库';

  @override
  String get scanMusicFolder => '扫描音乐文件夹';

  @override
  String get folderPath => '文件夹路径';

  @override
  String get libraryFolders => '音乐库文件夹';

  @override
  String get scanFolder => '扫描文件夹';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return '重新扫描：新增 $added，更新 $updated，移除 $removed';
  }

  @override
  String removeFolderBody(String path) {
    return '忘记“$path”并从音乐库移除其曲目？磁盘上的文件不会被删除。';
  }

  @override
  String get watchingForChanges => '正在监视更改';

  @override
  String get notWatchingManual => '未监视（手动扫描）';

  @override
  String get watchingTapToStop => '正在监视 — 点按停止';

  @override
  String get notWatchingTapToWatch => '未监视 — 点按以监视';

  @override
  String rescanFailed(Object error) {
    return '重新扫描失败：$error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return '无法更改监视：$error';
  }

  @override
  String get removeFolderQuestion => '移除文件夹？';

  @override
  String get rescanAll => '全部重新扫描';

  @override
  String get noFoldersYet => '还没有文件夹 — 请使用“扫描文件夹”。';

  @override
  String get findDuplicates => '查找重复项';

  @override
  String couldNotRemove(Object error) {
    return '无法移除：$error';
  }

  @override
  String get duplicateTracks => '重复曲目';

  @override
  String copiesCount(int count, String title) {
    return '$count 份副本 · $title';
  }

  @override
  String get noDuplicatesFound => '未发现重复项。';

  @override
  String get removeExtras => '移除多余项';

  @override
  String get kept => '保留';

  @override
  String get removeFromLibrary => '从音乐库移除';

  @override
  String get searchHint => '搜索歌曲、艺人、专辑…';

  @override
  String get nowPlayingSemantic => '正在播放';

  @override
  String addedToQueue(int count) {
    return '已将 $count 项加入队列';
  }

  @override
  String get clearSelection => '清除选择';

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get addToQueue => '加入队列';

  @override
  String get editTags => '编辑标签';

  @override
  String get nothingHereYet => '这里还什么都没有';

  @override
  String get trackActions => '曲目操作';

  @override
  String get playNext => '下一首播放';

  @override
  String get addToPlaylist => '添加到播放列表';

  @override
  String get select => '选择';

  @override
  String queuedTrack(String title) {
    return '已将“$title”加入队列';
  }

  @override
  String failedToLoad(Object error) {
    return '加载失败：$error';
  }

  @override
  String get libraryEmpty => '你的音乐库为空';

  @override
  String get libraryEmptyHintDrop => '将音乐文件夹拖到这里，或使用顶栏的扫描按钮添加。';

  @override
  String get libraryEmptyHintTap => '点按顶栏的扫描按钮以添加音乐文件夹。';

  @override
  String get importPlaylistTitle => '导入播放列表 (M3U / PLS)';

  @override
  String get newPlaylist => '新建播放列表';

  @override
  String importedTracks(int matched, int total) {
    return '已导入 $total 首中的 $matched 首';
  }

  @override
  String importFailed(Object error) {
    return '导入失败：$error';
  }

  @override
  String get deleteSmartPlaylistQuestion => '删除智能播放列表？';

  @override
  String deleteNamedPermanently(String name) {
    return '永久删除“$name”？';
  }

  @override
  String get smart => '智能';

  @override
  String get import => '导入';

  @override
  String get autoPlaylists => '自动列表';

  @override
  String get recentlyPlayed => '最近播放';

  @override
  String get mostPlayed => '最常播放';

  @override
  String get neverPlayed => '从未播放';

  @override
  String get favorites => '收藏';

  @override
  String get songs => '歌曲';

  @override
  String get albums => '专辑';

  @override
  String get artists => '艺人';

  @override
  String get genres => '流派';

  @override
  String get recent => '最近';

  @override
  String get settings => '设置';

  @override
  String get playlists => '播放列表';

  @override
  String get smartPlaylists => '智能播放列表';

  @override
  String trackCount(int count) {
    return '$count 首曲目';
  }

  @override
  String get exportEllipsis => '导出…';

  @override
  String couldNotRemoveTrack(Object error) {
    return '无法移除曲目：$error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return '无法重新排序播放列表：$error';
  }

  @override
  String get playPlaylist => '播放该列表';

  @override
  String get unknownArtist => '未知艺人';

  @override
  String get exportPlaylistTitle => '导出播放列表';

  @override
  String get noTracksInPlaylist => '该播放列表中没有曲目';

  @override
  String get renamePlaylist => '重命名播放列表';

  @override
  String get duplicatePlaylist => '复制播放列表';

  @override
  String exportedPlaylist(String name) {
    return '已导出“$name”';
  }

  @override
  String get deletePlaylistQuestion => '删除播放列表？';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '已将“$title”添加到 $playlist';
  }

  @override
  String get noAlbums => '没有专辑';

  @override
  String get noArtists => '没有艺人';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums 张专辑 • $tracks 首曲目';
  }

  @override
  String get noGenres => '没有流派';
}

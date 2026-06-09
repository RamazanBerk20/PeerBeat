// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTagline => 'ローカル + LAN ミュージックプレーヤー';

  @override
  String get trayShow => 'PeerBeat を表示';

  @override
  String get trayQuit => '終了';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '削除';

  @override
  String get commonRemove => '削除';

  @override
  String get commonDone => '完了';

  @override
  String get commonApply => '適用';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonPlay => '再生';

  @override
  String get commonEdit => '編集';

  @override
  String get commonRename => '名前を変更';

  @override
  String get commonDuplicate => '複製';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonRefresh => '更新';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonPrevious => '前へ';

  @override
  String get commonNext => '次へ';

  @override
  String get nowPlayingTitle => '再生中';

  @override
  String get pause => '一時停止';

  @override
  String get repeatOff => 'リピートなし';

  @override
  String get repeatAll => '全曲リピート';

  @override
  String get repeatOne => '1曲リピート';

  @override
  String get mute => 'ミュート';

  @override
  String get unmute => 'ミュート解除';

  @override
  String volumePercent(int percent) {
    return '音量 $percent%';
  }

  @override
  String get shuffle => 'シャッフル';

  @override
  String get queue => 'キュー';

  @override
  String get lyrics => '歌詞';

  @override
  String get playbackSpeed => '再生速度';

  @override
  String get upNext => '次に再生';

  @override
  String get queueIsEmpty => 'キューは空です';

  @override
  String get noLyricsFound => '歌詞が見つかりません';

  @override
  String get sleepTimer => 'スリープタイマー';

  @override
  String sleepTimerActive(String remaining) {
    return 'スリープタイマー: $remaining';
  }

  @override
  String get sleepTurnOff => 'オフ';

  @override
  String sleepMinutes(int count) {
    return '$count 分';
  }

  @override
  String seekFailed(Object error) {
    return 'シークに失敗しました: $error';
  }

  @override
  String playbackFailed(Object error) {
    return '再生に失敗しました: $error';
  }

  @override
  String get editMetadata => 'メタデータを編集';

  @override
  String get batchEditHint => 'いずれかの項目にチェックを入れると、選択中のすべての曲に適用されます。残りはそのままです。';

  @override
  String get addToFavorites => 'お気に入りに追加';

  @override
  String get removeFromFavorites => 'お気に入りから削除';

  @override
  String get accentDefault => '既定のアクセント';

  @override
  String positionLabel(String time) {
    return '位置 $time';
  }

  @override
  String get setPinFirst => '先に 4〜6 桁の PIN を設定してください';

  @override
  String get pinMustBeDigits => 'PIN は 4〜6 桁にしてください';

  @override
  String sharingNamed(String name) {
    return '「$name」を共有中';
  }

  @override
  String stoppedSharingNamed(String name) {
    return '「$name」の共有を停止しました';
  }

  @override
  String get fieldTitle => 'タイトル';

  @override
  String get fieldArtist => 'アーティスト（\";\" 区切り）';

  @override
  String get fieldAlbum => 'アルバム';

  @override
  String get fieldAlbumArtist => 'アルバムアーティスト';

  @override
  String get fieldGenre => 'ジャンル（\";\" 区切り）';

  @override
  String get fieldYear => '年';

  @override
  String get fieldTrackNo => 'トラック番号';

  @override
  String editNTracks(int count) {
    return '$count 曲を編集';
  }

  @override
  String couldNotReadTags(Object error) {
    return 'タグを読み取れませんでした: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    return '$count 曲を更新できませんでした';
  }

  @override
  String saveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get settingsAudio => 'オーディオ';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsAbout => '情報';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get language => '言語';

  @override
  String get languageSystemDefault => 'システムの既定';

  @override
  String get dynamicTheme => 'アルバムアートから動的テーマ';

  @override
  String get dynamicThemeSubtitle => '再生中の曲の色でアプリを彩ります';

  @override
  String get accentColor => 'アクセントカラー';

  @override
  String get accentDynamicHint => 'アルバムアートに強い色がないときの代替';

  @override
  String get accentPickHint => 'アプリのアクセントを選択';

  @override
  String get stereoWidening => 'ステレオ拡張';

  @override
  String get stereoWideningHint =>
      'デスクトップ出力でミッド/サイド幅を調整します。100% でファイルは変更されません。';

  @override
  String get width => '幅';

  @override
  String get crossfade => 'クロスフェード';

  @override
  String get crossfadeHint => '1曲の終わりと次の曲の始まりを重ねます（デスクトップ）。0 で無効。';

  @override
  String get duration => '長さ';

  @override
  String get outputDevice => '出力デバイス';

  @override
  String get outputDeviceHint =>
      'デスクトップの音声出力を選択します。Android のルーティングはシステム出力に従います。';

  @override
  String couldNotListDevices(Object error) {
    return 'デバイスを一覧表示できませんでした: $error';
  }

  @override
  String get refreshDevices => 'デバイスを更新';

  @override
  String get audioOutput => 'オーディオ出力';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint => 'ゲインタグを使って曲間の体感音量をそろえます。';

  @override
  String get equalizerHint =>
      'デスクトップ再生では EQ をリアルタイムで適用します。Android の EQ は同じ保存設定を使い、Android のオーディオエフェクト対応で有効になります。';

  @override
  String get replayGainOff => 'オフ';

  @override
  String get replayGainTrack => 'トラック';

  @override
  String get replayGainAlbum => 'アルバム';

  @override
  String get preamp => 'プリアンプ';

  @override
  String get equalizer10Band => '10 バンドイコライザー';

  @override
  String get saveCustom => 'カスタムを保存';

  @override
  String get eqPre => 'プリ';

  @override
  String get saveEqPreset => 'EQ プリセットを保存';

  @override
  String get presetName => 'プリセット名';

  @override
  String couldNotSavePreset(Object error) {
    return 'プリセットを保存できませんでした: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return 'プリセットを削除できませんでした: $error';
  }

  @override
  String get version => 'バージョン';

  @override
  String get updates => 'アップデート';

  @override
  String get updatesManaged => 'パッケージマネージャーで管理されます (AUR / .deb / AppImage)。';

  @override
  String get checkAutomatically => '自動的にアップデートを確認';

  @override
  String get checkForUpdates => 'アップデートを確認';

  @override
  String get onLatestVersion => '最新バージョンです';

  @override
  String updateCheckFailed(Object error) {
    return 'アップデートの確認に失敗しました: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version が利用可能です';
  }

  @override
  String get updateSkip => 'スキップ';

  @override
  String get updateLater => '後で';

  @override
  String get updateNow => 'アップデート';

  @override
  String updateToVersion(String version) {
    return '$version に更新';
  }

  @override
  String downloadingPercent(int percent) {
    return 'ダウンロード中… $percent%';
  }

  @override
  String get startingInstaller => 'インストーラーを起動中…';

  @override
  String get downloadAndInstall => 'ダウンロードしてインストール';

  @override
  String invalidRules(Object error) {
    return '無効なルール: $error';
  }

  @override
  String get enterAName => '名前を入力してください';

  @override
  String couldNotSave(Object error) {
    return '保存できませんでした: $error';
  }

  @override
  String get name => '名前';

  @override
  String get ruleMatch => '一致';

  @override
  String get ruleMatchAll => 'すべて';

  @override
  String get ruleMatchAny => 'いずれか';

  @override
  String get ofTheseRules => 'のルール';

  @override
  String get addRule => 'ルールを追加';

  @override
  String get newSmartPlaylist => '新しいスマートプレイリスト';

  @override
  String get editSmartPlaylist => 'スマートプレイリストを編集';

  @override
  String get preview => 'プレビュー';

  @override
  String matchesCount(int count) {
    return '$count 件一致';
  }

  @override
  String get limitOptional => '上限 (任意)';

  @override
  String get ruleValueHint => '値';

  @override
  String get removeRule => 'ルールを削除';

  @override
  String get noTracksMatchRules => 'これらのルールに一致する曲はありません';

  @override
  String get playAll => 'すべて再生';

  @override
  String get sharingTitle => '共有';

  @override
  String get sharingHint =>
      'ネットワーク上のピアがストリーミングまたはダウンロードできる内容を選びます。変更は共有中すぐに反映されます。';

  @override
  String get wholeLibrary => 'ライブラリ全体';

  @override
  String get noPlaylistsYet => 'プレイリストはまだありません';

  @override
  String couldNotUpdateSharing(Object error) {
    return '共有を更新できませんでした: $error';
  }

  @override
  String get accessLabel => 'アクセス: ';

  @override
  String get accessOpen => 'オープン';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => '承認制';

  @override
  String get peersCanLabel => 'ピアの権限: ';

  @override
  String get streamOnly => 'ストリームのみ';

  @override
  String get streamAndDownload => 'ストリーム + ダウンロード';

  @override
  String get notShared => '未共有';

  @override
  String get changePin => 'PIN を変更（空欄で維持）';

  @override
  String get setPin => '4〜6 桁の PIN を設定';

  @override
  String get approvedModeHint =>
      '新しいデバイスは接続を要求します。ネットワーク画面で許可または拒否します（デバイスを記憶するには「常に」をチェック）。';

  @override
  String downloadedToLibrary(String title) {
    return '「$title」をライブラリにダウンロードしました';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '$total 曲中 $done 曲$failedをライブラリにダウンロードしました';
  }

  @override
  String bulkFailedSuffix(int count) {
    return '（$count 件失敗）';
  }

  @override
  String downloadFailed(Object error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String get joinedParty => 'パーティーに参加しました — ホストに追従します';

  @override
  String couldNotJoinParty(Object error) {
    return 'パーティーに参加できませんでした: $error';
  }

  @override
  String get downloadAllToLibrary => 'すべてをライブラリにダウンロード';

  @override
  String get downloadToLibrary => 'ライブラリにダウンロード';

  @override
  String get reconnectingToParty => 'パーティーに再接続中…（タップで退出）';

  @override
  String get leaveParty => 'パーティーを退出';

  @override
  String get joinPartySync => 'パーティーに参加（ホストと同期）';

  @override
  String get nothingSharedHere => 'ここに共有はありません';

  @override
  String requestedTrack(String title) {
    return '「$title」をリクエストしました';
  }

  @override
  String get joinToRequest => '曲をリクエストするにはパーティーに参加してください';

  @override
  String get networkTitle => 'ネットワーク';

  @override
  String get lanOnlyBanner => 'ローカルネットワークのみ — Wi-Fi の外には何も出ません。クラウドもアカウントも不要。';

  @override
  String sharingOnPort(String port, String name) {
    return 'ポート $port で「$name」として共有中';
  }

  @override
  String get off => 'オフ';

  @override
  String get manageWhatIShareSubtitle => 'プレイリストまたはライブラリ全体（アクセスモードと PIN 付き）';

  @override
  String get revokeAllSubtitle => '全員を切断します。再認証が必要になります';

  @override
  String get partyModeOnSubtitle => '接続中のピアがあなたの再生に同期して追従します';

  @override
  String get partyModeOffSubtitle => 'ピア向けの同期セッションを開始';

  @override
  String get recentActivity => '最近のアクティビティ';

  @override
  String get approvalRequests => '承認リクエスト';

  @override
  String get partyRequestsTitle => 'パーティーリクエスト';

  @override
  String peerAllowed(String peer) {
    return '$peer を許可しました';
  }

  @override
  String peerDenied(String peer) {
    return '$peer を拒否しました';
  }

  @override
  String get incorrectPin => 'PIN が正しくありません';

  @override
  String get tooManyAttempts => '試行回数が多すぎます — 少し待ってから再試行してください';

  @override
  String accessDenied(String detail) {
    return 'アクセスが拒否されました: $detail';
  }

  @override
  String get pinDigitsHint => '4〜6 桁';

  @override
  String get connect => '接続';

  @override
  String get ipExampleHint => '例: 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name は現在何も共有していません';
  }

  @override
  String sharedBy(String name) {
    return '$name が共有';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return '$name に接続できませんでした: $error';
  }

  @override
  String get waitingForHost => 'ホストの許可を待っています…';

  @override
  String get hostDenied => 'ホストがリクエストを拒否しました';

  @override
  String get enterPin => 'PIN を入力';

  @override
  String get connectByIp => 'IP で接続';

  @override
  String get enterAddressHint => 'アドレスとポートを入力（例: 192.168.1.42:54213）';

  @override
  String get shareMyLibrary => '自分のライブラリを共有';

  @override
  String get manageWhatIShare => '共有内容を管理';

  @override
  String get revokeAllPeerAccess => 'すべてのピアのアクセスを取り消す';

  @override
  String get allSessionsRevoked => 'すべてのピアセッションを取り消しました';

  @override
  String get partyMode => 'パーティーモード';

  @override
  String get discoveredHosts => '検出されたホスト';

  @override
  String get connectByIpAddress => 'IP アドレスで接続';

  @override
  String get reachHostManually => '検出されない場合は手動でホストに接続';

  @override
  String get noHostsFound => 'ネットワークにホストが見つかりません';

  @override
  String get connectionsAndActivity => '接続とアクティビティ';

  @override
  String get noPeersConnected => '接続中のピアはありません';

  @override
  String get activeSession => 'アクティブなセッション';

  @override
  String get revoke => '取り消す';

  @override
  String get clearActivity => 'アクティビティを消去';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer が「$label」への接続を求めています';
  }

  @override
  String get allowOnce => '1 回だけ許可';

  @override
  String get alwaysAllow => '常に許可';

  @override
  String get deny => '拒否';

  @override
  String requestedByPeer(String peer) {
    return '$peer がリクエスト';
  }

  @override
  String get dismiss => '閉じる';

  @override
  String scanFailed(Object error) {
    return 'スキャンに失敗しました: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return 'スキャン完了: $added 件追加、$updated 件更新、$skipped 件変更なし、$errors 件エラー';
  }

  @override
  String get dropFolderHint => 'フォルダーをドロップしてライブラリに追加';

  @override
  String get scanMusicFolder => '音楽フォルダーをスキャン';

  @override
  String get folderPath => 'フォルダーのパス';

  @override
  String get libraryFolders => 'ライブラリのフォルダー';

  @override
  String get scanFolder => 'フォルダーをスキャン';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return '再スキャン: $added 件追加、$updated 件更新、$removed 件削除';
  }

  @override
  String removeFolderBody(String path) {
    return '「$path」を忘れて、その曲をライブラリから削除しますか？ ディスク上のファイルは削除されません。';
  }

  @override
  String get watchingForChanges => '変更を監視中';

  @override
  String get notWatchingManual => '監視なし（手動でスキャン）';

  @override
  String get watchingTapToStop => '監視中 — タップで停止';

  @override
  String get notWatchingTapToWatch => '監視なし — タップで監視';

  @override
  String rescanFailed(Object error) {
    return '再スキャンに失敗しました: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return '監視を変更できませんでした: $error';
  }

  @override
  String get removeFolderQuestion => 'フォルダーを削除しますか？';

  @override
  String get rescanAll => 'すべて再スキャン';

  @override
  String get noFoldersYet => 'フォルダーはまだありません —「フォルダーをスキャン」を使用してください。';

  @override
  String get findDuplicates => '重複を検索';

  @override
  String couldNotRemove(Object error) {
    return '削除できませんでした: $error';
  }

  @override
  String get duplicateTracks => '重複した曲';

  @override
  String copiesCount(int count, String title) {
    return '$count 件のコピー · $title';
  }

  @override
  String get noDuplicatesFound => '重複は見つかりませんでした。';

  @override
  String get removeExtras => '余分を削除';

  @override
  String get kept => '保持';

  @override
  String get removeFromLibrary => 'ライブラリから削除';

  @override
  String get searchHint => '曲、アーティスト、アルバムを検索…';

  @override
  String get nowPlayingSemantic => '再生中';

  @override
  String addedToQueue(int count) {
    return '$count 件をキューに追加しました';
  }

  @override
  String get clearSelection => '選択を解除';

  @override
  String selectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get addToQueue => 'キューに追加';

  @override
  String get editTags => 'タグを編集';

  @override
  String get nothingHereYet => 'まだ何もありません';

  @override
  String get trackActions => '曲の操作';

  @override
  String get playNext => '次に再生';

  @override
  String get addToPlaylist => 'プレイリストに追加';

  @override
  String get select => '選択';

  @override
  String queuedTrack(String title) {
    return '「$title」をキューに追加しました';
  }

  @override
  String failedToLoad(Object error) {
    return '読み込みに失敗しました: $error';
  }

  @override
  String get libraryEmpty => 'ライブラリは空です';

  @override
  String get libraryEmptyHintDrop => '音楽フォルダーをここにドラッグするか、上部バーのスキャンボタンで追加します。';

  @override
  String get libraryEmptyHintTap => '上部バーのスキャンボタンをタップして音楽フォルダーを追加します。';

  @override
  String get importPlaylistTitle => 'プレイリストをインポート (M3U / PLS)';

  @override
  String get newPlaylist => '新しいプレイリスト';

  @override
  String importedTracks(int matched, int total) {
    return '$total 曲中 $matched 曲をインポートしました';
  }

  @override
  String importFailed(Object error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => 'スマートプレイリストを削除しますか？';

  @override
  String deleteNamedPermanently(String name) {
    return '「$name」を完全に削除しますか？';
  }

  @override
  String get smart => 'スマート';

  @override
  String get import => 'インポート';

  @override
  String get autoPlaylists => '自動プレイリスト';

  @override
  String get recentlyPlayed => '最近再生した曲';

  @override
  String get mostPlayed => '再生回数が多い曲';

  @override
  String get neverPlayed => '未再生の曲';

  @override
  String get favorites => 'お気に入り';

  @override
  String get songs => '曲';

  @override
  String get albums => 'アルバム';

  @override
  String get artists => 'アーティスト';

  @override
  String get genres => 'ジャンル';

  @override
  String get recent => '最近';

  @override
  String get settings => '設定';

  @override
  String get playlists => 'プレイリスト';

  @override
  String get smartPlaylists => 'スマートプレイリスト';

  @override
  String trackCount(int count) {
    return '$count 曲';
  }

  @override
  String get exportEllipsis => 'エクスポート…';

  @override
  String couldNotRemoveTrack(Object error) {
    return '曲を削除できませんでした: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return 'プレイリストを並べ替えられませんでした: $error';
  }

  @override
  String get playPlaylist => 'プレイリストを再生';

  @override
  String get unknownArtist => '不明なアーティスト';

  @override
  String get exportPlaylistTitle => 'プレイリストをエクスポート';

  @override
  String get noTracksInPlaylist => 'このプレイリストに曲はありません';

  @override
  String get renamePlaylist => 'プレイリストの名前を変更';

  @override
  String get duplicatePlaylist => 'プレイリストを複製';

  @override
  String duplicateCopyName(String name) {
    return '$name のコピー';
  }

  @override
  String exportedPlaylist(String name) {
    return '「$name」をエクスポートしました';
  }

  @override
  String get deletePlaylistQuestion => 'プレイリストを削除しますか？';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '「$title」を $playlist に追加しました';
  }

  @override
  String get noAlbums => 'アルバムなし';

  @override
  String get noArtists => 'アーティストなし';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums アルバム • $tracks 曲';
  }

  @override
  String get noGenres => 'ジャンルなし';
}

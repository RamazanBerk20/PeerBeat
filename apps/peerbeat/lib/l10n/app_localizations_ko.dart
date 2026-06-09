// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTagline => '로컬 + LAN 음악 플레이어';

  @override
  String get commonCancel => '취소';

  @override
  String get commonSave => '저장';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonRemove => '제거';

  @override
  String get commonDone => '완료';

  @override
  String get commonApply => '적용';

  @override
  String get commonRetry => '다시 시도';

  @override
  String get commonPlay => '재생';

  @override
  String get commonEdit => '편집';

  @override
  String get commonRename => '이름 변경';

  @override
  String get commonDuplicate => '복제';

  @override
  String get commonClose => '닫기';

  @override
  String get commonRefresh => '새로 고침';

  @override
  String get commonReset => '초기화';

  @override
  String get commonPrevious => '이전';

  @override
  String get commonNext => '다음';

  @override
  String get nowPlayingTitle => '재생 중';

  @override
  String get pause => '일시정지';

  @override
  String get repeatOff => '반복 끄기';

  @override
  String get repeatAll => '전체 반복';

  @override
  String get repeatOne => '한 곡 반복';

  @override
  String get mute => '음소거';

  @override
  String get unmute => '음소거 해제';

  @override
  String volumePercent(int percent) {
    return '음량 $percent%';
  }

  @override
  String get shuffle => '셔플';

  @override
  String get queue => '대기열';

  @override
  String get lyrics => '가사';

  @override
  String get playbackSpeed => '재생 속도';

  @override
  String get upNext => '다음 곡';

  @override
  String get queueIsEmpty => '대기열이 비어 있습니다';

  @override
  String get noLyricsFound => '가사를 찾을 수 없습니다';

  @override
  String get sleepTimer => '수면 타이머';

  @override
  String sleepTimerActive(String remaining) {
    return '수면 타이머: $remaining';
  }

  @override
  String get sleepTurnOff => '끄기';

  @override
  String sleepMinutes(int count) {
    return '$count분';
  }

  @override
  String seekFailed(Object error) {
    return '탐색 실패: $error';
  }

  @override
  String playbackFailed(Object error) {
    return '재생 실패: $error';
  }

  @override
  String get editMetadata => '메타데이터 편집';

  @override
  String get batchEditHint => '필드를 선택하면 선택한 모든 트랙에 적용됩니다. 나머지는 그대로 유지됩니다.';

  @override
  String get addToFavorites => '즐겨찾기에 추가';

  @override
  String get removeFromFavorites => '즐겨찾기에서 제거';

  @override
  String get accentDefault => '기본 강조색';

  @override
  String positionLabel(String time) {
    return '위치 $time';
  }

  @override
  String get setPinFirst => '먼저 4~6자리 PIN을 설정하세요';

  @override
  String get pinMustBeDigits => 'PIN은 4~6자리여야 합니다';

  @override
  String sharingNamed(String name) {
    return '\"$name\" 공유 중';
  }

  @override
  String stoppedSharingNamed(String name) {
    return '\"$name\" 공유 중지됨';
  }

  @override
  String get fieldTitle => '제목';

  @override
  String get fieldArtist => '아티스트 (\";\"로 구분)';

  @override
  String get fieldAlbum => '앨범';

  @override
  String get fieldAlbumArtist => '앨범 아티스트';

  @override
  String get fieldGenre => '장르 (\";\"로 구분)';

  @override
  String get fieldYear => '연도';

  @override
  String get fieldTrackNo => '트랙 번호';

  @override
  String editNTracks(int count) {
    return '$count개 트랙 편집';
  }

  @override
  String couldNotReadTags(Object error) {
    return '태그를 읽을 수 없습니다: $error';
  }

  @override
  String tracksNotUpdated(int count) {
    return '$count개 트랙을 업데이트할 수 없습니다';
  }

  @override
  String saveFailed(Object error) {
    return '저장 실패: $error';
  }

  @override
  String get settingsAudio => '오디오';

  @override
  String get settingsAppearance => '모양';

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsTheme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get language => '언어';

  @override
  String get languageSystemDefault => '시스템 기본값';

  @override
  String get dynamicTheme => '앨범 아트 기반 동적 테마';

  @override
  String get dynamicThemeSubtitle => '현재 트랙의 색상으로 앱을 물들입니다';

  @override
  String get accentColor => '강조 색상';

  @override
  String get accentDynamicHint => '앨범 아트에 뚜렷한 색이 없을 때의 대체 색상';

  @override
  String get accentPickHint => '앱 강조 색상 선택';

  @override
  String get stereoWidening => '스테레오 확장';

  @override
  String get stereoWideningHint =>
      '데스크톱 출력에서 미드/사이드 폭을 조정합니다. 100%는 파일을 변경하지 않습니다.';

  @override
  String get width => '폭';

  @override
  String get crossfade => '크로스페이드';

  @override
  String get crossfadeHint => '한 곡의 끝과 다음 곡의 시작을 겹칩니다 (데스크톱). 0이면 끕니다.';

  @override
  String get duration => '길이';

  @override
  String get outputDevice => '출력 장치';

  @override
  String get outputDeviceHint =>
      '데스크톱 오디오 출력을 선택하세요. Android 라우팅은 시스템 출력을 따릅니다.';

  @override
  String couldNotListDevices(Object error) {
    return '장치를 나열할 수 없습니다: $error';
  }

  @override
  String get refreshDevices => '장치 새로 고침';

  @override
  String get audioOutput => '오디오 출력';

  @override
  String get replayGain => 'ReplayGain';

  @override
  String get replayGainHint => '게인 태그를 사용해 트랙 간 체감 음량을 고르게 맞춥니다.';

  @override
  String get equalizerHint =>
      '데스크톱 재생은 EQ를 실시간으로 적용합니다. Android EQ는 동일한 저장 설정을 사용하며 Android 오디오 효과 단계에서 활성화됩니다.';

  @override
  String get replayGainOff => '끔';

  @override
  String get replayGainTrack => '트랙';

  @override
  String get replayGainAlbum => '앨범';

  @override
  String get preamp => '프리앰프';

  @override
  String get equalizer10Band => '10밴드 이퀄라이저';

  @override
  String get saveCustom => '사용자 지정 저장';

  @override
  String get eqPre => '프리';

  @override
  String get saveEqPreset => 'EQ 프리셋 저장';

  @override
  String get presetName => '프리셋 이름';

  @override
  String couldNotSavePreset(Object error) {
    return '프리셋을 저장할 수 없습니다: $error';
  }

  @override
  String couldNotDeletePreset(Object error) {
    return '프리셋을 삭제할 수 없습니다: $error';
  }

  @override
  String get version => '버전';

  @override
  String get updates => '업데이트';

  @override
  String get updatesManaged => '패키지 관리자가 관리합니다 (AUR / .deb / AppImage).';

  @override
  String get checkAutomatically => '자동으로 업데이트 확인';

  @override
  String get checkForUpdates => '업데이트 확인';

  @override
  String get onLatestVersion => '최신 버전을 사용 중입니다';

  @override
  String updateCheckFailed(Object error) {
    return '업데이트 확인 실패: $error';
  }

  @override
  String updateAvailable(String version) {
    return 'PeerBeat $version 사용 가능';
  }

  @override
  String get updateSkip => '건너뛰기';

  @override
  String get updateLater => '나중에';

  @override
  String get updateNow => '업데이트';

  @override
  String updateToVersion(String version) {
    return '$version(으)로 업데이트';
  }

  @override
  String downloadingPercent(int percent) {
    return '다운로드 중… $percent%';
  }

  @override
  String get startingInstaller => '설치 프로그램 시작 중…';

  @override
  String get downloadAndInstall => '다운로드 후 설치';

  @override
  String invalidRules(Object error) {
    return '잘못된 규칙: $error';
  }

  @override
  String get enterAName => '이름을 입력하세요';

  @override
  String couldNotSave(Object error) {
    return '저장할 수 없습니다: $error';
  }

  @override
  String get name => '이름';

  @override
  String get ruleMatch => '일치';

  @override
  String get ruleMatchAll => '모두';

  @override
  String get ruleMatchAny => '아무거나';

  @override
  String get ofTheseRules => '개 규칙 중';

  @override
  String get addRule => '규칙 추가';

  @override
  String get newSmartPlaylist => '새 스마트 재생목록';

  @override
  String get editSmartPlaylist => '스마트 재생목록 편집';

  @override
  String get preview => '미리보기';

  @override
  String matchesCount(int count) {
    return '$count개 일치';
  }

  @override
  String get limitOptional => '제한 (선택 사항)';

  @override
  String get ruleValueHint => '값';

  @override
  String get removeRule => '규칙 제거';

  @override
  String get noTracksMatchRules => '이 규칙에 맞는 트랙이 없습니다';

  @override
  String get playAll => '모두 재생';

  @override
  String get sharingTitle => '공유';

  @override
  String get sharingHint =>
      '네트워크의 피어가 스트리밍하거나 다운로드할 수 있는 항목을 선택하세요. 공유 중에는 변경 사항이 즉시 적용됩니다.';

  @override
  String get wholeLibrary => '전체 라이브러리';

  @override
  String get noPlaylistsYet => '아직 재생목록이 없습니다';

  @override
  String couldNotUpdateSharing(Object error) {
    return '공유를 업데이트할 수 없습니다: $error';
  }

  @override
  String get accessLabel => '접근: ';

  @override
  String get accessOpen => '공개';

  @override
  String get accessPin => 'PIN';

  @override
  String get accessApproved => '승인제';

  @override
  String get peersCanLabel => '피어 권한: ';

  @override
  String get streamOnly => '스트리밍만';

  @override
  String get streamAndDownload => '스트리밍 + 다운로드';

  @override
  String get notShared => '공유 안 함';

  @override
  String get changePin => 'PIN 변경 (유지하려면 비워 두기)';

  @override
  String get setPin => '4~6자리 PIN 설정';

  @override
  String get approvedModeHint =>
      '새 기기마다 연결을 요청합니다. 네트워크 화면에서 허용하거나 거부하세요(기기를 기억하려면 \"항상\" 체크).';

  @override
  String downloadedToLibrary(String title) {
    return '\"$title\"을(를) 라이브러리에 다운로드했습니다';
  }

  @override
  String downloadedBulk(int done, int total, String failed) {
    return '$total개 중 $done개 트랙$failed을(를) 라이브러리에 다운로드했습니다';
  }

  @override
  String bulkFailedSuffix(int count) {
    return ' ($count개 실패)';
  }

  @override
  String downloadFailed(Object error) {
    return '다운로드 실패: $error';
  }

  @override
  String get joinedParty => '파티에 참여함 — 호스트를 따라갑니다';

  @override
  String couldNotJoinParty(Object error) {
    return '파티에 참여할 수 없습니다: $error';
  }

  @override
  String get downloadAllToLibrary => '모두 내 라이브러리에 다운로드';

  @override
  String get downloadToLibrary => '내 라이브러리에 다운로드';

  @override
  String get reconnectingToParty => '파티에 다시 연결 중… (나가려면 탭)';

  @override
  String get leaveParty => '파티 나가기';

  @override
  String get joinPartySync => '파티 참여 (호스트와 동기화)';

  @override
  String get nothingSharedHere => '여기에 공유된 것이 없습니다';

  @override
  String requestedTrack(String title) {
    return '\"$title\" 요청함';
  }

  @override
  String get joinToRequest => '트랙을 요청하려면 파티에 참여하세요';

  @override
  String get networkTitle => '네트워크';

  @override
  String get lanOnlyBanner =>
      '로컬 네트워크 전용 — 어떤 것도 Wi-Fi를 벗어나지 않습니다. 클라우드도 계정도 없습니다.';

  @override
  String sharingOnPort(String port, String name) {
    return '포트 $port에서 \"$name\"(으)로 공유 중';
  }

  @override
  String get off => '끔';

  @override
  String get manageWhatIShareSubtitle => '재생목록 또는 전체 라이브러리, 접근 모드 및 PIN 포함';

  @override
  String get revokeAllSubtitle => '모두 연결 해제; 다시 인증해야 합니다';

  @override
  String get partyModeOnSubtitle => '연결된 피어가 재생을 동기화하여 따라갑니다';

  @override
  String get partyModeOffSubtitle => '피어를 위한 동기화 세션 시작';

  @override
  String get recentActivity => '최근 활동';

  @override
  String get approvalRequests => '승인 요청';

  @override
  String get partyRequestsTitle => '파티 요청';

  @override
  String peerAllowed(String peer) {
    return '$peer 허용됨';
  }

  @override
  String peerDenied(String peer) {
    return '$peer 거부됨';
  }

  @override
  String get incorrectPin => '잘못된 PIN';

  @override
  String get tooManyAttempts => '시도가 너무 많습니다 — 잠시 후 다시 시도하세요';

  @override
  String accessDenied(String detail) {
    return '접근 거부됨: $detail';
  }

  @override
  String get pinDigitsHint => '4~6자리';

  @override
  String get connect => '연결';

  @override
  String get ipExampleHint => '예: 192.168.1.42:54213';

  @override
  String hostNotSharing(String name) {
    return '$name은(는) 지금 아무것도 공유하지 않습니다';
  }

  @override
  String sharedBy(String name) {
    return '$name이(가) 공유함';
  }

  @override
  String couldNotReachHost(String name, Object error) {
    return '$name에 연결할 수 없습니다: $error';
  }

  @override
  String get waitingForHost => '호스트의 허용을 기다리는 중…';

  @override
  String get hostDenied => '호스트가 요청을 거부했습니다';

  @override
  String get enterPin => 'PIN 입력';

  @override
  String get connectByIp => 'IP로 연결';

  @override
  String get enterAddressHint => '주소와 포트를 입력하세요. 예: 192.168.1.42:54213';

  @override
  String get shareMyLibrary => '내 라이브러리 공유';

  @override
  String get manageWhatIShare => '공유 항목 관리';

  @override
  String get revokeAllPeerAccess => '모든 피어 접근 취소';

  @override
  String get allSessionsRevoked => '모든 피어 세션이 취소되었습니다';

  @override
  String get partyMode => '파티 모드';

  @override
  String get discoveredHosts => '발견된 호스트';

  @override
  String get connectByIpAddress => 'IP 주소로 연결';

  @override
  String get reachHostManually => '발견되지 않으면 수동으로 호스트에 연결';

  @override
  String get noHostsFound => '네트워크에서 호스트를 찾을 수 없습니다';

  @override
  String get connectionsAndActivity => '연결 및 활동';

  @override
  String get noPeersConnected => '연결된 피어가 없습니다';

  @override
  String get activeSession => '활성 세션';

  @override
  String get revoke => '취소';

  @override
  String get clearActivity => '활동 지우기';

  @override
  String peerWantsToConnect(String peer, String label) {
    return '$peer이(가) \"$label\"에 연결하려고 합니다';
  }

  @override
  String get allowOnce => '한 번 허용';

  @override
  String get alwaysAllow => '항상 허용';

  @override
  String get deny => '거부';

  @override
  String requestedByPeer(String peer) {
    return '$peer이(가) 요청함';
  }

  @override
  String get dismiss => '닫기';

  @override
  String scanFailed(Object error) {
    return '스캔 실패: $error';
  }

  @override
  String scanSummary(int added, int updated, int skipped, int errors) {
    return '스캔 완료: $added개 추가, $updated개 업데이트, $skipped개 변경 없음, $errors개 오류';
  }

  @override
  String get dropFolderHint => '폴더를 끌어다 놓아 라이브러리에 추가';

  @override
  String get scanMusicFolder => '음악 폴더 스캔';

  @override
  String get folderPath => '폴더 경로';

  @override
  String get libraryFolders => '라이브러리 폴더';

  @override
  String get scanFolder => '폴더 스캔';

  @override
  String rescanSummary(int added, int updated, int removed) {
    return '다시 스캔: $added개 추가, $updated개 업데이트, $removed개 제거';
  }

  @override
  String removeFolderBody(String path) {
    return '\"$path\"을(를) 잊고 해당 트랙을 라이브러리에서 제거할까요? 디스크의 파일은 삭제되지 않습니다.';
  }

  @override
  String get watchingForChanges => '변경 사항 감시 중';

  @override
  String get notWatchingManual => '감시 안 함 (수동 스캔)';

  @override
  String get watchingTapToStop => '감시 중 — 탭하여 중지';

  @override
  String get notWatchingTapToWatch => '감시 안 함 — 탭하여 감시';

  @override
  String rescanFailed(Object error) {
    return '다시 스캔 실패: $error';
  }

  @override
  String couldNotChangeWatching(Object error) {
    return '감시를 변경할 수 없습니다: $error';
  }

  @override
  String get removeFolderQuestion => '폴더를 제거할까요?';

  @override
  String get rescanAll => '모두 다시 스캔';

  @override
  String get noFoldersYet => '아직 폴더가 없습니다 — \"폴더 스캔\"을 사용하세요.';

  @override
  String get findDuplicates => '중복 찾기';

  @override
  String couldNotRemove(Object error) {
    return '제거할 수 없습니다: $error';
  }

  @override
  String get duplicateTracks => '중복 트랙';

  @override
  String copiesCount(int count, String title) {
    return '$count개 사본 · $title';
  }

  @override
  String get noDuplicatesFound => '중복을 찾을 수 없습니다.';

  @override
  String get removeExtras => '여분 제거';

  @override
  String get kept => '유지됨';

  @override
  String get removeFromLibrary => '라이브러리에서 제거';

  @override
  String get searchHint => '노래, 아티스트, 앨범 검색…';

  @override
  String get nowPlayingSemantic => '재생 중';

  @override
  String addedToQueue(int count) {
    return '$count개를 대기열에 추가했습니다';
  }

  @override
  String get clearSelection => '선택 해제';

  @override
  String selectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get addToQueue => '대기열에 추가';

  @override
  String get editTags => '태그 편집';

  @override
  String get nothingHereYet => '아직 아무것도 없습니다';

  @override
  String get trackActions => '트랙 작업';

  @override
  String get playNext => '다음에 재생';

  @override
  String get addToPlaylist => '재생목록에 추가';

  @override
  String get select => '선택';

  @override
  String queuedTrack(String title) {
    return '\"$title\"을(를) 대기열에 추가했습니다';
  }

  @override
  String failedToLoad(Object error) {
    return '불러오기 실패: $error';
  }

  @override
  String get libraryEmpty => '라이브러리가 비어 있습니다';

  @override
  String get libraryEmptyHintDrop => '음악 폴더를 여기로 드래그하거나 상단 바의 스캔 버튼으로 추가하세요.';

  @override
  String get libraryEmptyHintTap => '상단 바의 스캔 버튼을 탭하여 음악 폴더를 추가하세요.';

  @override
  String get importPlaylistTitle => '재생목록 가져오기 (M3U / PLS)';

  @override
  String get newPlaylist => '새 재생목록';

  @override
  String importedTracks(int matched, int total) {
    return '$total개 중 $matched개 트랙을 가져왔습니다';
  }

  @override
  String importFailed(Object error) {
    return '가져오기 실패: $error';
  }

  @override
  String get deleteSmartPlaylistQuestion => '스마트 재생목록을 삭제할까요?';

  @override
  String deleteNamedPermanently(String name) {
    return '\"$name\"을(를) 영구적으로 삭제할까요?';
  }

  @override
  String get smart => '스마트';

  @override
  String get import => '가져오기';

  @override
  String get autoPlaylists => '자동 재생목록';

  @override
  String get recentlyPlayed => '최근 재생';

  @override
  String get mostPlayed => '가장 많이 재생';

  @override
  String get neverPlayed => '재생 안 함';

  @override
  String get favorites => '즐겨찾기';

  @override
  String get songs => '노래';

  @override
  String get albums => '앨범';

  @override
  String get artists => '아티스트';

  @override
  String get genres => '장르';

  @override
  String get recent => '최근';

  @override
  String get settings => '설정';

  @override
  String get playlists => '재생목록';

  @override
  String get smartPlaylists => '스마트 재생목록';

  @override
  String trackCount(int count) {
    return '$count개 트랙';
  }

  @override
  String get exportEllipsis => '내보내기…';

  @override
  String couldNotRemoveTrack(Object error) {
    return '트랙을 제거할 수 없습니다: $error';
  }

  @override
  String couldNotReorderPlaylist(Object error) {
    return '재생목록 순서를 변경할 수 없습니다: $error';
  }

  @override
  String get playPlaylist => '재생목록 재생';

  @override
  String get unknownArtist => '알 수 없는 아티스트';

  @override
  String get exportPlaylistTitle => '재생목록 내보내기';

  @override
  String get noTracksInPlaylist => '이 재생목록에 트랙이 없습니다';

  @override
  String get renamePlaylist => '재생목록 이름 변경';

  @override
  String get duplicatePlaylist => '재생목록 복제';

  @override
  String duplicateCopyName(String name) {
    return '$name 사본';
  }

  @override
  String exportedPlaylist(String name) {
    return '\"$name\"을(를) 내보냈습니다';
  }

  @override
  String get deletePlaylistQuestion => '재생목록을 삭제할까요?';

  @override
  String addedTrackToPlaylist(String title, String playlist) {
    return '\"$title\"을(를) $playlist에 추가했습니다';
  }

  @override
  String get noAlbums => '앨범 없음';

  @override
  String get noArtists => '아티스트 없음';

  @override
  String artistSummary(int albums, int tracks) {
    return '$albums개 앨범 • $tracks개 트랙';
  }

  @override
  String get noGenres => '장르 없음';
}

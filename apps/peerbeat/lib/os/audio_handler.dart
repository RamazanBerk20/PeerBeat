import 'package:audio_service/audio_service.dart';

import '../playback/player.dart';

/// Bridges the OS media session (Android lockscreen / notification / output
/// switcher) to the app's [player]. We don't let audio_service drive playback —
/// it's a thin session/notification layer over our own queue — so we expose
/// exactly the controls we want: previous · play/pause · next (no stop), and map
/// them back onto the [PlayerController]. The metadata + position come straight
/// from the player.
class PeerBeatAudioHandler extends BaseAudioHandler {
  PeerBeatAudioHandler() {
    player.addListener(_onPlayer);
    player.positionNotifier.addListener(_onPosition);
    _onPlayer();
  }

  String _lastItemKey = '';

  void _onPlayer() {
    _pushMediaItem();
    _pushState();
  }

  void _onPosition() => _pushState();

  void _pushMediaItem() {
    final t = player.current;
    if (t == null) return;
    // Only re-publish when the track actually changes (avoid churn per tick).
    final key = '${t.id}';
    if (key == _lastItemKey) return;
    _lastItemKey = key;
    final art = t.artPath;
    mediaItem.add(
      MediaItem(
        id: key,
        title: t.title,
        // Empty (not null) when unknown so the applet never prints "null".
        artist: t.artist.isEmpty ? '' : t.artist,
        album: t.album.isEmpty ? '' : t.album,
        duration: Duration(milliseconds: t.durationMs),
        artUri: (art != null && art.isNotEmpty) ? Uri.file(art) : null,
      ),
    );
  }

  void _pushState() {
    final playing = player.playing;
    playbackState.add(
      PlaybackState(
        // Fixed layout: previous · play/pause · next. No stop button.
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: playing,
        updatePosition: player.position,
        speed: player.speed,
      ),
    );
  }

  // ── Session commands → the app player ──────────────────────────────────────
  @override
  Future<void> play() async {
    if (!player.playing) player.toggle();
  }

  @override
  Future<void> pause() async {
    if (player.playing) player.toggle();
  }

  @override
  Future<void> skipToNext() => player.next();

  @override
  Future<void> skipToPrevious() => player.previous();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    // No stop control is shown, but hardware/automation may still call it.
    if (player.playing) player.toggle();
  }
}

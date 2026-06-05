import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/audio/audio_engine.dart';
import 'package:peerbeat/playback/player.dart';
import 'package:peerbeat/src/rust/api/audio.dart' show OutputDeviceRow;
import 'package:peerbeat/src/rust/db/tracks.dart';

void main() {
  test('repeat off advances to the next queued track at EOF', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    await controller.playQueue([_track(1), _track(2)], 0);
    engine.emitPosition(const Duration(milliseconds: 1000));
    engine.emitPlaying(false);
    await _settle();

    expect(controller.current?.id, 2);
    expect(engine.playedPaths, ['/tmp/1.mp3', '/tmp/2.mp3']);
  });

  test('repeat off does not replay the final queued track at EOF', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    await controller.playQueue([_track(1)], 0);
    engine.emitPosition(const Duration(milliseconds: 1000));
    engine.emitPlaying(false);
    await _settle();

    expect(controller.current?.id, 1);
    expect(engine.playedPaths, ['/tmp/1.mp3']);
    expect(controller.playing, isFalse);
  });

  test('repeat one replays the current track at EOF', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    controller.setRepeat(RepeatMode.one);
    await controller.playQueue([_track(1), _track(2)], 0);
    engine.emitPosition(const Duration(milliseconds: 1000));
    engine.emitPlaying(false);
    await _settle();

    expect(controller.current?.id, 1);
    expect(engine.playedPaths, ['/tmp/1.mp3', '/tmp/1.mp3']);
  });

  test('user pause near end does not advance', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    await controller.playQueue([_track(1), _track(2)], 0);
    engine.emitPosition(const Duration(milliseconds: 900));
    controller.toggle();
    await _settle();

    expect(controller.current?.id, 1);
    expect(engine.playedPaths, ['/tmp/1.mp3']);
  });

  test(
    'position at duration advances even if backend still reports playing',
    () async {
      final engine = _FakeAudioEngine();
      final controller = PlayerController.forTest(engine: engine);
      addTearDown(controller.dispose);

      await controller.playQueue([_track(1), _track(2)], 0);
      engine.emitPosition(const Duration(milliseconds: 1000));
      await _settle();

      expect(controller.current?.id, 2);
      expect(engine.playedPaths, ['/tmp/1.mp3', '/tmp/2.mp3']);
    },
  );

  test('seek keeps the requested position when the engine succeeds', () async {
    final engine = _FakeAudioEngine();
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    await controller.playQueue([_track(1)], 0);
    await controller.seek(const Duration(milliseconds: 400));

    expect(engine.seekedPositions, [const Duration(milliseconds: 400)]);
    expect(controller.position, const Duration(milliseconds: 400));
  });

  test('seek reverts the optimistic position when the engine fails', () async {
    final engine = _FakeAudioEngine()..seekError = Exception('seek broke');
    final controller = PlayerController.forTest(engine: engine);
    addTearDown(controller.dispose);

    await controller.playQueue([_track(1)], 0);
    engine.emitPosition(const Duration(milliseconds: 200));

    await expectLater(
      controller.seek(const Duration(milliseconds: 500)),
      throwsA(isA<Exception>()),
    );
    expect(controller.position, const Duration(milliseconds: 200));
  });

  test(
    'stale stopped event after EOF advance does not stop next track',
    () async {
      final engine = _FakeAudioEngine();
      final controller = PlayerController.forTest(engine: engine);
      addTearDown(controller.dispose);

      await controller.playQueue([_track(1), _track(2)], 0);
      engine.emitPosition(const Duration(milliseconds: 1000));
      await _settle();

      expect(controller.current?.id, 2);
      expect(controller.playing, isTrue);

      engine.emitPlaying(false);
      await _settle();

      expect(controller.current?.id, 2);
      expect(controller.playing, isTrue);
      expect(engine.playedPaths, ['/tmp/1.mp3', '/tmp/2.mp3']);
    },
  );

  test(
    'position ticks update positionNotifier without notifying main listeners',
    () async {
      // Regression guard for the Overlay `_skipMarkNeedsLayout` crash: a
      // position tick must NOT fire the app-wide ChangeNotifier (which would
      // rebuild every tooltip/Slider OverlayPortal ~5x/s). Only the dedicated
      // positionNotifier may tick.
      final engine = _FakeAudioEngine();
      final controller = PlayerController.forTest(engine: engine);
      addTearDown(controller.dispose);

      await controller.playQueue([_track(1)], 0); // loads the engine
      var mainNotifies = 0;
      var posNotifies = 0;
      controller.addListener(() => mainNotifies++);
      controller.positionNotifier.addListener(() => posNotifies++);

      engine.emitPosition(const Duration(milliseconds: 300));
      await _settle();

      expect(controller.position, const Duration(milliseconds: 300));
      expect(posNotifies, 1, reason: 'scrubber must follow the tick');
      expect(mainNotifies, 0, reason: 'a tick must not rebuild the whole UI');
    },
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TrackRow _track(int id) => TrackRow(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  album: 'Album',
  durationMs: 1000,
  rating: 0,
  playedCount: 0,
  path: '/tmp/$id.mp3',
);

class _FakeAudioEngine implements AudioEngine {
  final _position = StreamController<Duration>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final List<String> playedPaths = [];
  final List<Duration> seekedPositions = [];
  Object? seekError;
  Duration _pos = Duration.zero;
  bool _isPlaying = false;

  void emitPosition(Duration position) {
    _pos = position;
    _position.add(position);
  }

  void emitPlaying(bool playing) {
    _isPlaying = playing;
    _playing.add(playing);
  }

  @override
  Future<void> playPath(String path, {Duration? duration}) async {
    playedPaths.add(path);
    _pos = Duration.zero;
    _isPlaying = true;
  }

  @override
  Future<void> playUrl(String url, {Duration? duration}) =>
      playPath(url, duration: duration);

  @override
  Future<void> pause() async => emitPlaying(false);

  @override
  Future<void> resume() async => emitPlaying(true);

  @override
  Future<void> stop() async => emitPlaying(false);

  @override
  Future<void> seek(Duration position) async {
    seekedPositions.add(position);
    final error = seekError;
    if (error != null) throw error;
    emitPosition(position);
  }

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setCrossfade(double secs) async {}

  @override
  Future<void> setEq(List<double> gains, double preampDb) async {}

  @override
  Future<void> setStereoWidth(double width) async {}

  @override
  Future<List<OutputDeviceRow>> outputDevices() async => const [
    OutputDeviceRow(id: 'default', name: 'Default', isDefault: true),
  ];

  @override
  Future<void> setOutputDevice(String? deviceId) async {}

  @override
  String? get lastError => null;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Duration get position => _pos;

  @override
  Duration get duration => const Duration(milliseconds: 1000);

  @override
  bool get playing => _isPlaying;

  @override
  Future<void> dispose() async {
    await _position.close();
    await _playing.close();
  }
}

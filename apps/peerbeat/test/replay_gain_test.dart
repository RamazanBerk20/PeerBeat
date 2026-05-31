import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/audio/replay_gain.dart';

void main() {
  group('replayGainFactor', () {
    test('off is always unity', () {
      expect(
        replayGainFactor(mode: ReplayGainMode.off, trackDb: -6, albumDb: -3),
        1.0,
      );
    });

    test('no gain data → unity', () {
      expect(replayGainFactor(mode: ReplayGainMode.track), 1.0);
    });

    test('-6 dB ≈ 0.501× (half power amplitude)', () {
      final f = replayGainFactor(mode: ReplayGainMode.track, trackDb: -6.0);
      expect(f, closeTo(0.501, 0.002));
    });

    test('0 dB is unity', () {
      expect(
        replayGainFactor(mode: ReplayGainMode.track, trackDb: 0),
        closeTo(1.0, 1e-9),
      );
    });

    test('track mode falls back to album gain when track gain is absent', () {
      final f = replayGainFactor(mode: ReplayGainMode.track, albumDb: 0);
      expect(f, closeTo(1.0, 1e-9));
    });

    test('album mode prefers album gain', () {
      final track = replayGainFactor(
        mode: ReplayGainMode.album,
        trackDb: -12,
        albumDb: 0,
      );
      expect(track, closeTo(1.0, 1e-9));
    });

    test('preamp adds to gain', () {
      final f = replayGainFactor(
        mode: ReplayGainMode.track,
        trackDb: -6,
        preampDb: 6,
      );
      expect(f, closeTo(1.0, 1e-9));
    });

    test('clamps extreme positive gain to 4×', () {
      final f = replayGainFactor(mode: ReplayGainMode.track, trackDb: 60);
      expect(f, 4.0);
    });
  });
}

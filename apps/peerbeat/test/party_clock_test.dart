import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/net/party.dart';

void main() {
  group('cristianSync', () {
    test('symmetric path → offset is the host-vs-local-midpoint delta', () {
      // Sent at local 1000, received at local 1100 (rtt 100). The host stamped
      // 5050 — i.e. the host clock is ~4000 ms ahead of ours.
      final s = cristianSync(1000, 5050, 1100);
      expect(s.rttMs, 100);
      expect(s.offsetMs, 4000); // 5050 - (1000+1100)/2
    });

    test(
      'rtt uses the single captured receive time, not a second clock read',
      () {
        // Regression guard for the bug where the offset used a *second* now()
        // read: with one t1 the rtt and offset are computed from the same instant.
        final s = cristianSync(2000, 2000, 2200);
        expect(s.rttMs, 200);
        expect(s.offsetMs, -100); // 2000 - (2000+2200)/2 = 2000 - 2100
      },
    );

    test('zero round-trip → offset is host minus send time', () {
      final s = cristianSync(500, 900, 500);
      expect(s.rttMs, 0);
      expect(s.offsetMs, 400);
    });
  });
}

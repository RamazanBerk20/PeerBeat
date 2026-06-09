import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/update/updater.dart';

void main() {
  group('compareVersions', () {
    test('orders release numbers', () {
      expect(compareVersions('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersions('0.3.0', '1.0.0'), lessThan(0));
      expect(compareVersions('1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0)); // not lexical
    });

    test('prerelease ranks below its release', () {
      expect(compareVersions('1.0.0-rc.1', '1.0.0'), lessThan(0));
      expect(compareVersions('1.0.0', '1.0.0-rc.1'), greaterThan(0));
      expect(compareVersions('1.0.0-rc.2', '1.0.0-rc.1'), greaterThan(0));
      expect(compareVersions('1.0.0-rc.1', '1.0.0-rc.1'), 0);
    });

    test(
      'a newer release outranks the current rc (drives the update prompt)',
      () {
        // Running 1.0.0-rc.1; a 1.0.0 release should be offered.
        expect(compareVersions('1.0.0', '1.0.0-rc.1'), greaterThan(0));
        // Running 1.0.0; an older 0.3.0 must NOT be offered.
        expect(compareVersions('0.3.0', '1.0.0'), lessThan(0));
      },
    );

    test('tolerates differing segment counts', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0.1', '1.0.0'), greaterThan(0));
    });
  });
}

import 'package:flutter/foundation.dart';

/// Lightweight error sink for best-effort operations.
///
/// Many paths (tray/MPRIS updates, cache cleanup, network teardown) are
/// intentionally non-fatal — a failure should not crash or interrupt playback.
/// But swallowing them *silently* makes field issues invisible. Routing them
/// here keeps the best-effort behaviour while surfacing a tagged line in debug
/// builds; in release it is a no-op.
void logErr(String tag, Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('[PeerBeat:$tag] $error');
  }
}

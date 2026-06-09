package io.github.ramazanberk20.peerbeat

import com.ryanheise.audioservice.AudioServiceActivity

// Must extend AudioServiceActivity (not FlutterActivity) so just_audio_background
// / audio_service can bind its foreground media service to this engine —
// otherwise the first playback throws LateInitializationError(_audioHandler).
class MainActivity : AudioServiceActivity()

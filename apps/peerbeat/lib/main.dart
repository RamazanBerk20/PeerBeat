import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_config.dart';
import 'os/os_media_controller.dart';
import 'playback/player.dart';
import 'src/rust/api/library.dart';
import 'src/rust/frb_generated.dart';
import 'ui/library_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    final dir = await getApplicationSupportDirectory();
    appDbPath = '${dir.path}${Platform.pathSeparator}library.db';
    appDisplayName = _deviceName();
    await libraryOpen(dbPath: appDbPath);
    await player.loadAudioSettings(); // ReplayGain mode/preamp
    await player.restoreSession(); // best-effort: restore last track + position
    await osMedia.start(); // best-effort: MPRIS media-key/lockscreen on Linux
  } catch (e, st) {
    debugPrintStack(label: 'PeerBeat startup failed', stackTrace: st);
    runApp(_StartupErrorApp(error: '$e'));
    return;
  }
  runApp(const PeerBeatApp());
}

/// Shown if the native core or database fail to initialise.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: PeerBeatApp._seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('PeerBeat failed to start'),
                const SizedBox(height: 8),
                SelectableText(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _deviceName() {
  try {
    final h = Platform.localHostname;
    return h.isEmpty ? 'PeerBeat' : h;
  } catch (_) {
    return 'PeerBeat';
  }
}

class PeerBeatApp extends StatefulWidget {
  const PeerBeatApp({super.key});

  static const _seed = Color(0xFF2BD9C6); // neon teal from the PeerBeat icon

  @override
  State<PeerBeatApp> createState() => _PeerBeatAppState();
}

class _PeerBeatAppState extends State<PeerBeatApp> {
  late final AppLifecycleListener _lifecycle;
  bool _cleaned = false;

  @override
  void initState() {
    super.initState();
    // Release the OS media controller (D-Bus connection + player listener) and
    // the audio engine on shutdown so nothing is left dangling on quit.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        await _cleanup();
        return AppExitResponse.exit;
      },
      onDetach: _cleanup,
    );
  }

  Future<void> _cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    try {
      await osMedia.dispose();
    } catch (_) {}
    try {
      player.dispose(); // ChangeNotifier.dispose is synchronous (returns void)
    } catch (_) {}
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme(Brightness b) =>
        ColorScheme.fromSeed(seedColor: PeerBeatApp._seed, brightness: b);
    return MaterialApp(
      title: 'PeerBeat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme(Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: scheme(Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const LibraryHome(),
    );
  }
}

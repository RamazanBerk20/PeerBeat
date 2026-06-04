import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_config.dart';
import 'os/desktop_shell.dart';
import 'os/os_media_controller.dart';
import 'playback/player.dart';
import 'src/rust/api/library.dart';
import 'src/rust/frb_generated.dart';
import 'ui/library_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DesktopShell.isDesktop) {
    try {
      await windowManager.ensureInitialized();
    } catch (_) {}
  }
  try {
    await RustLib.init();
    final dir = await getApplicationSupportDirectory();
    appDbPath = '${dir.path}${Platform.pathSeparator}library.db';
    appDisplayName = _deviceName();
    await libraryOpen(dbPath: appDbPath);
    await player.loadAudioSettings(); // ReplayGain mode/preamp
    await player.restoreSession(); // best-effort: restore last track + position
    await osMedia.start(); // best-effort: MPRIS media-key/lockscreen on Linux
    try {
      await libraryStartWatching(); // best-effort: auto-import on folder changes
    } catch (_) {}
    try {
      await desktopShell.start(); // best-effort: system tray + close-to-tray
    } catch (_) {}
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
    try {
      await desktopShell.dispose();
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
      builder: (context, child) =>
          _GlobalPlaybackShortcuts(child: child ?? const SizedBox.shrink()),
      home: const LibraryHome(),
    );
  }
}

/// App-wide desktop keyboard shortcuts for playback. Wrapped via MaterialApp's
/// builder so they work on every route. Keys consumed by a focused text field
/// (typing, cursor movement) or button (space/enter) take precedence, so these
/// don't interfere with editing.
class _GlobalPlaybackShortcuts extends StatelessWidget {
  const _GlobalPlaybackShortcuts({required this.child});
  final Widget child;

  void _seekBy(Duration delta) {
    final p = player.position + delta;
    player.seek(p < Duration.zero ? Duration.zero : p);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): player.toggle,
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(const Duration(seconds: 5)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(const Duration(seconds: -5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): () =>
            player.next(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): () =>
            player.previous(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            player.setVolume((player.volume + 0.05).clamp(0.0, 1.0)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            player.setVolume((player.volume - 0.05).clamp(0.0, 1.0)),
        const SingleActivator(LogicalKeyboardKey.keyM): player.toggleMute,
        const SingleActivator(LogicalKeyboardKey.keyS): () =>
            player.setShuffle(!player.shuffle),
        const SingleActivator(LogicalKeyboardKey.keyR): player.cycleRepeat,
      },
      // CallbackShortcuts already provides its own (non-focusable) Focus that
      // catches key events bubbling from the focused route, so no extra Focus is
      // needed here. A wrapping Focus(autofocus: true) re-requested focus on every
      // MaterialApp rebuild (e.g. dynamic-theme changes), which collided with
      // route/overlay layout and tripped an overlay assertion.
      child: child,
    );
  }
}

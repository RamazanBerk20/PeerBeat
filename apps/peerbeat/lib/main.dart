import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_config.dart';
import 'l10n/app_localizations.dart';
import 'os/audio_handler.dart';
import 'os/desktop_shell.dart';
import 'os/os_media_controller.dart';
import 'playback/player.dart';
import 'src/rust/api/library.dart';
import 'src/rust/frb_generated.dart';
import 'ui/library_home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    // Media session + foreground service for lockscreen/notification controls
    // and background playback. Our custom handler exposes exactly
    // previous · play/pause · next (no stop) and drives the app player.
    try {
      await AudioService.init(
        builder: () => PeerBeatAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'io.github.ramazanberk20.peerbeat.audio',
          androidNotificationChannelName: 'PeerBeat playback',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'drawable/ic_notification',
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (_) {}
  }
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
    // Extract the bundled icon to a file so the media session can use it as the
    // artwork fallback for tracks with no embedded cover (esp. on Android).
    try {
      final iconData = await rootBundle.load('assets/icon/app_icon.png');
      final iconFile = File('${dir.path}${Platform.pathSeparator}app_icon.png');
      await iconFile.writeAsBytes(iconData.buffer.asUint8List(), flush: true);
      appIconPath = iconFile.path;
    } catch (_) {}
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
      darkTheme: peerBeatTheme(Brightness.dark),
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
    // Rebuild the app theme only when the accent, theme mode, or chosen seed
    // changes (track / settings cadence) — MaterialApp animates the new
    // ColorScheme via its internal AnimatedTheme, so this never rebuilds on the
    // position tick.
    return ListenableBuilder(
      listenable: Listenable.merge([
        player.accentColor,
        player.themeMode,
        player.accentSeed,
        player.locale,
      ]),
      builder: (context, _) {
        // Album-art accent (when dynamic) wins; else the user's fixed accent;
        // else the built-in default.
        final seed =
            player.accentColor.value ?? player.accentSeed.value ?? kDefaultSeed;
        final mode = switch (player.themeMode.value) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        };
        return MaterialApp(
          title: 'PeerBeat',
          debugShowCheckedModeBanner: false,
          theme: peerBeatTheme(Brightness.light, seed: seed),
          darkTheme: peerBeatTheme(Brightness.dark, seed: seed),
          themeMode: mode,
          locale: player.locale.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) =>
              _GlobalPlaybackShortcuts(child: child ?? const SizedBox.shrink()),
          home: const LibraryHome(),
        );
      },
    );
  }
}

/// App-wide desktop keyboard shortcuts for playback. Wrapped via MaterialApp's
/// builder so they work on every route.
///
/// These bare keys (space, r, s, m, arrows) collide with text editing:
/// `CallbackShortcuts` sits *below* `DefaultTextEditingShortcuts` in the
/// WidgetsApp tree, so it would otherwise intercept the key before a focused
/// text field could type the character or move the cursor (the reason typing
/// "r"/"s"/"m"/space was impossible in search/name fields). So we watch the
/// focus and empty the bindings while a text field has focus, letting the key
/// fall through to the editor. The `CallbackShortcuts` element itself stays
/// mounted (only its bindings change) so the child route subtree is never
/// reparented.
class _GlobalPlaybackShortcuts extends StatefulWidget {
  const _GlobalPlaybackShortcuts({required this.child});
  final Widget child;

  @override
  State<_GlobalPlaybackShortcuts> createState() =>
      _GlobalPlaybackShortcutsState();
}

class _GlobalPlaybackShortcutsState extends State<_GlobalPlaybackShortcuts> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// True when a text field (EditableText) currently holds focus. EditableText
  /// attaches its focus node via a `Focus` widget inside its own subtree, so the
  /// primary focus node's context resolves an `EditableTextState` ancestor.
  bool get _editing {
    final ctx = FocusManager.instance.primaryFocus?.context;
    return ctx != null &&
        ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  void _seekBy(Duration delta) {
    final p = player.position + delta;
    player.seek(p < Duration.zero ? Duration.zero : p);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _editing
          ? const <ShortcutActivator, VoidCallback>{}
          : {
              const SingleActivator(LogicalKeyboardKey.space): player.toggle,
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _seekBy(const Duration(seconds: 5)),
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _seekBy(const Duration(seconds: -5)),
              const SingleActivator(
                LogicalKeyboardKey.arrowRight,
                control: true,
              ): () =>
                  player.next(),
              const SingleActivator(
                LogicalKeyboardKey.arrowLeft,
                control: true,
              ): () =>
                  player.previous(),
              const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                  player.setVolume((player.volume + 0.05).clamp(0.0, 1.0)),
              const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                  player.setVolume((player.volume - 0.05).clamp(0.0, 1.0)),
              const SingleActivator(LogicalKeyboardKey.keyM): player.toggleMute,
              const SingleActivator(LogicalKeyboardKey.keyS): () =>
                  player.setShuffle(!player.shuffle),
              const SingleActivator(LogicalKeyboardKey.keyR):
                  player.cycleRepeat,
              // Track navigation by letter (alongside Ctrl+←/→).
              const SingleActivator(LogicalKeyboardKey.keyN): () =>
                  player.next(),
              const SingleActivator(LogicalKeyboardKey.keyP): () =>
                  player.previous(),
              // Speed nudge (engine clamps to 0.5–2×).
              const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
                  player.setSpeed(player.speed + 0.25),
              const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
                  player.setSpeed(player.speed - 0.25),
            },
      child: widget.child,
    );
  }
}

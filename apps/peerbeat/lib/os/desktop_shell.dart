import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';
import '../playback/player.dart';

/// Desktop (Windows/Linux) system-tray + close-to-tray shell.
///
/// The close button hides the window to the tray instead of quitting; the tray
/// icon/menu restores it and offers quick playback controls. Close-to-tray is
/// only armed if the tray actually initialized, so a compositor without a tray
/// never strands the window hidden.
///
/// On Wayland the custom-positioned mini-player popup and sliding notification
/// the original spec describes can't be placed by the app (the compositor
/// decides window position), so those are deliberately omitted in favour of the
/// compositor-provided tray + the OS's own notifications.
class DesktopShell with TrayListener, WindowListener {
  bool _started = false;
  bool _trayOk = false;
  bool _quitting = false;
  String? _trayIconFile;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  static bool get isWayland =>
      Platform.isLinux &&
      (((Platform.environment['XDG_SESSION_TYPE'] ?? '').toLowerCase() ==
              'wayland') ||
          (Platform.environment['WAYLAND_DISPLAY'] ?? '').isNotEmpty);

  Future<void> start() async {
    if (_started || !isDesktop) return;
    _started = true;
    try {
      trayManager.addListener(this);
      // Icon is best-effort: a missing icon must not disable close-to-tray (the
      // desktop shows a placeholder and the menu still restores the window).
      try {
        await trayManager.setIcon(await _trayIconPath());
      } catch (_) {}
      try {
        await trayManager.setToolTip('PeerBeat');
      } catch (_) {}
      await trayManager.setContextMenu(_menu(await _l10n()));
      _trayOk = true;
    } catch (_) {
      _trayOk = false;
    }
    if (_trayOk) {
      try {
        windowManager.addListener(this);
        await windowManager.setPreventClose(true);
        player.addListener(_onPlayerChanged);
      } catch (_) {}
    }
  }

  /// Extract the bundled tray icon to a real file path (appindicator needs one,
  /// not a bundle-relative asset key).
  Future<String> _trayIconPath() async {
    final data = await rootBundle.load('assets/icon/app_icon.png');
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/peerbeat_tray.png');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    _trayIconFile = f.path;
    return f.path;
  }

  /// Remove the extracted tray icon so it doesn't linger in the temp dir.
  Future<void> _cleanupTrayIcon() async {
    final path = _trayIconFile;
    _trayIconFile = null;
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Menu _menu(AppLocalizations l10n) => Menu(
    items: [
      MenuItem(
        key: 'playpause',
        label: player.playing ? l10n.pause : l10n.commonPlay,
      ),
      // Mirror the in-app transport: Next/Previous are disabled when the queue
      // has nowhere to go (otherwise Next looks broken at the end of the queue).
      MenuItem(key: 'next', label: l10n.commonNext, disabled: !player.hasNext),
      MenuItem(
        key: 'prev',
        label: l10n.commonPrevious,
        disabled: !player.hasPrevious,
      ),
      MenuItem.separator(),
      MenuItem(key: 'show', label: l10n.trayShow),
      MenuItem(key: 'quit', label: l10n.trayQuit),
    ],
  );

  /// Resolve [AppLocalizations] without a [BuildContext] (the tray runs outside
  /// the widget tree): use the user-chosen locale, else the system locale
  /// matched against the supported set, else English. The generated delegate
  /// loads synchronously, so the await completes immediately.
  Future<AppLocalizations> _l10n() {
    final chosen = player.locale.value;
    final locale = chosen ?? _systemLocale();
    return AppLocalizations.delegate.load(locale);
  }

  Locale _systemLocale() {
    final sys = PlatformDispatcher.instance.locale;
    return AppLocalizations.supportedLocales.firstWhere(
      (l) => l.languageCode == sys.languageCode,
      orElse: () => const Locale('en'),
    );
  }

  void _onPlayerChanged() => unawaited(_rebuildMenu());

  Future<void> _rebuildMenu() async {
    try {
      await trayManager.setContextMenu(_menu(await _l10n()));
    } catch (_) {}
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _quit() async {
    _quitting = true;
    await _cleanupTrayIcon();
    try {
      await trayManager.destroy();
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } catch (_) {}
  }

  // ── WindowListener ──────────────────────────────────────────────────────────
  @override
  void onWindowClose() {
    if (_quitting) return;
    unawaited(windowManager.hide()); // close → hide to tray
  }

  // ── TrayListener ────────────────────────────────────────────────────────────
  @override
  void onTrayIconMouseDown() => unawaited(_showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'playpause':
        player.toggle();
      case 'next':
        unawaited(player.next());
      case 'prev':
        unawaited(player.previous());
      case 'show':
        unawaited(_showWindow());
      case 'quit':
        unawaited(_quit());
    }
  }

  Future<void> dispose() async {
    if (!_started) return;
    try {
      player.removeListener(_onPlayerChanged);
    } catch (_) {}
    try {
      windowManager.removeListener(this);
    } catch (_) {}
    try {
      trayManager.removeListener(this);
    } catch (_) {}
    await _cleanupTrayIcon();
  }
}

/// Process-wide desktop shell.
final DesktopShell desktopShell = DesktopShell();

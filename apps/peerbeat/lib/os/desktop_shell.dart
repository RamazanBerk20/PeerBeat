import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

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
    // Bring up the tray first; only arm close-to-tray if it succeeded.
    try {
      trayManager.addListener(this);
      await trayManager.setIcon('assets/icon/app_icon.png');
      await trayManager.setToolTip('PeerBeat');
      await _rebuildMenu();
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

  void _onPlayerChanged() => unawaited(_rebuildMenu());

  Future<void> _rebuildMenu() async {
    try {
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'playpause', label: player.playing ? 'Pause' : 'Play'),
            MenuItem(key: 'next', label: 'Next'),
            MenuItem(key: 'prev', label: 'Previous'),
            MenuItem.separator(),
            MenuItem(key: 'show', label: 'Show PeerBeat'),
            MenuItem(key: 'quit', label: 'Quit'),
          ],
        ),
      );
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
  }
}

/// Process-wide desktop shell.
final DesktopShell desktopShell = DesktopShell();

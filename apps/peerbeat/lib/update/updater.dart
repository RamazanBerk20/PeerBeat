/// In-app update checker for the platforms that are *not* package-managed.
///
/// Linux ships through AUR / `.deb` / AppImage, so its package manager owns
/// updates and this controller stays inert there. Windows + Android are
/// side-loaded from GitHub Releases, so they poll the Releases API, download the
/// matching asset, and hand it to the OS installer (Inno `.exe` with UAC on
/// Windows; the package-installer intent on Android). The OS always asks the
/// user to confirm — nothing installs silently.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MethodChannel, MissingPluginException, PlatformException;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../src/rust/api/library.dart' show settingsGet, settingsSet;

const _repo = 'RamazanBerk20/PeerBeat';
const _kAutoCheck = 'update_auto_check';
const _kLastCheck = 'update_last_check';
const _kSkipVersion = 'update_skip_version';

/// Re-check at most once a day on launch.
const _throttle = Duration(hours: 24);

const _installer = MethodChannel('peerbeat/installer');

/// A release newer than the running build, with the asset for this platform.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.assetUrl,
    required this.assetName,
    required this.sizeBytes,
  });

  /// Release version, without a leading `v` (e.g. `1.0.0-rc.1`).
  final String version;
  final String notes;
  final String assetUrl;
  final String assetName;
  final int sizeBytes;
}

class UpdateController {
  UpdateController._();
  static final UpdateController instance = UpdateController._();

  /// Set when an applicable update is found; the home screen watches this to
  /// show its banner. Null = nothing to offer.
  final ValueNotifier<UpdateInfo?> available = ValueNotifier(null);

  /// Whether this platform self-updates at all. Linux is package-managed.
  bool get supported => Platform.isWindows || Platform.isAndroid;

  Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<bool> autoCheckEnabled() async =>
      (await settingsGet(key: _kAutoCheck)) != '0'; // default on

  Future<void> setAutoCheck(bool on) =>
      settingsSet(key: _kAutoCheck, value: on ? '1' : '0');

  /// Throttled launch check. Best-effort: any failure leaves [available] null.
  Future<void> maybeCheckOnLaunch() async {
    if (!supported) return;
    if (!await autoCheckEnabled()) return;
    final last = int.tryParse(await settingsGet(key: _kLastCheck) ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _throttle.inMilliseconds) return;
    await settingsSet(key: _kLastCheck, value: '$now');
    try {
      final info = await check();
      if (info == null) return;
      if ((await settingsGet(key: _kSkipVersion)) == info.version) return;
      available.value = info;
    } catch (_) {
      // Offline / API error — silent; the manual button surfaces errors.
    }
  }

  /// Query GitHub Releases for the latest version and pick this platform's
  /// asset. Returns null if up-to-date or unsupported. Throws on network error
  /// (the manual "Check for updates" path reports it).
  Future<UpdateInfo?> check() async {
    if (!supported) return null;
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('GitHub API returned ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').replaceFirst(
      RegExp('^v'),
      '',
    );
    if (tag.isEmpty) return null;
    final current = await currentVersion();
    if (compareVersions(tag, current) <= 0) return null; // not newer

    final assets = (json['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final wanted = await _assetNameFor();
    final match = _pickAsset(assets, wanted);
    if (match == null) return null; // release has no asset for this platform
    return UpdateInfo(
      version: tag,
      notes: (json['body'] as String? ?? '').trim(),
      assetUrl: match['browser_download_url'] as String,
      assetName: match['name'] as String,
      sizeBytes: (match['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Resolve the release asset name pattern for the current platform/ABI.
  Future<RegExp> _assetNameFor() async {
    if (Platform.isWindows) {
      return RegExp(r'^PeerBeat-Setup-.*\.exe$', caseSensitive: false);
    }
    // Android: split-per-abi APK. Match the device's primary ABI, default arm64.
    final abi = await _primaryAbi();
    final suffix = switch (abi) {
      'arm64-v8a' => 'arm64-v8a',
      'armeabi-v7a' => 'armeabi-v7a',
      'x86_64' => 'x86_64',
      _ => 'arm64-v8a',
    };
    return RegExp('app-$suffix-release\\.apk\$', caseSensitive: false);
  }

  Future<String> _primaryAbi() async {
    try {
      final abi = await _installer.invokeMethod<String>('getAbi');
      if (abi != null && abi.isNotEmpty) return abi;
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
    return 'arm64-v8a';
  }

  Map<String, dynamic>? _pickAsset(
    List<Map<String, dynamic>> assets,
    RegExp pattern,
  ) {
    for (final a in assets) {
      final name = a['name'] as String? ?? '';
      if (pattern.hasMatch(name)) return a;
    }
    return null;
  }

  /// Download [info]'s asset to a temp file, reporting 0..1 progress.
  Future<File> download(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}${info.assetName}');
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.assetUrl));
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw HttpException('Download failed (${resp.statusCode})');
      }
      final total = resp.contentLength ?? info.sizeBytes;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in resp.stream) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
        }
      } finally {
        await sink.close();
      }
      if (info.sizeBytes > 0 && await file.length() != info.sizeBytes) {
        throw const HttpException('Downloaded size mismatch');
      }
      onProgress(1.0);
      return file;
    } finally {
      client.close();
    }
  }

  /// Hand the downloaded asset to the OS installer. On Windows the app exits so
  /// the Inno installer can replace it in place; on Android the system package
  /// installer takes over (the user confirms).
  Future<void> install(File file) async {
    if (Platform.isWindows) {
      await Process.start(file.path, const [], mode: ProcessStartMode.detached);
      // Give the installer a moment to spawn, then quit so files aren't locked.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      exit(0);
    } else if (Platform.isAndroid) {
      await _installer.invokeMethod('installApk', {'path': file.path});
    }
  }

  Future<void> skip(String version) =>
      settingsSet(key: _kSkipVersion, value: version);

  /// Clear the banner without recording a skip (the "Later" action).
  void dismiss() => available.value = null;
}

/// Compare two dot-separated version strings, treating a `-prerelease` suffix as
/// lower than the same release (SemVer ordering: `1.0.0-rc.1` < `1.0.0`).
/// Returns <0 if [a] < [b], 0 if equal, >0 if [a] > [b].
@visibleForTesting
int compareVersions(String a, String b) {
  (List<int>, List<String>) parse(String v) {
    final dash = v.indexOf('-');
    final core = dash >= 0 ? v.substring(0, dash) : v;
    final pre = dash >= 0 ? v.substring(dash + 1) : '';
    final nums = core
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final preParts = pre.isEmpty ? <String>[] : pre.split('.');
    return (nums, preParts);
  }

  final (an, ap) = parse(a);
  final (bn, bp) = parse(b);
  for (var i = 0; i < (an.length > bn.length ? an.length : bn.length); i++) {
    final av = i < an.length ? an[i] : 0;
    final bv = i < bn.length ? bn[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  // Equal cores: no prerelease outranks any prerelease.
  if (ap.isEmpty && bp.isEmpty) return 0;
  if (ap.isEmpty) return 1; // a is the full release
  if (bp.isEmpty) return -1; // b is the full release
  for (var i = 0; i < (ap.length > bp.length ? ap.length : bp.length); i++) {
    final av = i < ap.length ? ap[i] : '';
    final bv = i < bp.length ? bp[i] : '';
    if (av == bv) continue;
    final an2 = int.tryParse(av);
    final bn2 = int.tryParse(bv);
    if (an2 != null && bn2 != null) return an2.compareTo(bn2);
    return av.compareTo(bv); // lexical fallback
  }
  return 0;
}

/// Singleton, mirroring `player` / `osMedia`.
final updater = UpdateController.instance;

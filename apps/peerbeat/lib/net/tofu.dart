import 'dart:io';

import 'package:crypto/crypto.dart';

import '../src/rust/api/library.dart' as lib;

/// Hex SHA-256 of [bytes] — matches the Rust host fingerprint format.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

class _Holder {
  String? value;
}

/// An `HttpClient` that trusts a LAN host's self-signed certificate under TOFU:
/// the first connection for [hostKey] pins the live cert fingerprint; later
/// connections must present the same one, else the request fails (possible
/// MITM). Call [confirmPin] only after a request succeeds.
class TofuHostClient {
  TofuHostClient._(
    this.client,
    this._hostKey,
    this._name,
    this._seen,
    this.firstUse,
  );

  final HttpClient client;
  final String _hostKey;
  final String _name;
  final _Holder _seen;

  /// True when no pin existed yet (this connection is establishing trust).
  final bool firstUse;

  static Future<TofuHostClient> forHost(String hostKey, String name) async {
    final expected = await lib.netKnownHostFingerprint(hostId: hostKey);
    final seen = _Holder();
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          final fp = sha256Hex(cert.der);
          if (expected == null) {
            seen.value =
                fp; // remember after the request verifies the connection
            return true;
          }
          return fp == expected;
        };
    return TofuHostClient._(client, hostKey, name, seen, expected == null);
  }

  /// Persist the first-use pin (call after a successful request).
  Future<void> confirmPin() async {
    if (firstUse && _seen.value != null) {
      await lib.netRememberHost(
        hostId: _hostKey,
        name: _name,
        fingerprint: _seen.value!,
      );
    }
  }

  void close() => client.close();
}

/// An `HttpClient` for streaming, which only has a URL (no host id): it accepts
/// a self-signed cert iff its fingerprint belongs to an already-pinned host.
Future<HttpClient> tofuStreamClient() async {
  final known = (await lib.netKnownFingerprints()).toSet();
  final client = HttpClient();
  client.badCertificateCallback =
      (X509Certificate cert, String host, int port) =>
          known.contains(sha256Hex(cert.der));
  return client;
}

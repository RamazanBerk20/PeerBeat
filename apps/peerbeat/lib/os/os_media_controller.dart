import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../playback/player.dart';
import '../src/rust/db/tracks.dart';

/// Bridges the [player] to the OS media controls (lockscreen/media-keys).
/// Linux uses MPRIS over D-Bus; other desktops/Android are no-ops here
/// (Android playback controls come from just_audio's own session).
abstract class OsMediaController {
  factory OsMediaController.forPlatform() {
    if (Platform.isLinux) return MprisController();
    return _NoopOsMediaController();
  }

  /// Register with the OS. Best-effort: failures must not crash the app.
  Future<void> start();
  Future<void> dispose();
}

/// Process-wide controller (one audio session).
final OsMediaController osMedia = OsMediaController.forPlatform();

class _NoopOsMediaController implements OsMediaController {
  @override
  Future<void> start() async {}
  @override
  Future<void> dispose() async {}
}

const _mp2 = 'org.mpris.MediaPlayer2';
const _player = 'org.mpris.MediaPlayer2.Player';

/// Exposes PeerBeat as an MPRIS player so desktops can drive it via media
/// keys / the lockscreen, and show now-playing info.
class MprisController implements OsMediaController {
  DBusClient? _client;
  _MprisObject? _object;

  // Last-emitted snapshot, so we only signal PropertiesChanged on real changes
  // (the player notifies on every position tick).
  String _lastStatus = '';
  int _lastTrackId = -1;
  bool _lastShuffle = false;
  RepeatMode _lastRepeat = RepeatMode.off;

  @override
  Future<void> start() async {
    try {
      final client = DBusClient.session();
      // Register the object *before* claiming the name so a desktop that reacts
      // to the name appearing can introspect /org/mpris/MediaPlayer2 immediately.
      final object = _MprisObject();
      await client.registerObject(object);
      // Take the name even from a stale (hidden/close-to-tray) instance, and let
      // a future instance take it from us, so the *live* player is the one KDE
      // and GNOME show.
      final reply = await client.requestName(
        'org.mpris.MediaPlayer2.peerbeat',
        flags: {
          DBusRequestNameFlag.allowReplacement,
          DBusRequestNameFlag.replaceExisting,
        },
      );
      if (reply == DBusRequestNameReply.exists ||
          reply == DBusRequestNameReply.inQueue) {
        // A non-replaceable owner holds the name — don't shadow it.
        await client.close();
        return;
      }
      _client = client;
      _object = object;
      player.addListener(_onPlayerChanged);
      _onPlayerChanged(); // push initial state
    } catch (e) {
      // No session bus (headless/CI) or registration failed — degrade silently,
      // and make sure a listener added before the failure doesn't leak.
      debugPrint('MPRIS unavailable: $e');
      player.removeListener(_onPlayerChanged);
      _client = null;
      _object = null;
    }
  }

  void _onPlayerChanged() {
    final obj = _object;
    if (obj == null) return;
    final t = player.current;
    final status = t == null
        ? 'Stopped'
        : (player.playing ? 'Playing' : 'Paused');
    final trackId = t?.id ?? -1;

    final changed = <String, DBusValue>{};
    if (status != _lastStatus) {
      _lastStatus = status;
      changed['PlaybackStatus'] = DBusString(status);
    }
    if (trackId != _lastTrackId) {
      _lastTrackId = trackId;
      changed['Metadata'] = mprisMetadata(t);
    }
    if (player.shuffle != _lastShuffle) {
      _lastShuffle = player.shuffle;
      changed['Shuffle'] = DBusBoolean(player.shuffle);
    }
    if (player.repeat != _lastRepeat) {
      _lastRepeat = player.repeat;
      changed['LoopStatus'] = DBusString(loopStatusFor(player.repeat));
    }
    if (changed.isNotEmpty) {
      // Capabilities can shift with the queue/repeat; refresh alongside.
      changed['CanGoNext'] = DBusBoolean(player.hasNext);
      changed['CanGoPrevious'] = DBusBoolean(player.hasPrevious);
      changed['CanPlay'] = DBusBoolean(t != null);
      changed['CanPause'] = DBusBoolean(t != null);
      obj.emitPropertiesChanged(_player, changedProperties: changed);
    }
  }

  @override
  Future<void> dispose() async {
    player.removeListener(_onPlayerChanged);
    final c = _client;
    _client = null;
    _object = null;
    if (c != null) await c.close();
  }
}

String loopStatusFor(RepeatMode m) => switch (m) {
  RepeatMode.off => 'None',
  RepeatMode.all => 'Playlist',
  RepeatMode.one => 'Track',
};

RepeatMode repeatFromLoopStatus(String s) => switch (s) {
  'Playlist' => RepeatMode.all,
  'Track' => RepeatMode.one,
  _ => RepeatMode.off,
};

/// Build the MPRIS `Metadata` dict (`a{sv}`) for [t].
DBusValue mprisMetadata(TrackRow? t) {
  if (t == null) return DBusDict.stringVariant({});
  final m = <String, DBusValue>{
    'mpris:trackid': DBusObjectPath('/org/peerbeat/track/${t.id}'),
    'mpris:length': DBusInt64(t.durationMs * 1000), // microseconds
    'xesam:title': DBusString(t.title.isEmpty ? 'Unknown' : t.title),
  };
  if (t.artist.isNotEmpty) m['xesam:artist'] = DBusArray.string([t.artist]);
  if (t.album.isNotEmpty) m['xesam:album'] = DBusString(t.album);
  final art = t.artPath;
  if (art != null && art.isNotEmpty) {
    m['mpris:artUrl'] = DBusString(Uri.file(art).toString());
  }
  return DBusDict.stringVariant(m);
}

/// The D-Bus object at `/org/mpris/MediaPlayer2` implementing the two MPRIS
/// interfaces. Methods/properties act on the global [player].
class _MprisObject extends DBusObject {
  _MprisObject() : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  @override
  List<DBusIntrospectInterface> introspect() {
    DBusIntrospectArgument arg(
      String sig,
      DBusArgumentDirection dir,
      String name,
    ) => DBusIntrospectArgument(DBusSignature(sig), dir, name: name);
    DBusIntrospectProperty prop(
      String name,
      String sig, {
      DBusPropertyAccess access = DBusPropertyAccess.read,
    }) => DBusIntrospectProperty(name, DBusSignature(sig), access: access);

    return [
      DBusIntrospectInterface(
        _mp2,
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: [
          prop('Identity', 's'),
          prop('DesktopEntry', 's'),
          prop('CanQuit', 'b'),
          prop('CanRaise', 'b'),
          prop('HasTrackList', 'b'),
          prop('SupportedUriSchemes', 'as'),
          prop('SupportedMimeTypes', 'as'),
        ],
      ),
      DBusIntrospectInterface(
        _player,
        methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod(
            'Seek',
            args: [arg('x', DBusArgumentDirection.in_, 'Offset')],
          ),
          DBusIntrospectMethod(
            'SetPosition',
            args: [
              arg('o', DBusArgumentDirection.in_, 'TrackId'),
              arg('x', DBusArgumentDirection.in_, 'Position'),
            ],
          ),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [arg('x', DBusArgumentDirection.out, 'Position')],
          ),
        ],
        properties: [
          prop('PlaybackStatus', 's'),
          prop('LoopStatus', 's', access: DBusPropertyAccess.readwrite),
          prop('Rate', 'd', access: DBusPropertyAccess.readwrite),
          prop('MinimumRate', 'd'),
          prop('MaximumRate', 'd'),
          prop('Shuffle', 'b', access: DBusPropertyAccess.readwrite),
          prop('Metadata', 'a{sv}'),
          prop('Volume', 'd', access: DBusPropertyAccess.readwrite),
          prop('Position', 'x'),
          prop('CanGoNext', 'b'),
          prop('CanGoPrevious', 'b'),
          prop('CanPlay', 'b'),
          prop('CanPause', 'b'),
          prop('CanSeek', 'b'),
          prop('CanControl', 'b'),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == _mp2) {
      switch (call.name) {
        case 'Raise':
        case 'Quit':
          return DBusMethodSuccessResponse();
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    if (call.interface == _player) {
      switch (call.name) {
        case 'PlayPause':
          player.toggle();
          return DBusMethodSuccessResponse();
        case 'Play':
          if (!player.playing) player.toggle();
          return DBusMethodSuccessResponse();
        case 'Pause':
        case 'Stop':
          if (player.playing) player.toggle();
          return DBusMethodSuccessResponse();
        case 'Next':
          unawaited(player.next());
          return DBusMethodSuccessResponse();
        case 'Previous':
          unawaited(player.previous());
          return DBusMethodSuccessResponse();
        case 'Seek':
          final offsetUs = (call.values.first as DBusInt64).value;
          final target = player.position + Duration(microseconds: offsetUs);
          unawaited(
            player.seek(target < Duration.zero ? Duration.zero : target),
          );
          return DBusMethodSuccessResponse();
        case 'SetPosition':
          final posUs = (call.values[1] as DBusInt64).value;
          unawaited(player.seek(Duration(microseconds: posUs)));
          return DBusMethodSuccessResponse();
      }
      return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final props = _propsFor(interface);
    final v = props[name];
    return v == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(v);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(_propsFor(interface));

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface != _player) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    switch (name) {
      case 'Volume':
        player.setVolume((value as DBusDouble).value);
        return DBusMethodSuccessResponse();
      case 'Rate':
        player.setSpeed((value as DBusDouble).value);
        return DBusMethodSuccessResponse();
      case 'Shuffle':
        player.setShuffle((value as DBusBoolean).value);
        return DBusMethodSuccessResponse();
      case 'LoopStatus':
        player.setRepeat(repeatFromLoopStatus((value as DBusString).value));
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownProperty();
  }

  Map<String, DBusValue> _propsFor(String interface) {
    if (interface == _mp2) {
      return {
        'Identity': DBusString('PeerBeat'),
        'DesktopEntry': DBusString('peerbeat'),
        'CanQuit': DBusBoolean(false),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'SupportedUriSchemes': DBusArray.string([]),
        'SupportedMimeTypes': DBusArray.string([]),
      };
    }
    if (interface == _player) {
      final t = player.current;
      final status = t == null
          ? 'Stopped'
          : (player.playing ? 'Playing' : 'Paused');
      return {
        'PlaybackStatus': DBusString(status),
        'LoopStatus': DBusString(loopStatusFor(player.repeat)),
        'Rate': DBusDouble(player.speed),
        'MinimumRate': DBusDouble(0.25),
        'MaximumRate': DBusDouble(4.0),
        'Shuffle': DBusBoolean(player.shuffle),
        'Metadata': mprisMetadata(t),
        'Volume': DBusDouble(player.muted ? 0.0 : player.volume),
        'Position': DBusInt64(player.position.inMicroseconds),
        'CanGoNext': DBusBoolean(player.hasNext),
        'CanGoPrevious': DBusBoolean(player.hasPrevious),
        'CanPlay': DBusBoolean(t != null),
        'CanPause': DBusBoolean(t != null),
        'CanSeek': DBusBoolean(true),
        'CanControl': DBusBoolean(true),
      };
    }
    return {};
  }
}

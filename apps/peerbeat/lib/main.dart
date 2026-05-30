import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/rust/api/library.dart';
import 'src/rust/frb_generated.dart';
import 'ui/library_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final dir = await getApplicationSupportDirectory();
  await libraryOpen(dbPath: '${dir.path}${Platform.pathSeparator}library.db');
  runApp(const PeerBeatApp());
}

class PeerBeatApp extends StatelessWidget {
  const PeerBeatApp({super.key});

  static const _seed = Color(0xFF2BD9C6); // neon teal from the PeerBeat icon

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme(Brightness b) =>
        ColorScheme.fromSeed(seedColor: _seed, brightness: b);
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

// Smoke test that does not touch the native Rust core (the core is exercised by
// `cargo test` and, end-to-end, by the build/run jobs).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material 3 theme + scaffold build', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF2BD9C6)),
          useMaterial3: true,
        ),
        home: const Scaffold(body: Center(child: Text('PeerBeat'))),
      ),
    );
    expect(find.text('PeerBeat'), findsOneWidget);
  });
}

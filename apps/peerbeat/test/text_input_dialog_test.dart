import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/l10n/app_localizations.dart';
import 'package:peerbeat/ui/text_input_dialog.dart';

void main() {
  testWidgets(
    'promptText returns the entered value and survives the dismiss transition',
    (tester) async {
      // Regression guard: the old inline dialogs disposed their controller in a
      // `finally` right after the dialog popped, so the TextField rebuilding
      // during the dismiss transition touched a disposed controller and crashed.
      // pumpAndSettle() below runs that exit transition.
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      String? result;
      final future = promptText(
        pageContext,
        title: 'Enter PIN',
        confirmLabel: 'Connect',
      ).then((v) => result = v);
      await tester.pumpAndSettle(); // dialog enter transition

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Connect'));
      await tester
          .pumpAndSettle(); // dialog EXIT transition — used to crash here
      await future;

      expect(result, '1234');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('promptText returns null when cancelled', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    String? result = 'sentinel';
    final future = promptText(
      pageContext,
      title: 'Name',
    ).then((v) => result = v);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await future;

    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}

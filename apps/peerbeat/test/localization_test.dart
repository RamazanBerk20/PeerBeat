import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peerbeat/l10n/app_localizations.dart';

void main() {
  testWidgets('every supported locale resolves strings without crashing', (
    tester,
  ) async {
    expect(AppLocalizations.supportedLocales.length, 10);

    for (final locale in AppLocalizations.supportedLocales) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              // Exercise a spread of keys incl. plurals + placeholders so a
              // malformed ICU message in any locale throws here. Scrollable so
              // the test surface can't overflow on long translations.
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text(l10n.nowPlayingTitle),
                    Text(l10n.trackCount(1)),
                    Text(l10n.trackCount(5)),
                    Text(l10n.scanSummary(1, 2, 3, 0)),
                    Text(l10n.updateAvailable('1.0.0')),
                    Text(l10n.sharingOnPort('54213', 'host')),
                    Text(l10n.matchesCount(3)),
                    Text(l10n.peerWantsToConnect('Phone', 'Library')),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'locale ${locale.languageCode}',
      );
      expect(l10n.commonSave, isNotEmpty);
    }
  });

  testWidgets('Arabic resolves to a right-to-left layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Text(
            Directionality.of(context).name,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('rtl'), findsOneWidget);
  });
}

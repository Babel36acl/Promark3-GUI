import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import '../support/localized_test_app.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('DESFire uses an applications noun in $language',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final localizations = lookupAppLocalizations(Locale(language));
      final applications = language == 'en' ? 'Applications' : '应用';
      final apply = language == 'en' ? 'Apply' : '应用';
      await tester.pumpWidget(LocalizedTestApp(
        locale: Locale(language),
        home: const Scaffold(body: HfMfdesPage()),
      ));
      await tester.pumpAndSettle();

      final tab = find.descendant(
        of: find.byType(TabBar),
        matching: find.text(applications),
      );
      expect(tab, findsOneWidget);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.text(localizations.messageListApplications), findsOneWidget);
      expect(localizations.messageApply, apply);
      expect(tester.takeException(), isNull);
    });
  }
}

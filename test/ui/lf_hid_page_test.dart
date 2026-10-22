import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';
import '../support/localized_test_app.dart';

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('HID reader brute-force labels are distinct in $language',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(LocalizedTestApp(
        locale: Locale(language),
        home: const Scaffold(body: LfHidPage()),
      ));
      await tester.pumpAndSettle();

      final tabLabel = language == 'en' ? 'Reader brute-force' : '读卡器暴力枚举';
      final title = language == 'en'
          ? 'Brute-force facility codes / card numbers'
          : '枚举设施码 / 卡号';
      final start = language == 'en' ? 'Start brute-force' : '开始暴力枚举';
      await tester.tap(find.descendant(
        of: find.byType(TabBar),
        matching: find.text(tabLabel),
      ));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text(start), findsOneWidget);
      expect(find.text('Key recovery'), findsNothing);
      expect(find.text('Brute-force recovery'), findsNothing);
      expect(find.text('Start recovery'), findsNothing);
      expect(lookupAppLocalizations(Locale(language)).messageKeyRecovery,
          language == 'en' ? 'Key recovery' : '破解');
      await tester.enterText(find.byType(TextFormField), '123');

      final otherLanguage = language == 'en' ? 'zh' : 'en';
      final otherL10n = lookupAppLocalizations(Locale(otherLanguage));
      await tester.pumpWidget(LocalizedTestApp(
        locale: Locale(otherLanguage),
        home: const Scaffold(body: LfHidPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text(otherL10n.hidReaderBruteForceTitle), findsOneWidget);
      expect(find.text(otherL10n.hidStartBruteForce), findsOneWidget);
      expect(find.text('123'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('HID brute-force command syntax is unchanged', () {
    expect(LfHidCmd.brute(), 'lf hid brute');
    expect(LfHidCmd.brute(fc: '123'), 'lf hid brute --fc 123');
  });
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/l10n/app_locale_controller.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/services/locale_settings_store.dart';

class MemoryLocaleSettings implements LocaleSettingsRepository {
  MemoryLocaleSettings([this.language]);
  String? language;

  @override
  Future<String?> load() async => language;
  @override
  Future<void> save(String? languageCode) async => language = languageCode;
}

class LocalizedTestApp extends StatelessWidget {
  const LocalizedTestApp({
    super.key,
    required this.home,
    this.locale = const Locale('zh'),
  });

  final Widget home;
  final Locale locale;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => AppLocaleController(repository: MemoryLocaleSettings()),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );
}

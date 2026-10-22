import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

final AppLocalizations defaultLocalizations =
    lookupAppLocalizations(const Locale('zh'));

mixin LocalizedMessages {
  AppLocalizations l10n = defaultLocalizations;

  void updateLocalizations(AppLocalizations value) {
    l10n = value;
  }
}

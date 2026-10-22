import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pm3gui/services/locale_settings_store.dart';
import 'app_localizations.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({LocaleSettingsRepository? repository})
      : _repository = repository ?? LocaleSettingsStore();

  final LocaleSettingsRepository _repository;
  Locale? _locale;
  Object? _error;
  bool _changed = false;
  bool _disposed = false;
  int _pendingSaves = 0;
  Future<void>? _initialization;
  Future<void> _queue = Future.value();

  Locale? get locale => _locale;
  Object? get error => _error;
  bool get isSaving => _pendingSaves > 0;

  Future<void> initialize() => _initialization ??= _restore();

  Future<void> _restore() async {
    try {
      final languageCode = await _repository.load();
      if (languageCode != null &&
          !AppLocalizations.supportedLocales
              .any((locale) => locale.languageCode == languageCode)) {
        throw FormatException('Unsupported saved language: $languageCode');
      }
      if (!_changed) {
        _locale = languageCode == null ? null : Locale(languageCode);
      }
    } on FileSystemException catch (error) {
      _error = error;
    } on FormatException catch (error) {
      _error = error;
    }
    _notify();
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale != null && !AppLocalizations.supportedLocales.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported app locale');
    }
    _changed = true;
    _locale = locale;
    _error = null;
    _pendingSaves++;
    _notify();
    final previous = _queue;
    final saving = () async {
      await previous;
      await initialize();
      try {
        await _repository.save(locale?.languageCode);
        _error = null;
      } on FileSystemException catch (error) {
        _error = error;
      } finally {
        _pendingSaves--;
        _notify();
      }
    }();
    _queue = saving;
    await saving;
  }

  Future<void> flush() async {
    await initialize();
    while (true) {
      final pending = _queue;
      await pending;
      if (identical(pending, _queue)) return;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

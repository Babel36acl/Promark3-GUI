import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/backend/mock/mock_pm3_backend.dart';
import 'package:pm3gui/core/pm3/pm3_client_settings.dart';
import 'package:pm3gui/core/pm3/pm3_controller.dart';
import 'package:pm3gui/services/pm3_settings_store.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/state/connection_state.dart' as pm3;
import 'package:pm3gui/ui/pages/settings_page.dart';
import 'package:provider/provider.dart';
import '../support/localized_test_app.dart';

void main() {
  testWidgets('settings page shows a consumed save error', (tester) async {
    late final AppState state;
    await tester.runAsync(() async {
      state = AppState(
        connectionState: pm3.ConnectionState(
          controller: Pm3Controller(MockPm3Backend()),
          settingsStore: _ThrowingSettingsStore(),
        ),
      );
      await state.initialize();
    });
    addTearDown(() => tester.runAsync(state.shutdown));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const LocalizedTestApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    await tester.runAsync(() => state.setPm3Path('failing-client'));
    await tester.pump();

    expect(find.byKey(const ValueKey('settings-error')), findsOneWidget);
    expect(find.textContaining('save failed'), findsOneWidget);
  });
}

final class _ThrowingSettingsStore implements Pm3SettingsRepository {
  @override
  Future<Pm3ClientSettings?> load() async => null;

  @override
  Future<void> save(Pm3ClientSettings settings) async {
    throw StateError('save failed');
  }
}

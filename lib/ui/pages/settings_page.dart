/// Settings page — app configuration.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/core/pm3/pm3_argument_codec.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/l10n/app_locale_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _pm3PathController = TextEditingController();
  final _argumentsController = TextEditingController();
  final _workingDirectoryController = TextEditingController();
  final _argumentsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _argumentsFocusNode.addListener(_refreshAfterArgumentsEditing);
  }

  @override
  void dispose() {
    _pm3PathController.dispose();
    _argumentsController.dispose();
    _argumentsFocusNode
      ..removeListener(_refreshAfterArgumentsEditing)
      ..dispose();
    _workingDirectoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = context.watch<AppLocaleController>();
    final l10n = context.l10n;
    _syncController(_pm3PathController, appState.pm3Path);
    if (!_argumentsFocusNode.hasFocus) {
      _syncController(
        _argumentsController,
        encodePm3Arguments(appState.pm3Arguments),
      );
    }
    _syncController(
      _workingDirectoryController,
      appState.pm3WorkingDirectory ?? '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.navSettings,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l10n.language),
                    contentPadding: EdgeInsets.zero,
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                        'language-${language.locale?.languageCode ?? 'system'}'),
                    initialValue: language.locale?.languageCode ?? 'system',
                    decoration: InputDecoration(labelText: l10n.language),
                    items: [
                      DropdownMenuItem(
                          value: 'system', child: Text(l10n.languageSystem)),
                      const DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                      const DropdownMenuItem(
                          value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      language
                          .setLocale(value == 'system' ? null : Locale(value));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.languageHelp),
                  if (language.isSaving) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (language.error case final error?) ...[
                    const SizedBox(height: 8),
                    Text(l10n.languagePreferenceError(error.toString()),
                        key: const ValueKey('language-error'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // PM3 Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.terminal),
                    title: Text(l10n.settingsPm3Configuration),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextFormField(
                    controller: _pm3PathController,
                    decoration: InputDecoration(
                      labelText: l10n.settingsPm3Path,
                      hintText: Platform.isWindows
                          ? l10n.settingsWindowsPathHint
                          : '/usr/bin/proxmark3',
                      helperText: Platform.isWindows
                          ? l10n.settingsWindowsPathHelp
                          : null,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder_open),
                        tooltip: l10n.settingsPickPm3,
                        onPressed: () async {
                          final path =
                              await FileDialogService.pickSingleFilePath();
                          if (path != null) await appState.setPm3Path(path);
                        },
                      ),
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _argumentsController,
                    focusNode: _argumentsFocusNode,
                    decoration: InputDecoration(
                      labelText: l10n.settingsArguments,
                      hintText: '--flush\n--example=value with spaces',
                      helperText: Platform.isWindows
                          ? l10n.settingsWindowsArgumentsHelp
                          : l10n.settingsArgumentsHelp,
                    ),
                    minLines: 2,
                    maxLines: 6,
                    onChanged: (value) => appState.setPm3Arguments(
                      decodePm3Arguments(value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _workingDirectoryController,
                    decoration: InputDecoration(
                      labelText: l10n.settingsWorkingDirectory,
                    ),
                    onChanged: appState.setPm3WorkingDirectory,
                  ),
                  if (appState.isSavingSettings) ...[
                    const SizedBox(height: 12),
                    Row(
                      key: const ValueKey('settings-saving'),
                      children: [
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.settingsSaving),
                      ],
                    ),
                  ],
                  if (appState.settingsError case final error?) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      key: const ValueKey('settings-error'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // About
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l10n.settingsAbout),
                  subtitle: Text(l10n.settingsDescription),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(l10n.settingsPlatform),
                  subtitle: Text(Platform.operatingSystem),
                ),
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: Text(l10n.settingsArchitecture),
                  subtitle: Text(l10n.settingsArchitectureDescription),
                ),
                ListTile(
                  leading: const Icon(Icons.layers),
                  title: Text(l10n.settingsSupportedFormats),
                  subtitle: const Text('.eml, .bin/.dump, .json (PM3 Jansson)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text(
            l10n.settingsMaintenance,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => appState.clearTerminal(),
                icon: const Icon(Icons.delete_sweep),
                label: Text(l10n.terminalClear),
              ),
              if (appState.isConnected)
                OutlinedButton.icon(
                  onPressed: () => appState.sendCommand('hw version'),
                  icon: const Icon(Icons.info),
                  label: Text(l10n.hardwareVersion),
                ),
              if (appState.isConnected)
                OutlinedButton.icon(
                  onPressed: () => appState.sendCommand('hw tune'),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.antennaTune),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _refreshAfterArgumentsEditing() {
    if (!_argumentsFocusNode.hasFocus && mounted) setState(() {});
  }
}

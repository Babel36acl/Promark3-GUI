/// LF Indala operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfIndalaPage extends StatefulWidget {
  const LfIndalaPage({super.key});

  @override
  State<LfIndalaPage> createState() => _LfIndalaPageState();
}

class _LfIndalaPageState extends State<LfIndalaPage> {
  String _rawData = '';
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _execute(String cmd) async {
    if (!ensurePm3Ready(context)) return;
    setState(() {
      _lastCmd = cmd;
      _isLoading = true;
      _result = '';
    });
    final buf = StringBuffer();
    _sub?.cancel();
    _sub = context.read<AppState>().pm3PageOutput.listen((line) {
      if (!line.startsWith('[pm3]')) {
        buf.writeln(line);
        if (mounted) setState(() => _result = buf.toString());
      }
    });
    await context.read<AppState>().sendCommand(cmd);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageRead,
              subtitle: context.l10n.messageReadAnIndalaCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfIndalaCmd.reader())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageCloneSimulate,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      HexInputField(
                          label: context.l10n.messageRawData2,
                          onChanged: (v) => setState(() => _rawData = v)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ElevatedButton.icon(
                            onPressed: _rawData.isNotEmpty
                                ? () => _execute(LfIndalaCmd.clone(_rawData))
                                : null,
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(context.l10n.messageClone)),
                        OutlinedButton.icon(
                            onPressed: _rawData.isNotEmpty
                                ? () => _execute(LfIndalaCmd.sim(_rawData))
                                : null,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(context.l10n.messageSimulate)),
                      ]),
                    ],
                  ))),
        ],
      ),
      main: ResultDisplay(
          command: _lastCmd,
          result: _result,
          isLoading: _isLoading,
          onClear: () => setState(() {
                _result = '';
                _lastCmd = '';
              })),
    );
  }
}

/// LF Keri operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfKeriPage extends StatefulWidget {
  const LfKeriPage({super.key});

  @override
  State<LfKeriPage> createState() => _LfKeriPageState();
}

class _LfKeriPageState extends State<LfKeriPage> {
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
              subtitle: context.l10n.messageReadAKeriCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfKeriCmd.reader())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageClone,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      HexInputField(
                          label: context.l10n.messageRawData2,
                          onChanged: (v) => setState(() => _rawData = v)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: _rawData.isNotEmpty
                              ? () => _execute(LfKeriCmd.clone(_rawData))
                              : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(context.l10n.messageCloneToT55xx)),
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

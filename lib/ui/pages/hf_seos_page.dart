/// SEOS operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfSeosPage extends StatefulWidget {
  const HfSeosPage({super.key});

  @override
  State<HfSeosPage> createState() => _HfSeosPageState();
}

class _HfSeosPageState extends State<HfSeosPage> {
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
              title: context.l10n.messageInformation,
              subtitle: context.l10n.messageReadSeosInformation,
              icon: Icons.info_outline,
              onTap: () => _execute(HfSeosCmd.info())),
          ActionCard(
              title: 'PACS',
              subtitle: context.l10n.messageReadPacsData,
              icon: Icons.badge,
              onTap: () => _execute(HfSeosCmd.pacs())),
          ActionCard(
              title: context.l10n.messageSimulate,
              subtitle: context.l10n.messageSimulateASeosCard,
              icon: Icons.play_arrow,
              onTap: () => _execute(HfSeosCmd.sim())),
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

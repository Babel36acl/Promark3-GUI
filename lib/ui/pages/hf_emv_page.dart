/// EMV contactless payment operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfEmvPage extends StatefulWidget {
  const HfEmvPage({super.key});

  @override
  State<HfEmvPage> createState() => _HfEmvPageState();
}

class _HfEmvPageState extends State<HfEmvPage> {
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
              title: context.l10n.messageSearch,
              subtitle: context.l10n.messageSearchForEmvCards,
              icon: Icons.search,
              onTap: () => _execute(HfEmvCmd.search())),
          ActionCard(
              title: 'PPSE',
              subtitle: context.l10n.messageSelectPpseApplication,
              icon: Icons.payment,
              onTap: () => _execute(HfEmvCmd.ppse())),
          ActionCard(
              title: context.l10n.messageExecuteTransaction,
              subtitle: context.l10n.messageSimulateTheEmvTransactionFlow,
              icon: Icons.receipt_long,
              onTap: () => _execute(HfEmvCmd.exec())),
          ActionCard(
              title: context.l10n.messageTest,
              subtitle: context.l10n.messageEmvSelfTest,
              icon: Icons.check_circle,
              onTap: () => _execute(HfEmvCmd.test())),
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

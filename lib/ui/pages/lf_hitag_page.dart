/// LF Hitag operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfHitagPage extends StatefulWidget {
  const LfHitagPage({super.key});

  @override
  State<LfHitagPage> createState() => _LfHitagPageState();
}

class _LfHitagPageState extends State<LfHitagPage> {
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
              subtitle: context.l10n.messageReadAHitagCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfHitagCmd.reader())),
          ActionCard(
              title: context.l10n.messageInformation,
              subtitle: context.l10n.messageGetTagDetails,
              icon: Icons.info_outline,
              onTap: () => _execute(LfHitagCmd.info())),
          ActionCard(
              title: context.l10n.messageDump,
              subtitle: context.l10n.messageDumpAllData,
              icon: Icons.download,
              onTap: () => _execute(LfHitagCmd.dump())),
          ActionCard(
              title: context.l10n.messageSniff,
              subtitle: context.l10n.messageCaptureCommunicationData,
              icon: Icons.hearing,
              onTap: () => _execute(LfHitagCmd.sniff())),
          ActionCard(
              title: context.l10n.messageCheckKeys,
              subtitle: context.l10n.messageCheckCommonKeys,
              icon: Icons.security,
              onTap: () => _execute(LfHitagCmd.chk())),
          ActionCard(
              title: context.l10n.messageKeyRecovery,
              subtitle: context.l10n.messageKeyRecoveryAttack,
              icon: Icons.bolt,
              onTap: () => _execute(LfHitagCmd.crack())),
          ActionCard(
              title: context.l10n.messageSimulate,
              subtitle: context.l10n.messageSimulateAHitagTag,
              icon: Icons.play_arrow,
              onTap: () => _execute(LfHitagCmd.sim())),
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

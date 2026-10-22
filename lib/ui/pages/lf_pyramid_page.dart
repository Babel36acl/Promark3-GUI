/// LF Pyramid operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfPyramidPage extends StatefulWidget {
  const LfPyramidPage({super.key});

  @override
  State<LfPyramidPage> createState() => _LfPyramidPageState();
}

class _LfPyramidPageState extends State<LfPyramidPage> {
  String _fc = '';
  String _cn = '';
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
              subtitle: context.l10n.messageReadAPyramidCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfPyramidCmd.reader())),
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
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageFcFacilityCode,
                            isDense: true),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (v) => setState(() => _fc = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageCnCardNumber,
                            isDense: true),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: (v) => setState(() => _cn = v),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: _fc.isNotEmpty && _cn.isNotEmpty
                              ? () => _execute(LfPyramidCmd.clone(_fc, _cn))
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

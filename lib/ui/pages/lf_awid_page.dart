/// LF AWID operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class LfAwidPage extends StatefulWidget {
  const LfAwidPage({super.key});

  @override
  State<LfAwidPage> createState() => _LfAwidPageState();
}

class _LfAwidPageState extends State<LfAwidPage> {
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
              subtitle: context.l10n.messageReadAnAwidCard,
              icon: Icons.nfc,
              onTap: () => _execute(LfAwidCmd.reader())),
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
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ElevatedButton.icon(
                            onPressed: _fc.isNotEmpty && _cn.isNotEmpty
                                ? () => _execute(LfAwidCmd.clone(_fc, _cn))
                                : null,
                            icon: const Icon(Icons.copy, size: 18),
                            label: Text(context.l10n.messageClone)),
                        OutlinedButton.icon(
                            onPressed: _fc.isNotEmpty && _cn.isNotEmpty
                                ? () => _execute(LfAwidCmd.sim(_fc, _cn))
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
        }),
      ),
    );
  }
}

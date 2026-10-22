/// HF Sniff unified page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfSniffPage extends StatefulWidget {
  const HfSniffPage({super.key});

  @override
  State<HfSniffPage> createState() => _HfSniffPageState();
}

class _HfSniffPageState extends State<HfSniffPage> {
  String _listProtocol = '14a';
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  static const _protocols = [
    '14a',
    '14b',
    'felica',
    'iclass',
    'legic',
    'mf',
    'topaz',
  ];

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
              title: context.l10n.messageHfSearch,
              subtitle: context.l10n.messageSearchForHighFrequencyTags,
              icon: Icons.search,
              onTap: () => _execute(HfCmd.search())),
          ActionCard(
              title: context.l10n.messageHfSniff,
              subtitle: context.l10n.messageCaptureHighFrequencyCommunication,
              icon: Icons.hearing,
              onTap: () => _execute(HfCmd.sniff())),
          ActionCard(
              title: context.l10n.messageHfTuning,
              subtitle: context.l10n.messageTuneTheHfAntenna,
              icon: Icons.tune,
              onTap: () => _execute(HfCmd.tune())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageProtocolList,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _listProtocol,
                        decoration: InputDecoration(
                            labelText: context.l10n.messageProtocol,
                            isDense: true),
                        items: _protocols
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _listProtocol = v ?? '14a'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () => _execute(HfCmd.list(_listProtocol)),
                          icon: const Icon(Icons.list, size: 18),
                          label: Text(context.l10n.messageDecodeList)),
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

/// Trace capture and analysis page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class TracePage extends StatefulWidget {
  const TracePage({super.key});

  @override
  State<TracePage> createState() => _TracePageState();
}

class _TracePageState extends State<TracePage> {
  String _file = '';
  String _protocol = 'raw';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  static const _protocols = [
    'raw',
    '14a',
    '14b',
    'felica',
    'iclass',
    'legic',
    'mf',
    'hitag1',
    'hitag2',
    'hitags',
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
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageListDecode,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _protocol,
                        decoration: InputDecoration(
                            labelText: context.l10n.messageProtocolType,
                            isDense: true),
                        items: _protocols
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _protocol = v ?? 'raw'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () =>
                              _execute(TraceCmd.list(type: _protocol)),
                          icon: const Icon(Icons.list_alt, size: 18),
                          label: Text(context.l10n.messageDecodeList2)),
                    ],
                  ))),
          ActionCard(
              title: context.l10n.messageExtract,
              subtitle: context.l10n.messageExtractTraceData,
              icon: Icons.filter_alt,
              onTap: () => _execute(TraceCmd.extract())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageFileOperations,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageFilePath,
                            isDense: true),
                        onChanged: (v) => _file = v,
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ElevatedButton.icon(
                            onPressed: _file.isNotEmpty
                                ? () => _execute(TraceCmd.save(_file))
                                : null,
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(context.l10n.messageSave)),
                        OutlinedButton.icon(
                            onPressed: _file.isNotEmpty
                                ? () => _execute(TraceCmd.load(_file))
                                : null,
                            icon: const Icon(Icons.upload, size: 18),
                            label: Text(context.l10n.messageLoad)),
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

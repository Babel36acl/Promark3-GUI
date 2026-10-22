/// NFC type operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class NfcPage extends StatefulWidget {
  const NfcPage({super.key});

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> {
  String _hexData = '';
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
              title: 'Type 1',
              subtitle: 'NFC Type 1 Tag',
              icon: Icons.nfc,
              onTap: () => _execute(NfcCmd.type1())),
          ActionCard(
              title: 'Type 2',
              subtitle: 'NFC Type 2 Tag',
              icon: Icons.nfc,
              onTap: () => _execute(NfcCmd.type2())),
          ActionCard(
              title: 'Type 4A',
              subtitle: 'NFC Type 4A Tag',
              icon: Icons.nfc,
              onTap: () => _execute(NfcCmd.type4a())),
          ActionCard(
              title: 'Barcode',
              subtitle: 'NFC Barcode',
              icon: Icons.qr_code,
              onTap: () => _execute(NfcCmd.barcode())),
          const SizedBox(height: 8),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageNdefDecoding,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      HexInputField(
                          label: context.l10n.messageHexData,
                          onChanged: (v) => _hexData = v),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: _hexData.isNotEmpty
                              ? () => _execute(NfcCmd.decode(_hexData))
                              : null,
                          icon: const Icon(Icons.code, size: 18),
                          label: Text(context.l10n.messageDecode)),
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

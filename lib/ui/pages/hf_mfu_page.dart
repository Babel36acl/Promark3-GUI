/// Mifare Ultralight / NTAG operations page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HfMfuPage extends StatefulWidget {
  const HfMfuPage({super.key});

  @override
  State<HfMfuPage> createState() => _HfMfuPageState();
}

class _HfMfuPageState extends State<HfMfuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _blockNumber = 0;
  String _blockData = '';
  String _password = '';
  String _uid = '';
  String _emuFile = '';

  // Result state
  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.messageInformation),
            Tab(text: context.l10n.messageReadWrite),
            Tab(text: 'NDEF'),
            Tab(text: context.l10n.messageEmulator),
            Tab(text: context.l10n.navTools),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
              _buildNdefTab(),
              _buildEmulatorTab(),
              _buildToolsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Info tab ──────────────────────────────────────────────
  Widget _buildInfoTab() {
    return SplitPageLayout(
      sideWidth: 280,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageGetInformation,
              subtitle: context.l10n.messageReadAnMfuNtagTag,
              icon: Icons.info_outline,
              onTap: () => _execute(HfMfuCmd.info())),
          ActionCard(
              title: context.l10n.messageDumpCard,
              subtitle: context.l10n.messageReadAllDataToAFile,
              icon: Icons.download,
              onTap: () => _execute(HfMfuCmd.dump())),
          ActionCard(
              title: context.l10n.messageEraseCard,
              subtitle: context.l10n.messageClearCardData,
              icon: Icons.delete_forever,
              onTap: () => _confirmThenExecute(
                  context.l10n.messageConfirmErase,
                  context.l10n.messageThisOperationCannotBeUndone,
                  HfMfuCmd.wipe())),
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

  // ── Read / Write tab ──────────────────────────────────────
  Widget _buildReadWriteTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageBlockOperations,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: context.l10n.messageBlockNumber),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => _blockNumber = int.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _execute(HfMfuCmd.rdbl(_blockNumber)),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: Text(context.l10n.messageReadBlock),
                    ),
                  ),
                  const SizedBox(height: 12),
                  HexInputField(
                    label: context.l10n.messageWriteDataHex,
                    byteLength: 4,
                    onChanged: (v) => _blockData = v,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _blockData.length == 8
                        ? () =>
                            _execute(HfMfuCmd.wrbl(_blockNumber, _blockData))
                        : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(context.l10n.messageWriteBlock),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messagePasswordAuthentication,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  HexInputField(
                    label: context.l10n.messagePassword4ByteHex,
                    byteLength: 4,
                    onChanged: (v) => _password = v,
                    prefixIcon: Icons.vpn_key,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _password.length == 8
                        ? () => _execute(HfMfuCmd.cauth(_password))
                        : null,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: Text(context.l10n.messageAuthenticate),
                  ),
                ],
              ),
            ),
          ),
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

  // ── NDEF tab ──────────────────────────────────────────────
  Widget _buildNdefTab() {
    return SplitPageLayout(
      sideWidth: 280,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageReadNdef,
              subtitle: context.l10n.messageReadNfcDataExchangeFormat,
              icon: Icons.article,
              onTap: () => _execute(HfMfuCmd.ndefRead())),
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

  // ── Emulator tab ──────────────────────────────────────────
  Widget _buildEmulatorTab() {
    return SplitPageLayout(
      sideWidth: 340,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageEmulatorOperations,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: context.l10n.messageFilePathOptional,
                      hintText: context.l10n.messageLeaveBlankToUseTheDefault,
                      prefixIcon: Icon(Icons.file_open, size: 18),
                    ),
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    onChanged: (v) => _emuFile = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.eload(
                            _emuFile.isEmpty ? 'dump' : _emuFile)),
                        icon: const Icon(Icons.upload, size: 18),
                        label: Text(context.l10n.messageLoadIntoEmulator),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.esave(
                            file: _emuFile.isEmpty ? null : _emuFile)),
                        icon: const Icon(Icons.save, size: 18),
                        label: Text(context.l10n.messageSaveEmulator),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.eview()),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: Text(context.l10n.messageView),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _execute(HfMfuCmd.sim()),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: Text(context.l10n.messageSimulate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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

  // ── Tools tab ─────────────────────────────────────────────
  Widget _buildToolsTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messageGenerateKeys,
              subtitle: context.l10n.messageKeygenDeriveKeysFromUid,
              icon: Icons.vpn_key,
              onTap: () => _execute(HfMfuCmd.keygen())),
          ActionCard(
              title: context.l10n.messageDerivePassword,
              subtitle: context.l10n.messagePwdgenDeriveTheNtagPassword,
              icon: Icons.password,
              onTap: () => _execute(HfMfuCmd.pwdgen())),
          ActionCard(
              title: context.l10n.messageKeyCheck,
              subtitle: context.l10n.messageCchkCheckCommonKeys,
              icon: Icons.security,
              onTap: () => _execute(HfMfuCmd.cchk())),
          const Divider(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageSetUid,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  HexInputField(
                    label: context.l10n.messageUid7ByteHex,
                    byteLength: 7,
                    onChanged: (v) => _uid = v,
                    prefixIcon: Icons.credit_card,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _uid.length == 14
                        ? () => _execute(HfMfuCmd.setuid(_uid))
                        : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(context.l10n.messageSetUid),
                  ),
                ],
              ),
            ),
          ),
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

  // ── Helpers ───────────────────────────────────────────────
  void _confirmThenExecute(String title, String msg, String cmd) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.messageCancel)),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _execute(cmd);
              },
              child: Text(context.l10n.messageConfirm)),
        ],
      ),
    );
  }
}

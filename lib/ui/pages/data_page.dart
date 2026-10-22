/// Data processing utilities page.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/components/components.dart';
import 'package:pm3gui/l10n/l10n.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _file = '';
  String _sampleCount = '20000';
  String _hexData = '';
  String _fileA = '';
  String _fileB = '';

  String _lastCmd = '';
  String _result = '';
  bool _isLoading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    return Column(children: [
      TabBar(controller: _tabController, tabs: [
        Tab(text: context.l10n.messageBasic),
        Tab(text: context.l10n.messageAnalysis),
        Tab(text: context.l10n.messageCompare),
      ]),
      Expanded(
          child: TabBarView(controller: _tabController, children: [
        _buildBasicTab(),
        _buildAnalyzeTab(),
        _buildDiffTab(),
      ])),
    ]);
  }

  Widget _buildBasicTab() {
    return SplitPageLayout(
      side: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionCard(
              title: context.l10n.messagePlot,
              subtitle: context.l10n.messageDisplayTheDataGraph,
              icon: Icons.show_chart,
              onTap: () => _execute(DataCmd.plot())),
          ActionCard(
              title: context.l10n.messageClear,
              subtitle: context.l10n.messageClearTheGraphBuffer,
              icon: Icons.clear_all,
              onTap: () => _execute(DataCmd.clear())),
          ActionCard(
              title: context.l10n.messageDetectClock,
              subtitle: context.l10n.messageAutomaticallyDetectTheClockRate,
              icon: Icons.timer,
              onTap: () => _execute(DataCmd.detectclock())),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.messageSampling,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        decoration: InputDecoration(
                            labelText: context.l10n.messageSampleCount,
                            isDense: true),
                        initialValue: _sampleCount,
                        onChanged: (v) => _sampleCount = v,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                          onPressed: () => _execute(DataCmd.samples(
                              count: int.tryParse(_sampleCount) ?? 20000)),
                          icon: const Icon(Icons.memory, size: 18),
                          label: Text(context.l10n.messageReadSamples)),
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

  Widget _buildAnalyzeTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageFileOperations,
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                              ? () => _execute(DataCmd.save(_file))
                              : null,
                          icon: const Icon(Icons.save, size: 18),
                          label: Text(context.l10n.messageSave)),
                      OutlinedButton.icon(
                          onPressed: _file.isNotEmpty
                              ? () => _execute(DataCmd.load(_file))
                              : null,
                          icon: const Icon(Icons.upload, size: 18),
                          label: Text(context.l10n.messageLoad)),
                    ]),
                  ],
                ))),
        const SizedBox(height: 12),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.messageAsn1Decoding,
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    HexInputField(
                        label: context.l10n.messageHexData,
                        onChanged: (v) => _hexData = v),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                        onPressed: _hexData.isNotEmpty
                            ? () => _execute(DataCmd.asn1(_hexData))
                            : null,
                        icon: const Icon(Icons.code, size: 18),
                        label: Text(context.l10n.messageDecode)),
                  ],
                ))),
      ]),
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

  Widget _buildDiffTab() {
    return SplitPageLayout(
      sideWidth: 320,
      side: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageFileComparison,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: context.l10n.messageFileA, isDense: true),
                    onChanged: (v) => _fileA = v,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: context.l10n.messageFileB, isDense: true),
                    onChanged: (v) => _fileB = v,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                      onPressed: _fileA.isNotEmpty && _fileB.isNotEmpty
                          ? () => _execute(DataCmd.diff(_fileA, _fileB))
                          : null,
                      icon: const Icon(Icons.compare, size: 18),
                      label: Text(context.l10n.messageCompare)),
                ],
              ))),
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

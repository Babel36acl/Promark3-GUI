/// Connection & Dashboard page — PM3 connection, device info, file browser.
library;

import 'dart:io';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/file_collector.dart';
import 'package:pm3gui/services/file_dialog_service.dart';
import 'package:pm3gui/ui/theme.dart';
import 'package:pm3gui/l10n/l10n.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  bool _scanning = false;
  final _pm3PathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _pm3PathController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final appState = context.read<AppState>();
    await appState.initialize();
    if (!mounted) return;
    await _scanPorts();
    if (!mounted) return;
    await appState.scanForFiles();
  }

  Future<void> _scanPorts() async {
    setState(() => _scanning = true);
    final appState = context.read<AppState>();

    try {
      final ports = <String>[];

      if (Platform.isLinux) {
        final devDir = Directory('/dev');
        if (devDir.existsSync()) {
          for (final entity in devDir.listSync()) {
            final name = entity.path;
            if (name.contains('ttyACM') || name.contains('ttyUSB')) {
              ports.add(name);
            }
          }
        }
      } else if (Platform.isWindows) {
        for (var i = 1; i <= 20; i++) {
          ports.add('COM$i');
        }
      }

      ports.sort();
      appState.availablePorts = ports;
      if (ports.isNotEmpty && appState.portName.isEmpty) {
        appState.setPort(ports.first);
      }
    } catch (e) {
      // Ignore scan errors
    }

    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final isConnected = context.select<AppState, bool>((s) =>
        s.connectionState.connectionState == Pm3ConnectionState.connected);
    final isConnecting = context.select<AppState, bool>((s) =>
        s.connectionState.connectionState == Pm3ConnectionState.connecting);
    final pm3Path = context.select<AppState, String>((s) => s.pm3Path);
    if (_pm3PathController.text != pm3Path) {
      _pm3PathController.value = TextEditingValue(
        text: pm3Path,
        selection: TextSelection.collapsed(offset: pm3Path.length),
      );
    }
    final availablePorts =
        context.select<AppState, List<String>>((s) => s.availablePorts);
    final portName = context.select<AppState, String>((s) => s.portName);
    final pm3Version = context.select<AppState, String>((s) => s.pm3Version);
    final lastError = context.select<AppState, String>((s) => s.lastError);
    final hwInfoParsed = context.select<AppState, bool>((s) => s.hwInfoParsed);
    final hwModel = context.select<AppState, String>((s) => s.hwModel);
    final hwMcu = context.select<AppState, String>((s) => s.hwMcu);
    final hwFlashSize = context.select<AppState, String>((s) => s.hwFlashSize);
    final hwFirmware = context.select<AppState, String>((s) => s.hwFirmware);
    final hwBootrom = context.select<AppState, String>((s) => s.hwBootrom);
    final hwFpga = context.select<AppState, String>((s) => s.hwFpga);
    final hwSmartcard = context.select<AppState, String>((s) => s.hwSmartcard);
    final hwUniqueId = context.select<AppState, String>((s) => s.hwUniqueId);
    final hwFlashTotal = context.select<AppState, int>((s) => s.hwFlashTotal);
    final commandHistoryLength =
        context.select<AppState, int>((s) => s.commandHistory.length);
    final terminalOutputLength =
        context.select<AppState, int>((s) => s.terminalOutput.length);
    final collectedFilesCount =
        context.select<AppState, int>((s) => s.collectedFiles.length);
    final cardGroupsCount =
        context.select<AppState, int>((s) => s.cardGroups.length);
    final isFileScanning = context.select<AppState, bool>((s) => s.isScanning);
    final hasCollectedFiles =
        context.select<AppState, bool>((s) => s.collectedFiles.isNotEmpty);
    final cardGroups =
        context.select<AppState, List<CardGroup>>((s) => s.cardGroups);
    final theme = Theme.of(context);

    return Row(
      children: [
        // ═══════ 左栏: 连接 & 设备信息 ═══════
        SizedBox(
          width: 360,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 连接状态头 ──
                _buildConnectionHeader(appState, isConnected, theme),
                const SizedBox(height: 16),

                // ── PM3 路径 ──
                _buildSection(
                  icon: Icons.folder_open,
                  title: context.l10n.settingsPm3Path,
                  child: TextFormField(
                    controller: _pm3PathController,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: Platform.isWindows
                          ? context.l10n.settingsWindowsPathHint
                          : '/usr/bin/proxmark3',
                      helperText: Platform.isWindows
                          ? context.l10n.messageOnWindowsUseTheOfficialPm3Bat
                          : null,
                      prefixIcon: const Icon(Icons.terminal, size: 18),
                      suffixIcon: File(pm3Path).existsSync()
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                    size: 18, color: AppTheme.accentBlue),
                                _pickPm3PathButton(appState),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning,
                                    size: 18, color: Color(0xFFF87171)),
                                _pickPm3PathButton(appState),
                              ],
                            ),
                    ),
                    onChanged: appState.setPm3Path,
                  ),
                ),
                const SizedBox(height: 12),

                // ── 串口选择 ──
                _buildSection(
                  icon: Icons.usb,
                  title: context.l10n.messageSerialPort,
                  trailing: IconButton(
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 18),
                    onPressed: _scanning ? null : _scanPorts,
                    tooltip: context.l10n.messageRefreshPorts,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: availablePorts.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF87171).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            Icon(Icons.info_outline,
                                size: 16, color: const Color(0xFFF87171)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  context.l10n
                                      .messageNoSerialPortFoundConnectYourPm3,
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ]),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: availablePorts.contains(portName)
                              ? portName
                              : null,
                          items: availablePorts
                              .map((p) =>
                                  DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: isConnected
                              ? null
                              : (v) {
                                  if (v != null) appState.setPort(v);
                                },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.usb, size: 18),
                            helperText: Platform.isWindows &&
                                    (pm3Path.toLowerCase().endsWith('.bat') ||
                                        pm3Path.toLowerCase().endsWith('.cmd'))
                                ? context.l10n
                                    .messageTheOfficialBatLauncherDetectsDevicesAutomatically
                                : null,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // ── 连接按钮 ──
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isConnecting
                        ? null
                        : () async {
                            if (isConnected) {
                              await appState.disconnect();
                            } else {
                              await appState.connect();
                            }
                          },
                    icon: isConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(isConnected ? Icons.link_off : Icons.link,
                            size: 18),
                    label: Text(
                      isConnecting
                          ? context.l10n.messageConnecting
                          : isConnected
                              ? context.l10n.messageDisconnect
                              : context.l10n.messageConnectPm3,
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? AppTheme.accentBlue : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── 错误信息 ──
                if (!isConnected && lastError.isNotEmpty)
                  _buildErrorCard(lastError),

                // ── 设备信息（已连接时） ──
                if (isConnected) ...[
                  const SizedBox(height: 12),
                  _buildSection(
                    icon: Icons.developer_board,
                    title: context.l10n.messageDeviceInformation,
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh, size: 16),
                      tooltip: context.l10n.messageRefreshHardwareInformation,
                      onPressed: () => appState.refreshHwInfo(),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(context.l10n.messagePort, portName),
                        _infoRow(context.l10n.messageVersion, pm3Version),
                        _infoRow(
                            context.l10n.messageStatus, context.l10n.connected,
                            valueColor: AppTheme.accentBlue),
                        if (hwInfoParsed) ...[
                          const Divider(height: 16),
                          if (hwModel.isNotEmpty)
                            _infoRow(context.l10n.messageDeviceModel, hwModel),
                          if (hwMcu.isNotEmpty) _infoRow('MCU', hwMcu),
                          if (hwFlashSize.isNotEmpty)
                            _infoRow('Flash', hwFlashSize),
                          if (hwFirmware.isNotEmpty)
                            _infoRow(context.l10n.messageFirmware, hwFirmware),
                          if (hwBootrom.isNotEmpty)
                            _infoRow('Bootrom', hwBootrom),
                          if (hwFpga.isNotEmpty) _infoRow('FPGA', hwFpga),
                          if (hwSmartcard.isNotEmpty)
                            _infoRow(context.l10n.messageSmartcardModule,
                                hwSmartcard),
                          if (hwUniqueId.isNotEmpty)
                            _infoRow(context.l10n.messageDeviceId, hwUniqueId),
                          if (hwFlashTotal > 0) _buildFlashUsage(appState),
                        ] else ...[
                          const Divider(height: 16),
                          Row(children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                context
                                    .l10n.messageRetrievingHardwareInformation,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                          ]),
                        ],
                        const Divider(height: 16),
                        _infoRow(context.l10n.messageCommandHistory,
                            context.l10n.messageCommands(commandHistoryLength)),
                        _infoRow(
                            context.l10n.messageTerminalBuffer,
                            context.l10n.messageLines(
                                (terminalOutputLength).toString())),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw version'),
                              icon: const Icon(Icons.info, size: 14),
                              label: Text(context.l10n.hardwareVersion,
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => appState.sendCommand('hw tune'),
                              icon: const Icon(Icons.wifi_tethering, size: 14),
                              label: Text(context.l10n.antennaTune,
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw status'),
                              icon: const Icon(Icons.monitor_heart, size: 14),
                              label: Text(context.l10n.messageHardwareStatus,
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  appState.sendCommand('hw dbg -4'),
                              icon: const Icon(Icons.bug_report, size: 14),
                              label: Text(context.l10n.messageDebugLevel,
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],

                // ── 平台信息 ──
                const SizedBox(height: 16),
                _buildSection(
                  icon: Icons.computer,
                  title: context.l10n.messageEnvironment,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(context.l10n.settingsPlatform,
                          Platform.operatingSystem),
                      _infoRow(context.l10n.settingsArchitecture, _getArch()),
                      _infoRow('Dart', Platform.version.split(' ').first),
                      _infoRow(
                          context.l10n.messagePm3Path,
                          File(pm3Path).existsSync()
                              ? context.l10n.messageValid
                              : context.l10n.messageInvalid),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: theme.dividerColor),

        // ═══════ 右栏: 文件收集 & 概览 ═══════
        Expanded(
          child: Column(
            children: [
              // 文件收集工具栏
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(Icons.folder_special,
                          size: 20, color: AppTheme.accentBlue),
                      const SizedBox(width: 8),
                      Text(context.l10n.messagePm3FileCollection,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (appState.fileState.scanError != null)
                        Tooltip(
                            message: appState.fileState.scanError!,
                            child: const Icon(Icons.error_outline,
                                color: Colors.orange)),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.messageFilesCards(
                            (collectedFilesCount).toString(),
                            (cardGroupsCount).toString()),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(width: 8),
                      if (isFileScanning)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: isFileScanning
                            ? null
                            : () => appState.scanForFiles(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(context.l10n.messageScan,
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: !hasCollectedFiles
                            ? null
                            : () => _showOrganizeDialog(appState),
                        icon: const Icon(Icons.create_new_folder, size: 16),
                        label: Text(context.l10n.messageOrganizeFiles,
                            style: TextStyle(fontSize: 12)),
                      ),
                    ]),
              ),
              const Divider(height: 1),

              // 文件列表（按卡片分组）
              Expanded(
                child: cardGroups.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off,
                              size: 48,
                              color: Colors.grey.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(context.l10n.messageNoPm3ExportFilesFound,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                              context.l10n
                                  .messageFilesAreCollectedAutomaticallyAfterConnectingAnd,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: cardGroups.length,
                        itemBuilder: (context, i) =>
                            _buildCardGroupTile(cardGroups[i], theme),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pickPm3PathButton(AppState appState) => IconButton(
        icon: const Icon(Icons.folder_open, size: 18),
        tooltip: context.l10n.settingsPickPm3,
        onPressed: () async {
          final path = await FileDialogService.pickSingleFilePath();
          if (path != null) await appState.setPm3Path(path);
        },
      );

  // ── Connection header ──────────────────────────────────────────────────

  Widget _buildConnectionHeader(
      AppState appState, bool isConnected, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [
                  AppTheme.accentBlue.withValues(alpha: 0.15),
                  AppTheme.accentBlue.withValues(alpha: 0.08),
                ]
              : [
                  AppTheme.auxiliaryGrey.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected
              ? AppTheme.accentBlue.withValues(alpha: 0.3)
              : theme.dividerColor,
        ),
      ),
      child: Row(children: [
        // Status icon
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected
                ? AppTheme.accentBlue.withValues(alpha: 0.2)
                : AppTheme.auxiliaryGrey.withValues(alpha: 0.15),
          ),
          child: Icon(
            isConnected ? Icons.nfc : Icons.usb_off,
            color: isConnected ? AppTheme.accentBlue : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected
                    ? context.l10n.messagePm3Connected
                    : context.l10n.messagePm3NotConnected,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                isConnected
                    ? '${appState.portName}  •  ${appState.pm3Version}'
                    : context.l10n.messageSelectASerialPortAndConnectThe,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Reusable section card ──────────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: AppTheme.accentBlue),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              if (trailing != null) ...[const Spacer(), trailing],
            ]),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  // ── Error card ─────────────────────────────────────────────────────────

  Widget _buildErrorCard(String error) {
    return Card(
      color: const Color(0xFFF87171).withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: const Color(0xFFF87171), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.messageConnectionFailed2,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF87171),
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(error,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card group tile ────────────────────────────────────────────────────

  Widget _buildCardGroupTile(CardGroup group, ThemeData theme) {
    final bandColor =
        group.band == FreqBand.hf ? AppTheme.accentBlue : AppTheme.accentBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bandColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            group.band == FreqBand.hf ? Icons.nfc : Icons.radio,
            color: bandColor,
            size: 20,
          ),
        ),
        title: Text(group.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          context.l10n.messageDumpsKeyFilesFiles((group.dumpCount).toString(),
              (group.keyCount).toString(), (group.files.length).toString()),
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        children: [
          for (final f in group.files)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                f.fileType == CardFileType.dump
                    ? Icons.sd_storage
                    : f.fileType == CardFileType.key
                        ? Icons.vpn_key
                        : Icons.insert_drive_file,
                size: 16,
                color: f.fileType == CardFileType.dump
                    ? AppTheme.accentBlue
                    : AppTheme.accentBlue,
              ),
              title: Text(f.fileName,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              subtitle: Text(
                '${_formatBytes(f.sizeBytes)}  •  '
                '${_formatTime(f.modified)}  •  ${f.format}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              trailing: Wrap(
                runSpacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 16),
                    tooltip: context.l10n.messageOpenInDumpViewer,
                    onPressed: () {
                      context.read<AppState>().requestOpenDumpInViewer(f.path);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.l10n
                                .messageOpenedInDumpViewer(
                                    (f.fileName).toString()))),
                      );
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Organize dialog ────────────────────────────────────────────────────

  void _showOrganizeDialog(AppState appState) {
    final controller = TextEditingController(
      text: appState.collectBaseDir ?? '${Directory.current.path}/pm3_files',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.messageOrganizePm3Files),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              context.l10n
                  .messageOrganizeCollectedPm3ExportFilesIntoSubdirectories,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: context.l10n.messageDestinationDirectory,
                prefixIcon: Icon(Icons.folder, size: 18),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.messageFilesToOrganize(
                  (appState.collectedFiles.length).toString()),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.messageCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final count =
                  await appState.organizeCollectedFiles(controller.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(context.l10n
                          .messageFilesOrganized((count).toString()))),
                );
              }
            },
            child: Text(context.l10n.messageStartOrganizing),
          ),
        ],
      ),
    );
    // controller will be disposed when dialog closes (TextField is StatefulWidget)
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(value,
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashUsage(AppState appState) {
    final free = appState.hwFlashFree;
    final total = appState.hwFlashTotal;
    final used = total - free;
    final usedPct = total > 0 ? used / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(
              width: 80,
              child: Text(context.l10n.messageFlashUsage,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ),
            Expanded(
              child: Text(
                '${_formatBytes(used)} / ${_formatBytes(total)} '
                '(${(usedPct * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usedPct,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: usedPct > 0.9
                  ? const Color(0xFFF87171)
                  : usedPct > 0.7
                      ? const Color(0xFFF87171)
                      : AppTheme.accentBlue,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _getArch() {
    return Abi.current().toString().split('_').last;
  }
}

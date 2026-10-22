/// Home page with sidebar navigation — main app shell.
///
/// Grouped collapsible sidebar: General, HF, LF, Tools, Settings
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/core/pm3/pm3_connection.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/ui/pages/connection_page.dart';
import 'package:pm3gui/ui/pages/terminal_page.dart';
import 'package:pm3gui/ui/pages/dump_viewer_page.dart';
import 'package:pm3gui/ui/pages/dump_compare_page.dart';
import 'package:pm3gui/ui/pages/mifare_page.dart';
import 'package:pm3gui/ui/pages/lf_page.dart';
import 'package:pm3gui/ui/pages/settings_page.dart';
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_14b_page.dart';
import 'package:pm3gui/ui/pages/hf_felica_page.dart';
import 'package:pm3gui/ui/pages/hf_legic_page.dart';
import 'package:pm3gui/ui/pages/hf_emv_page.dart';
import 'package:pm3gui/ui/pages/hf_seos_page.dart';
import 'package:pm3gui/ui/pages/hf_fido_page.dart';
import 'package:pm3gui/ui/pages/hf_sniff_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';
import 'package:pm3gui/ui/pages/lf_hitag_page.dart';
import 'package:pm3gui/ui/pages/lf_awid_page.dart';
import 'package:pm3gui/ui/pages/lf_indala_page.dart';
import 'package:pm3gui/ui/pages/lf_io_page.dart';
import 'package:pm3gui/ui/pages/lf_pyramid_page.dart';
import 'package:pm3gui/ui/pages/lf_keri_page.dart';
import 'package:pm3gui/ui/pages/lf_fdxb_page.dart';
import 'package:pm3gui/ui/pages/data_page.dart';
import 'package:pm3gui/ui/pages/trace_page.dart';
import 'package:pm3gui/ui/pages/nfc_page.dart';
import 'package:pm3gui/ui/pages/script_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _sidebarExpanded = true;

  /// Pages ordered to match [AppPage] enum indices exactly.
  final _pages = const <Widget>[
    // General
    ConnectionPage(), // 0  connection
    TerminalPage(), // 1  terminal
    DumpViewerPage(), // 2  dumpViewer
    DumpComparePage(), // 3  dumpCompare
    // HF
    MifarePage(), // 4  mifare
    HfMfuPage(), // 5  mifareUltralight
    HfMfdesPage(), // 6  desfire
    HfIclassPage(), // 7  iclass
    Hf15Page(), // 8  iso15693
    Hf14bPage(), // 9  iso14443b
    HfFelicaPage(), // 10 felica
    HfLegicPage(), // 11 legic
    HfEmvPage(), // 12 emv
    HfSeosPage(), // 13 seos
    HfFidoPage(), // 14 fido
    HfSniffPage(), // 15 hfSniff
    // LF
    LfPage(), // 16 lf
    LfHidPage(), // 17 lfHid
    LfHitagPage(), // 18 lfHitag
    LfAwidPage(), // 19 lfAwid
    LfIndalaPage(), // 20 lfIndala
    LfIoPage(), // 21 lfIo
    LfPyramidPage(), // 22 lfPyramid
    LfKeriPage(), // 23 lfKeri
    LfFdxbPage(), // 24 lfFdxb
    // Tools
    DataPage(), // 25 data
    TracePage(), // 26 trace
    NfcPage(), // 27 nfc
    ScriptPage(), // 28 script
    SettingsPage(), // 29 settings
  ];

  List<_NavItem> get _generalItems => [
        _NavItem(Icons.usb, context.l10n.navConnection, AppPage.connection),
        _NavItem(Icons.terminal, context.l10n.navTerminal, AppPage.terminal),
        _NavItem(
            Icons.file_open, context.l10n.navDumpViewer, AppPage.dumpViewer),
        _NavItem(Icons.compare_arrows, context.l10n.navDumpCompare,
            AppPage.dumpCompare),
      ];

  List<_NavItem> get _hfItems => [
        _NavItem(Icons.nfc, 'Mifare Classic', AppPage.mifare),
        _NavItem(Icons.nfc, 'Ultralight/NTAG', AppPage.mifareUltralight),
        _NavItem(Icons.nfc, 'DESFire', AppPage.desfire),
        _NavItem(Icons.nfc, 'iCLASS', AppPage.iclass),
        _NavItem(Icons.nfc, 'ISO 15693', AppPage.iso15693),
        _NavItem(Icons.nfc, 'ISO 14443-B', AppPage.iso14443b),
        _NavItem(Icons.nfc, 'FeliCa', AppPage.felica),
        _NavItem(Icons.nfc, 'Legic', AppPage.legic),
        _NavItem(Icons.payment, 'EMV', AppPage.emv),
        _NavItem(Icons.badge, 'SEOS', AppPage.seos),
        _NavItem(Icons.fingerprint, 'FIDO', AppPage.fido),
        _NavItem(Icons.hearing, context.l10n.navHfSniff, AppPage.hfSniff),
      ];

  List<_NavItem> get _lfItems => [
        _NavItem(Icons.radio, context.l10n.navLfGeneral, AppPage.lf),
        _NavItem(Icons.credit_card, 'HID Prox', AppPage.lfHid),
        _NavItem(Icons.security, 'Hitag', AppPage.lfHitag),
        _NavItem(Icons.credit_card, 'AWID', AppPage.lfAwid),
        _NavItem(Icons.credit_card, 'Indala', AppPage.lfIndala),
        _NavItem(Icons.credit_card, 'ioProx', AppPage.lfIo),
        _NavItem(Icons.credit_card, 'Pyramid', AppPage.lfPyramid),
        _NavItem(Icons.credit_card, 'Keri', AppPage.lfKeri),
        _NavItem(Icons.pets, 'FDX-B', AppPage.lfFdxb),
      ];

  List<_NavItem> get _toolItems => [
        _NavItem(Icons.show_chart, context.l10n.navData, AppPage.data),
        _NavItem(Icons.timeline, 'Trace', AppPage.trace),
        _NavItem(Icons.nfc, 'NFC', AppPage.nfc),
        _NavItem(Icons.code, context.l10n.navScripts, AppPage.script),
        _NavItem(Icons.settings, context.l10n.navSettings, AppPage.settings),
      ];

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final currentPageIndex =
        context.select<AppState, int>((s) => s.currentPageIndex);
    final pm3Version = context.select<AppState, String>((s) => s.pm3Version);
    final isConnected = context.select<AppState, bool>((s) =>
        s.connectionState.connectionState == Pm3ConnectionState.connected);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarExpanded ? 220 : 72,
            child: Material(
              color: isDark ? const Color(0xFF161622) : const Color(0xFFF0F2F5),
              child: Column(
                children: [
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.nfc,
                            color:
                                isConnected ? Colors.greenAccent : Colors.grey,
                            size: 28),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PM3 GUI',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                if (pm3Version.isNotEmpty)
                                  Text(pm3Version,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500]),
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sidebarExpanded ? 12 : 8, vertical: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: _sidebarExpanded ? 10 : 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          if (_sidebarExpanded) ...[
                            const SizedBox(width: 8),
                            Text(
                              isConnected
                                  ? context.l10n.connected
                                  : context.l10n.disconnected,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isConnected
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _sidebarExpanded
                        ? _buildExpandedNav(appState, theme, currentPageIndex)
                        : _buildCollapsedNav(appState, theme, currentPageIndex),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          setState(() => _sidebarExpanded = !_sidebarExpanded),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              _sidebarExpanded
                                  ? Icons.chevron_left
                                  : Icons.chevron_right,
                              size: 20,
                              color: Colors.grey,
                            ),
                            if (_sidebarExpanded) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(context.l10n.navCollapse,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          VerticalDivider(
              width: 1,
              color: isDark ? const Color(0xFF2A2A3C) : Colors.grey[300]),
          Expanded(
            child: IndexedStack(
              index: currentPageIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedNav(
      AppState appState, ThemeData theme, int currentPageIndex) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: [
        ..._generalItems
            .map((n) => _navTile(n, appState, theme, currentPageIndex)),
        _groupTile(context.l10n.navHighFrequency, _hfItems, appState, theme,
            currentPageIndex),
        _groupTile(context.l10n.navLowFrequency, _lfItems, appState, theme,
            currentPageIndex),
        _groupTile(context.l10n.navTools, _toolItems, appState, theme,
            currentPageIndex),
      ],
    );
  }

  Widget _buildCollapsedNav(
      AppState appState, ThemeData theme, int currentPageIndex) {
    final all = [..._generalItems, ..._hfItems, ..._lfItems, ..._toolItems];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: all.map((n) {
        final selected = n.page.index == currentPageIndex;
        return Tooltip(
          message: n.label,
          preferBelow: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => appState.setCurrentPage(n.page.index),
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: Icon(n.icon,
                        size: 20,
                        color:
                            selected ? theme.colorScheme.primary : Colors.grey),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _groupTile(String title, List<_NavItem> items, AppState appState,
      ThemeData theme, int currentPageIndex) {
    final anySelected = items.any((n) => n.page.index == currentPageIndex);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: anySelected ? theme.colorScheme.primary : Colors.grey[500],
            )),
        dense: true,
        initiallyExpanded: anySelected,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: EdgeInsets.zero,
        children: items
            .map((n) => _navTile(n, appState, theme, currentPageIndex))
            .toList(),
      ),
    );
  }

  Widget _navTile(
      _NavItem item, AppState appState, ThemeData theme, int currentPageIndex) {
    final selected = item.page.index == currentPageIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => appState.setCurrentPage(item.page.index),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 18,
                    color: selected ? theme.colorScheme.primary : Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final AppPage page;
  const _NavItem(this.icon, this.label, this.page);
}

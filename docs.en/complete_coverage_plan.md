# PM3GUI Complete Coverage Improvement Plan

> This file retains the coverage plan from before PR #27; the protocol counts, pages to add, and phase statuses below
> are records of the original plan, not a current completion checklist. PR #27 adds the English/Chinese interface and localization workflow;
> it does not justify claims of added or validated protocol capabilities. For the current scope, see the [README](../README.en.md),
> [implementation status](refactoring_plan.md), and [localization guide](localization.md).

## 1. Coverage Analysis at the Time of the Original Plan

### 1.1 Already Covered Protocols (7)
- HF Mifare Classic
- HF 14443-A
- General LF
- LF EM4x
- LF T55xx
- HW Hardware

### 1.2 Newly Documented Protocols (5)
- HF Mifare Ultralight/NTAG
- HF iCLASS/Picopass
- HF ISO15693
- HF Mifare DESFire
- LF HID Prox

### 1.3 Protocols to Add (15)

#### High Frequency (HF) - 6
| Protocol | Command Count | Priority | Common Scenarios |
|------|--------|--------|----------|
| 14443-B | 9 | P1 | Standard Type B cards |
| FeliCa | 8 | P2 | Japanese transit cards |
| Legic | 7 | P2 | Access control systems |
| SEOS | 3 | P3 | High-security access control |
| EMV | 15 | P1 | Bank cards/payments |
| FIDO | 3 | P3 | Security authentication |

#### Low Frequency (LF) - 8
| Protocol | Command Count | Priority | Common Scenarios |
|------|--------|--------|----------|
| AWID | 3 | P2 | Access cards |
| Indala | 3 | P2 | Access cards |
| Hitag | 7 | P1 | Car keys |
| IO | 3 | P2 | Access cards |
| Pyramid | 2 | P3 | Access cards |
| Keri | 2 | P3 | Access cards |
| FDXB | 2 | P3 | Animal tags |
| EM4x05/4x50/4x70 | 12 | P2 | Specialized applications |

#### Other - 4
| Protocol | Command Count | Priority | Description |
|------|--------|--------|------|
| Data | 30+ | P2 | Data analysis |
| Trace | 4 | P2 | Trace analysis |
| NFC | 5 | P2 | NFC decoding |
| Script | 2 | P3 | Script execution |

---

## 2. Complete Page List (27 Protocols)

### High-frequency Pages (13)
1. **hf_mfu_page.dart** - Mifare Ultralight/NTAG ✅
2. **hf_mfdes_page.dart** - Mifare DESFire ✅
3. **hf_iclass_page.dart** - iCLASS/Picopass ✅
4. **hf_15_page.dart** - ISO15693 ✅
5. **hf_14b_page.dart** - 14443-B 📋
6. **hf_felica_page.dart** - FeliCa 📋
7. **hf_legic_page.dart** - Legic 📋
8. **hf_seos_page.dart** - SEOS 📋
9. **hf_emv_page.dart** - EMV 📋
10. **hf_fido_page.dart** - FIDO 📋
11. **hf_mf_page.dart** - Mifare Classic (existing)
12. **hf_14a_page.dart** - 14443-A (existing)
13. **hf_sniff_page.dart** - General sniffing 📋

### Low-frequency Pages (9)
1. **lf_hid_page.dart** - HID Prox ✅
2. **lf_awid_page.dart** - AWID 📋
3. **lf_indala_page.dart** - Indala 📋
4. **lf_hitag_page.dart** - Hitag 📋
5. **lf_io_page.dart** - IO Prox 📋
6. **lf_pyramid_page.dart** - Pyramid 📋
7. **lf_keri_page.dart** - Keri 📋
8. **lf_fdxb_page.dart** - FDXB 📋
9. **lf_em4x_page.dart** - EM4x family (existing)

### Tool Pages (5)
1. **data_page.dart** - Data analysis 📋
2. **trace_page.dart** - Trace analysis 📋
3. **nfc_page.dart** - NFC decoding 📋
4. **script_page.dart** - Script execution 📋
5. **hw_page.dart** - Hardware information (existing)

---

## 3. Unified Page Template

All new pages follow a unified code structure:

```dart
/// [Protocol] operations page
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/theme.dart';

class [Protocol]Page extends StatefulWidget {
  const [Protocol]Page({super.key});

  @override
  State<[Protocol]Page> createState() => _[Protocol]PageState();
}

class _[Protocol]PageState extends State<[Protocol]Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: N, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _execute(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PM3 is not connected')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '';
    });

    appState.sendCommand(cmd).then((_) {
      setState(() {
        _isLoading = false;
        _result = appState.terminalOutput.last;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tab 1'),
            Tab(text: 'Tab 2'),
            // ...
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1(),
              _buildTab2(),
              // ...
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? 'Run a command to view results' : _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
```

---

## 4. Navigation Structure Update

### 4.1 Sidebar Grouping

Group the sidebar by protocol type as follows:

```
📁 High Frequency (HF)
  ├── Mifare Classic
  ├── Mifare Ultralight
  ├── Mifare DESFire
  ├── iCLASS
  ├── ISO15693
  ├── 14443-B
  ├── FeliCa
  ├── Legic
  ├── SEOS
  ├── EMV
  └── FIDO

📁 Low Frequency (LF)
  ├── EM4x
  ├── T55xx
  ├── HID Prox
  ├── AWID
  ├── Indala
  ├── Hitag
  ├── IO Prox
  ├── Pyramid
  ├── Keri
  └── FDXB

📁 Tools
  ├── Data Analysis
  ├── Trace Analysis
  ├── NFC Decoding
  └── Script Execution
```

### 4.2 home_page.dart Update

```dart
// Import all new pages
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_14b_page.dart';
import 'package:pm3gui/ui/pages/hf_felica_page.dart';
import 'package:pm3gui/ui/pages/hf_legic_page.dart';
import 'package:pm3gui/ui/pages/hf_seos_page.dart';
import 'package:pm3gui/ui/pages/hf_emv_page.dart';
import 'package:pm3gui/ui/pages/hf_fido_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';
import 'package:pm3gui/ui/pages/lf_awid_page.dart';
import 'package:pm3gui/ui/pages/lf_indala_page.dart';
import 'package:pm3gui/ui/pages/lf_hitag_page.dart';
import 'package:pm3gui/ui/pages/lf_io_page.dart';
import 'package:pm3gui/ui/pages/lf_pyramid_page.dart';
import 'package:pm3gui/ui/pages/lf_keri_page.dart';
import 'package:pm3gui/ui/pages/lf_fdxb_page.dart';
import 'package:pm3gui/ui/pages/data_page.dart';
import 'package:pm3gui/ui/pages/trace_page.dart';
import 'package:pm3gui/ui/pages/nfc_page.dart';
import 'package:pm3gui/ui/pages/script_page.dart';

// _pages list
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  // HF pages
  MifarePage(),
  HfMfuPage(),
  HfMfdesPage(),
  HfIclassPage(),
  Hf15Page(),
  Hf14bPage(),
  HfFelicaPage(),
  HfLegicPage(),
  HfSeosPage(),
  HfEmvPage(),
  HfFidoPage(),
  // LF pages
  LfPage(),
  LfHidPage(),
  LfAwidPage(),
  LfIndalaPage(),
  LfHitagPage(),
  LfIoPage(),
  LfPyramidPage(),
  LfKeriPage(),
  LfFdxbPage(),
  // Tool pages
  DataPage(),
  TracePage(),
  NfcPage(),
  ScriptPage(),
  SettingsPage(),
];
```

---

## 5. Projected Coverage Improvement

### 5.1 Coverage After Adding All Pages

| Metric | Current | After Addition | Improvement |
|:-----|:----:|:------:|:----:|
| **Total protocol families** | 27 | 27 | - |
| **Covered protocol families** | 7 | **27** | **+20** |
| **Protocol family coverage** | **26%** | **100%** | **+74%** |
| **GUI-wrapped commands** | 43 | **~200** | **+157** |
| **Accessible through the terminal** | 100% | 100% | - |

### 5.2 Coverage by Protocol

After adding all pages, all 27 protocol families will be covered:

- ✅ **High Frequency (HF)** - All 13 protocols covered
- ✅ **Low Frequency (LF)** - All 9 protocols covered
- ✅ **Tools** - All 5 categories covered

---

## 6. Implementation Recommendations

### 6.1 Phased Implementation

Implementation in three batches by priority is recommended:

**First Batch (P0-P1)** - Core functionality
- HF: Ultralight, DESFire, iCLASS, ISO15693, 14443-B, EMV
- LF: HID Prox, Hitag
- Tools: Data, Trace

**Second Batch (P2)** - Common functionality
- HF: FeliCa, Legic
- LF: AWID, Indala, IO, EM4x05/4x50/4x70
- Tools: NFC

**Third Batch (P3)** - Specialized functionality
- HF: SEOS, FIDO
- LF: Pyramid, Keri, FDXB
- Tools: Script

### 6.2 Code Reuse

Extract the following shared components:

```dart
// lib/ui/components/
├── action_button.dart      // General-purpose action button
├── hex_input_field.dart    // Hexadecimal input field
├── result_display.dart     // Result display area
├── file_selector.dart      // File selector
├── tab_page_scaffold.dart  // Tab page scaffold
└── command_executor.dart   // Command executor
```

### 6.3 Testing Strategy

1. **Unit Tests** - Test each page independently
2. **Integration Tests** - Navigation between pages and state sharing
3. **Command Tests** - Verify that all commands are sent correctly
4. **UI Tests** - Verify interface display and interaction

---

## 7. Summary

By adding 20 new pages, PM3GUI's coverage will increase from **26%** to **100%**, providing complete GUI support for all 27 protocol families.

### Key Benefits
- **100% protocol coverage** - GUI support for all common card types
- **Consistent user experience** - All pages follow the same design pattern
- **Zero maintenance cost** - Command compatibility is automatically inherited from the PM3 client
- **Extensible architecture** - Easy to add support for new protocols

### Document Checklist
- ✅ `hf_mfu_page_spec.md` - Mifare Ultralight/NTAG
- ✅ `hf_mfdes_page_spec.md` - Mifare DESFire
- ✅ `hf_iclass_page_spec.md` - iCLASS/Picopass
- ✅ `hf_15_page_spec.md` - ISO15693
- ✅ `lf_hid_page_spec.md` - HID Prox
- ✅ `hf_14b_page_spec.md` - 14443-B
- 📋 Documentation for the other 15 protocols is to be generated

### Next Actions
1. Generate detailed documentation for the remaining 15 protocols based on this document
2. Extract shared components and establish a component library
3. Implement pages in batches by priority
4. Establish a complete test suite
5. Update user documentation and tutorials

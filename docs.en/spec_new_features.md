# PM3GUI New Feature Page Development Plan

> This is an original feature-design reference from before PR #27, not a
> statement of current feature or platform completion. The original Chinese
> layouts and code examples are translated here as design illustrations.
> Current implementations must use the English/Chinese resources, message
> injection and validation behavior specified in [Localization](localization.md);
> do not reintroduce hard-coded Chinese UI text.
> See the [documentation index](README.md) for current usage and support scope.

## 1. Project Overview

### 1.1 Goal
Add new feature pages to PM3GUI to expand coverage of Proxmark3 commands,
prioritizing common high-frequency (HF) and low-frequency (LF) card functions
that do not yet have GUI support.

### 1.2 Design Principles
- **Consistency**: Follow the existing pages' design style and code patterns.
- **Incremental delivery**: Implement the most frequently used functions first,
  then expand them gradually.
- **Extensibility**: Use an architecture that makes it easy to add support for
  more protocols later.

---

## 2. Planned New Feature Pages

### 2.1 Page Priorities

| Priority | Page Name | Protocol | Rationale |
|:--------:|:---------:|:--------:|:----------|
| P0 | **Mifare Ultralight/NTAG** | hf mfu | One of the most common HF card families, with widespread use |
| P0 | **iCLASS/Picopass** | hf iclass | Common in access-control systems, with strong demand |
| P1 | **ISO15693** | hf 15 | Common in industrial and library tags |
| P1 | **Mifare DESFire** | hf mfdes | Advanced secure cards |
| P1 | **HID Prox** | lf hid | The most common LF access-control cards |
| P2 | **FeliCa** | hf felica | Common in Japan |
| P2 | **Hitag** | lf hitag | Applications such as vehicle keys |

---

## 3. Detailed Design Specifications

### 3.1 Mifare Ultralight/NTAG Page (hf_mfu_page.dart)

#### 3.1.1 Functional Scope
Based on the 17 commands defined in `HfMfuCmd`:
- `info()` - Tag information
- `dump()` - Dump card data
- `rdbl()` - Read a block
- `wrbl()` - Write a block
- `restore()` - Restore a card
- `view()` - View a dump file
- `wipe()` - Erase a card
- `ndefRead()` - Read NDEF data
- `keygen()` - Generate keys
- `pwdgen()` - Generate a password
- `cauth()` - Authenticate
- `cchk()` - Check passwords
- `sim()` - Simulate a card
- `eload()` - Load into the emulator
- `esave()` - Save emulator data
- `eview()` - View the emulator
- `setuid()` - Set the UID

#### 3.1.2 Page Layout
```text
+-------------------------------------------------------------+
| TabBar: [Information] [Read/Write] [NDEF] [Emulator] [Tools]   |
+-------------------------------------------------------------+
|                                                             |
| Tab 1 - Information:                                        |
| +-------------------------------------------------------+   |
| | [Get information] [Dump card] [Erase card]              |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 2 - Read/Write:                                         |
| +-------------------------------------------------------+   |
| | Block: [0-255 v] [Read block]                           |   |
| | Data: [________________] [Write block]                  |   |
| | Password: [________________] [Authenticate]             |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 3 - NDEF:                                               |
| +-------------------------------------------------------+   |
| | [Read NDEF] Result-display area...                      |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 4 - Emulator:                                           |
| +-------------------------------------------------------+   |
| | [Load file] [Save to file] [View] [Simulate]             |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 5 - Tools:                                              |
| +-------------------------------------------------------+   |
| | [Generate key] [Generate password] [Set UID]            |   |
| +-------------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
```

#### 3.1.3 Key Implementation Details
- Block-number range: 0-255, the maximum supported by NTAG216
- Data format: eight hexadecimal bytes, or 16 characters
- Password format: four hexadecimal bytes, or eight characters
- UID format: seven hexadecimal bytes, or 14 characters

---

### 3.2 iCLASS/Picopass Page (hf_iclass_page.dart)

#### 3.2.1 Functional Scope
Use `HfIclassCmd`, prioritizing core functions:
- `info()` - Tag information
- `reader()` - Reader mode
- `dump()` - Dump a card
- `rdbl()` - Read a block
- `wrbl()` - Write a block
- `restore()` - Restore a card
- `view()` - View a dump
- `sniff()` - Sniff
- `chk()` - Check keys
- `loclass()` - Offline key recovery
- `sim()` - Simulate
- `eload()/esave()/eview()` - Emulator operations

#### 3.2.2 Page Layout
```text
+-------------------------------------------------------------+
| TabBar: [Information] [Read/Write] [Key Recovery] [Emulator]  |
+-------------------------------------------------------------+
|                                                             |
| Tab 1 - Information:                                        |
| +-------------------------------------------------------+   |
| | [Get information] [Read card] [Dump card]               |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 2 - Read/Write:                                         |
| +-------------------------------------------------------+   |
| | Block: [0-31 v] Key: [________________] [Read]          |   |
| | Data: [________________] [Write]                       |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 3 - Key Recovery:                                       |
| +-------------------------------------------------------+   |
| | [Check keys] [Loclass attack] [Sniff communication]     |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 4 - Emulator:                                           |
| +-------------------------------------------------------+   |
| | [Load] [Save] [View] [Simulate]                         |   |
| +-------------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
```

#### 3.2.3 Key Implementation Details
- Block-number range: 0-31, for iCLASS 2K
- Key format: eight hexadecimal bytes, or 16 characters
- Data format: eight hexadecimal bytes, or 16 characters

---

### 3.3 ISO15693 Page (hf_15_page.dart)

#### 3.3.1 Functional Scope
Use `Hf15Cmd` to implement core functions:
- `reader()` - Reader
- `info()` - Tag information
- `dump()` - Dump
- `restore()` - Restore
- `rdbl()` - Read a block
- `wrbl()` - Write a block
- `view()` - View a dump
- `wipe()` - Erase
- `sniff()` - Sniff
- `sim()` - Simulate
- `findafi()` - Find the AFI
- `csetuid()` - Set the UID

#### 3.3.2 Page Layout
Use a structure similar to the Mifare page, with:
- Information tab: reader, information and dump
- Read/Write tab: block read/write operations
- Tools tab: AFI search, UID setting and simulation

---

### 3.4 Mifare DESFire Page (hf_mfdes_page.dart)

#### 3.4.1 Functional Scope
Use `HfMfdesCmd` to implement basic functions:
- `info()` - Tag information
- `detect()` - Detect
- `getuid()` - Get the UID
- `freemem()` - Free memory
- `chk()` - Check keys
- `auth()` - Authenticate
- `formatpicc()` - Format
- `getaids()` - Get the AID list
- `lsapp()` - List applications
- `selectapp()` - Select an application
- `dump()` - Dump
- `read()` - Read a file
- `write()` - Write a file

#### 3.4.2 Page Layout
```text
+-------------------------------------------------------------+
| TabBar: [Information] [Applications] [Files] [Management]     |
+-------------------------------------------------------------+
|                                                             |
| Tab 1 - Information:                                        |
| +-------------------------------------------------------+   |
| | [Detect] [Information] [UID] [Free memory] [Check keys] |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 2 - Applications:                                       |
| +-------------------------------------------------------+   |
| | [List AIDs] [List applications]                       |   |
| | AID: [________] [Select application]                  |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 3 - Files:                                              |
| +-------------------------------------------------------+   |
| | [List files] [Dump application]                       |   |
| | FID: [____] [Read] [Write]                             |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 4 - Management:                                         |
| +-------------------------------------------------------+   |
| | [Authenticate] [Format PICC]                          |   |
| +-------------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
```

---

### 3.5 HID Prox Page (lf_hid_page.dart)

#### 3.5.1 Functional Scope
Based on `LfHidCmd`:
- `reader()` - Read
- `demod()` - Demodulate
- `clone()` - Clone
- `sim()` - Simulate
- `brute()` - Brute-force

#### 3.5.2 Page Layout
```text
+-------------------------------------------------------------+
| TabBar: [Read] [Clone/Simulate] [Brute-force]                 |
+-------------------------------------------------------------+
|                                                             |
| Tab 1 - Read:                                               |
| +-------------------------------------------------------+   |
| | [Read HID card] [Demodulate signal]                    |   |
| | Result-display area...                                |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 2 - Clone/Simulate:                                     |
| +-------------------------------------------------------+   |
| | Card data: [________________]                         |   |
| | [Clone to T55xx] [Simulate card]                       |   |
| +-------------------------------------------------------+   |
|                                                             |
| Tab 3 - Brute-force:                                        |
| +-------------------------------------------------------+   |
| | FC: [____] (optional)                                 |   |
| | [Brute-force]                                         |   |
| +-------------------------------------------------------+   |
|                                                             |
+-------------------------------------------------------------+
```

---

## 4. Technical Implementation Standards

### 4.1 File Structure
```text
lib/
|-- ui/
|   |-- pages/
|   |   |-- hf_mfu_page.dart      # NEW: Ultralight/NTAG
|   |   |-- hf_iclass_page.dart   # NEW: iCLASS/Picopass
|   |   |-- hf_15_page.dart       # NEW: ISO15693
|   |   |-- hf_mfdes_page.dart    # NEW: DESFire
|   |   |-- lf_hid_page.dart      # NEW: HID Prox
|   |   `-- ... (existing pages)
|   `-- home_page.dart            # MODIFY: Add navigation entries
|-- services/
|   `-- pm3_commands.dart         # EXISTING: Already contains the required commands
`-- state/
    `-- app_state.dart            # EXISTING: No changes needed
```

### 4.2 Code Pattern

Each new page follows this pattern:

```dart
/// Operations page for the named feature.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';

class XxxPage extends StatefulWidget {
  const XxxPage({super.key});

  @override
  State<XxxPage> createState() => _XxxPageState();
}

class _XxxPageState extends State<XxxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ... State variables

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
        const SnackBar(content: Text('PM3 not connected')),
      );
      return;
    }
    appState.sendCommand(cmd);
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
  // ... _buildTabX() methods
}
```

### 4.3 Navigation Integration

In `home_page.dart`:

```dart
// 1. Import the new pages.
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
// ...

// 2. Add them to the _pages list.
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  MifarePage(),
  HfMfuPage(),        // NEW
  HfIclassPage(),     // NEW
  LfPage(),
  LfHidPage(),        // NEW
  SettingsPage(),
];

// 3. Add them to the _navItems list.
static const _navItems = [
  _NavItem(Icons.usb, Icons.usb, 'Connection', 'Device connection'),
  _NavItem(Icons.terminal, Icons.terminal, 'Terminal', 'Interactive terminal'),
  _NavItem(Icons.file_open, Icons.file_open, 'Dump', 'View/edit dumps'),
  _NavItem(Icons.compare_arrows, Icons.compare_arrows, 'Compare', 'Dump comparison'),
  _NavItem(Icons.nfc, Icons.nfc, 'Mifare', 'Mifare Classic'),
  _NavItem(Icons.memory, Icons.memory, 'NTAG', 'Ultralight/NTAG'),  // NEW
  _NavItem(Icons.badge, Icons.badge, 'iCLASS', 'iCLASS/Picopass'),  // NEW
  _NavItem(Icons.radio, Icons.radio, 'Low Frequency', 'LF operations'),
  _NavItem(Icons.door_front_door_outlined, Icons.door_front_door_outlined,
           'HID', 'HID Prox'),  // NEW
  _NavItem(Icons.settings, Icons.settings, 'Settings', 'Application settings'),
];
```

---

## 5. UI/UX Design Standards

### 5.1 Colors
Continue the Morandi palette:
- Primary: `#7E9AAB` (Morandi blue)
- Success/HF: `#8FA9A0` (Morandi green)
- Warning/LF: `#BFA2A2` (Morandi rose)
- Secondary information: `#A89F91` (Morandi warm gray)

### 5.2 Components
- **Action cards**: Use `Card` + `ListTile`, with an icon and subtitle.
- **Inputs**: Use `TextFormField`, with a monospace font for hexadecimal data.
- **Buttons**: Use `ElevatedButton` for primary actions and `OutlinedButton`
  for secondary actions.
- **Segmented buttons**: Use `SegmentedButton` to switch options.

### 5.3 Interaction Feedback
- Display a loading indicator while a command is running.
- Display results in a scrollable card.
- Support copying results to the clipboard.
- Require a confirmation dialog for dangerous operations such as erasing.

---

## 6. Test Plan

### 6.1 Functional Tests
- [ ] Tabs switch normally on every page.
- [ ] All buttons send the correct commands.
- [ ] Input validation covers hexadecimal format and length.
- [ ] Results can be displayed and copied.
- [ ] A prompt is shown when no device is connected.

### 6.2 Integration Tests
- [ ] New pages integrate with sidebar navigation.
- [ ] Theme switching works normally.
- [ ] New pages coexist with existing pages without conflicts.

---

## 7. Appendix

### 7.1 Reference Resources
- [pm3_commands.yaml](../docs/pm3_commands.yaml) - Command-mapping reference
- [pm3_commands.dart](../lib/services/pm3_commands.dart) - Command wrapper classes
- [mifare_page.dart](../lib/ui/pages/mifare_page.dart) - Reference implementation

### 7.2 Command Quick Reference

```bash
# Mifare Ultralight
hf mfu info
hf mfu dump -f <file>
hf mfu rdbl -b <block>
hf mfu wrbl -b <block> -d <data>
hf mfu ndefread

# iCLASS
hf iclass info
hf iclass dump -f <file>
hf iclass rdbl -b <block> [-k <key>]
hf iclass wrbl -b <block> -d <data> [-k <key>]

# ISO15693
hf 15 reader
hf 15 dump -f <file>
hf 15 rdbl -b <block>
hf 15 wrbl -b <block> -d <data>

# HID Prox
lf hid reader
lf hid clone -w <data>
lf hid sim -w <data>
```

# PM3GUI New Feature Page Development Task Breakdown

> The tasks, estimates and checkbox states below are preserved as planning
> records from before PR #27, not as the current backlog or feature list.
> New development should follow the [current implementation and roadmap](refactoring_plan.md),
> [localization guide](localization.md) and [contributing guide](../CONTRIBUTING.en.md).
> The original examples' Chinese UI text has been translated here for readers;
> production UI text must use ARB resources. Command and data formats remain unchanged.

## Task Overview

Break down the five new pages in the planning document into specific,
actionable tasks.

---

## Phase 1: Basic Preparation (P0)

### Task 1.1: Update the Navigation Structure
**File**: `lib/ui/home_page.dart`
**Dependencies**: None
**Estimate**: 30 minutes

**Subtasks**:
- [ ] 1.1.1 Add imports for the new pages, initially using placeholder classes.
- [ ] 1.1.2 Update the `_pages` list with placeholders for the five new pages.
- [ ] 1.1.3 Update the `_navItems` list with five new navigation entries.
- [ ] 1.1.4 Verify that the application compiles and runs normally.

**Code-change preview**:
```dart
// Import the new pages.
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';

// The _pages list.
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  MifarePage(),
  HfMfuPage(),        // NEW
  HfIclassPage(),     // NEW
  Hf15Page(),         // NEW
  LfPage(),
  LfHidPage(),        // NEW
  SettingsPage(),
];

// The _navItems list.
static const _navItems = [
  _NavItem(Icons.usb, Icons.usb, 'Connection', 'Device connection'),
  _NavItem(Icons.terminal, Icons.terminal, 'Terminal', 'Interactive terminal'),
  _NavItem(Icons.file_open, Icons.file_open, 'Dump', 'View/edit dumps'),
  _NavItem(Icons.compare_arrows, Icons.compare_arrows, 'Compare', 'Dump comparison'),
  _NavItem(Icons.nfc, Icons.nfc, 'Mifare', 'Mifare Classic'),
  _NavItem(Icons.memory, Icons.memory, 'NTAG', 'Ultralight/NTAG'),
  _NavItem(Icons.badge, Icons.badge, 'iCLASS', 'iCLASS/Picopass'),
  _NavItem(Icons.contactless, Icons.contactless, 'ISO15693', 'ISO15693'),
  _NavItem(Icons.radio, Icons.radio, 'Low Frequency', 'LF operations'),
  _NavItem(Icons.door_front_door_outlined, Icons.door_front_door_outlined,
           'HID', 'HID Prox'),
  _NavItem(Icons.settings, Icons.settings, 'Settings', 'Application settings'),
];
```

---

## Phase 2: Mifare Ultralight/NTAG Page (P0)

### Task 2.1: Create the Page Framework
**File**: `lib/ui/pages/hf_mfu_page.dart`
**Dependencies**: None
**Estimate**: 1 hour

**Subtasks**:
- [ ] 2.1.1 Create the basic file structure: imports and class definitions.
- [ ] 2.1.2 Implement the TabController with five tabs.
- [ ] 2.1.3 Implement the basic `_execute()` method.
- [ ] 2.1.4 Create five empty `_buildXxx()` methods.

### Task 2.2: Implement the "Information" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 2.2.1 Add the [Get information] button -> `HfMfuCmd.info()`.
- [ ] 2.2.2 Add the [Dump card] button -> `HfMfuCmd.dump()`.
- [ ] 2.2.3 Add the [Erase card] button, with a confirmation dialog -> `HfMfuCmd.wipe()`.
- [ ] 2.2.4 Add the result-display area.

### Task 2.3: Implement the "Read/Write" Tab
**Estimate**: 1.5 hours

**Subtasks**:
- [ ] 2.3.1 Add a block-number input with range validation for 0-255.
- [ ] 2.3.2 Add the [Read block] button -> `HfMfuCmd.rdbl()`.
- [ ] 2.3.3 Add a data input with validation for 16 hexadecimal characters.
- [ ] 2.3.4 Add the [Write block] button -> `HfMfuCmd.wrbl()`.
- [ ] 2.3.5 Add a password input for eight hexadecimal characters.
- [ ] 2.3.6 Add the [Authenticate] button -> `HfMfuCmd.cauth()`.

### Task 2.4: Implement the "NDEF" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 2.4.1 Add the [Read NDEF] button -> `HfMfuCmd.ndefRead()`.
- [ ] 2.4.2 Add the NDEF result-display area with formatted output.

### Task 2.5: Implement the "Emulator" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 2.5.1 Add file selection.
- [ ] 2.5.2 Add the [Load into emulator] button -> `HfMfuCmd.eload()`.
- [ ] 2.5.3 Add the [Save emulator] button -> `HfMfuCmd.esave()`.
- [ ] 2.5.4 Add the [View emulator] button -> `HfMfuCmd.eview()`.
- [ ] 2.5.5 Add the [Simulate card] button -> `HfMfuCmd.sim()`.

### Task 2.6: Implement the "Tools" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 2.6.1 Add the [Generate key] button -> `HfMfuCmd.keygen()`.
- [ ] 2.6.2 Add an optional UID input.
- [ ] 2.6.3 Add the [Generate password] button -> `HfMfuCmd.pwdgen()`.
- [ ] 2.6.4 Add the [Set UID] button -> `HfMfuCmd.setuid()`.

---

## Phase 3: iCLASS/Picopass Page (P0)

### Task 3.1: Create the Page Framework
**File**: `lib/ui/pages/hf_iclass_page.dart`
**Dependencies**: None
**Estimate**: 1 hour

**Subtasks**:
- [ ] 3.1.1 Create the basic file structure.
- [ ] 3.1.2 Implement the TabController with four tabs.
- [ ] 3.1.3 Implement the basic `_execute()` method.

### Task 3.2: Implement the "Information" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 3.2.1 Add the [Get information] button -> `HfIclassCmd.info()`.
- [ ] 3.2.2 Add the [Read card] button -> `HfIclassCmd.reader()`.
- [ ] 3.2.3 Add the [Dump card] button -> `HfIclassCmd.dump()`.

### Task 3.3: Implement the "Read/Write" Tab
**Estimate**: 1.5 hours

**Subtasks**:
- [ ] 3.3.1 Add a block-number selector for 0-31.
- [ ] 3.3.2 Add an optional key input for 16 hexadecimal characters.
- [ ] 3.3.3 Add the [Read block] button -> `HfIclassCmd.rdbl()`.
- [ ] 3.3.4 Add a data input for 16 hexadecimal characters.
- [ ] 3.3.5 Add the [Write block] button -> `HfIclassCmd.wrbl()`.

### Task 3.4: Implement the "Key Recovery" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 3.4.1 Add the [Check keys] button -> `HfIclassCmd.chk()`.
- [ ] 3.4.2 Add the [Loclass attack] button -> `HfIclassCmd.loclass()`.
- [ ] 3.4.3 Add the [Sniff communication] button -> `HfIclassCmd.sniff()`.

### Task 3.5: Implement the "Emulator" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 3.5.1 Add the [Load file] button -> `HfIclassCmd.eload()`.
- [ ] 3.5.2 Add the [Save file] button -> `HfIclassCmd.esave()`.
- [ ] 3.5.3 Add the [View] button -> `HfIclassCmd.eview()`.
- [ ] 3.5.4 Add the [Simulate card] button -> `HfIclassCmd.sim()`.

---

## Phase 4: ISO15693 Page (P1)

### Task 4.1: Create the Page Framework
**File**: `lib/ui/pages/hf_15_page.dart`
**Dependencies**: None
**Estimate**: 1 hour

**Subtasks**:
- [ ] 4.1.1 Create the basic file structure.
- [ ] 4.1.2 Implement the TabController with three tabs.
- [ ] 4.1.3 Implement the basic `_execute()` method.

### Task 4.2: Implement the "Information" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 4.2.1 Add the [Reader] button -> `Hf15Cmd.reader()`.
- [ ] 4.2.2 Add the [Tag information] button -> `Hf15Cmd.info()`.
- [ ] 4.2.3 Add the [Dump card] button -> `Hf15Cmd.dump()`.
- [ ] 4.2.4 Add the [Erase card] button -> `Hf15Cmd.wipe()`.

### Task 4.3: Implement the "Read/Write" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 4.3.1 Add a block-number input.
- [ ] 4.3.2 Add the [Read block] button -> `Hf15Cmd.rdbl()`.
- [ ] 4.3.3 Add a data input.
- [ ] 4.3.4 Add the [Write block] button -> `Hf15Cmd.wrbl()`.

### Task 4.4: Implement the "Tools" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 4.4.1 Add the [Find AFI] button -> `Hf15Cmd.findafi()`.
- [ ] 4.4.2 Add a UID input.
- [ ] 4.4.3 Add the [Set UID] button -> `Hf15Cmd.csetuid()`.
- [ ] 4.4.4 Add the [Simulate card] button -> `Hf15Cmd.sim()`.
- [ ] 4.4.5 Add the [Sniff] button -> `Hf15Cmd.sniff()`.

---

## Phase 5: Mifare DESFire Page (P1)

### Task 5.1: Create the Page Framework
**File**: `lib/ui/pages/hf_mfdes_page.dart`
**Dependencies**: None
**Estimate**: 1 hour

**Subtasks**:
- [ ] 5.1.1 Create the basic file structure.
- [ ] 5.1.2 Implement the TabController with four tabs.
- [ ] 5.1.3 Implement the basic `_execute()` method.

### Task 5.2: Implement the "Information" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 5.2.1 Add the [Detect] button -> `HfMfdesCmd.detect()`.
- [ ] 5.2.2 Add the [Information] button -> `HfMfdesCmd.info()`.
- [ ] 5.2.3 Add the [Get UID] button -> `HfMfdesCmd.getuid()`.
- [ ] 5.2.4 Add the [Free memory] button -> `HfMfdesCmd.freemem()`.
- [ ] 5.2.5 Add the [Check keys] button -> `HfMfdesCmd.chk()`.

### Task 5.3: Implement the "Applications" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 5.3.1 Add the [List AIDs] button -> `HfMfdesCmd.getaids()`.
- [ ] 5.3.2 Add the [List applications] button -> `HfMfdesCmd.lsapp()`.
- [ ] 5.3.3 Add an AID input for six hexadecimal characters.
- [ ] 5.3.4 Add the [Select application] button -> `HfMfdesCmd.selectapp()`.

### Task 5.4: Implement the "Files" Tab
**Estimate**: 1.5 hours

**Subtasks**:
- [ ] 5.4.1 Add the [List files] button -> `HfMfdesCmd.getfileids()`.
- [ ] 5.4.2 Add a FID input.
- [ ] 5.4.3 Add the [Read file] button -> `HfMfdesCmd.read()`.
- [ ] 5.4.4 Add a data input.
- [ ] 5.4.5 Add the [Write file] button -> `HfMfdesCmd.write()`.
- [ ] 5.4.6 Add the [Dump application] button -> `HfMfdesCmd.dump()`.

### Task 5.5: Implement the "Management" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 5.5.1 Add a key-number input.
- [ ] 5.5.2 Add a key input.
- [ ] 5.5.3 Add algorithm selection for AES/DES.
- [ ] 5.5.4 Add the [Authenticate] button -> `HfMfdesCmd.auth()`.
- [ ] 5.5.5 Add the [Format PICC] button, with confirmation -> `HfMfdesCmd.formatpicc()`.

---

## Phase 6: HID Prox Page (P1)

### Task 6.1: Create the Page Framework
**File**: `lib/ui/pages/lf_hid_page.dart`
**Dependencies**: None
**Estimate**: 1 hour

**Subtasks**:
- [ ] 6.1.1 Create the basic file structure.
- [ ] 6.1.2 Implement the TabController with three tabs.
- [ ] 6.1.3 Implement the basic `_execute()` method.

### Task 6.2: Implement the "Read" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 6.2.1 Add the [Read HID card] button -> `LfHidCmd.reader()`.
- [ ] 6.2.2 Add the [Demodulate signal] button -> `LfHidCmd.demod()`.
- [ ] 6.2.3 Add the result-display area, parsing FC/CN.

### Task 6.3: Implement the "Clone/Simulate" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 6.3.1 Add a card-data input in Wiegand format.
- [ ] 6.3.2 Add the [Clone to T55xx] button -> `LfHidCmd.clone()`.
- [ ] 6.3.3 Add the [Simulate card] button -> `LfHidCmd.sim()`.

### Task 6.4: Implement the "Brute-force" Tab
**Estimate**: 1 hour

**Subtasks**:
- [ ] 6.4.1 Add an optional FC input.
- [ ] 6.4.2 Add the [Brute-force] button -> `LfHidCmd.brute()`.

---

## Phase 7: Testing and Optimization

### Task 7.1: Unit Tests
**Estimate**: 2 hours

**Subtasks**:
- [ ] 7.1.1 Test tab switching on each page.
- [ ] 7.1.2 Test that every button triggers the correct command.
- [ ] 7.1.3 Test input validation for hexadecimal format and length.
- [ ] 7.1.4 Test the prompts shown when no device is connected.

### Task 7.2: Integration Tests
**Estimate**: 1 hour

**Subtasks**:
- [ ] 7.2.1 Test that sidebar navigation switches pages correctly.
- [ ] 7.2.2 Test that theme switching works normally.
- [ ] 7.2.3 Test for conflicts with existing pages.
- [ ] 7.2.4 Test application startup and runtime performance.

### Task 7.3: Code Optimization
**Estimate**: 2 hours

**Subtasks**:
- [ ] 7.3.1 Extract shared components, such as ActionCard and ResultDisplay.
- [ ] 7.3.2 Optimize duplicate code.
- [ ] 7.3.3 Add necessary comments.
- [ ] 7.3.4 Run `flutter analyze` to check for issues.

---

## Time-Estimate Summary

| Phase | Number of Tasks | Estimated Time | Actual Time |
|:-----:|:---------------:|:--------------:|:-----------:|
| Phase 1: Basic preparation | 1 | 0.5h | - |
| Phase 2: MFU page | 6 | 6.5h | - |
| Phase 3: iCLASS page | 5 | 5.5h | - |
| Phase 4: ISO15693 page | 4 | 4h | - |
| Phase 5: DESFire page | 5 | 5.5h | - |
| Phase 6: HID page | 4 | 4h | - |
| Phase 7: Testing and optimization | 3 | 5h | - |
| **Total** | **28** | **31h** | - |

---

## Dependency Diagram

```text
Phase 1: Basic preparation
    |
    |---> Phase 2: MFU page -----------+
    |                                 |
    |---> Phase 3: iCLASS page --------+
    |                                 |
    |---> Phase 4: ISO15693 page ------+---> Phase 7: Testing and optimization
    |                                 |
    |---> Phase 5: DESFire page -------+
    |                                 |
    `---> Phase 6: HID page -----------+
```

**Notes**:
- Phases 2-6 can be developed in parallel.
- Phase 7 must take place after all pages are complete.
- Within each phase, perform tasks in sequence where possible.

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|:-----|:----------:|:------:|:-----------|
| Command-parameter mismatch | Medium | High | Consult pm3_commands.yaml and test against the real CLI. |
| Too many pages crowd the navigation | Medium | Medium | Consider collapsible menus or categories. |
| State management becomes more complex | Low | Medium | Keep page state independent; do not add global state. |
| Compilation problems | Low | High | Run flutter analyze promptly after each change. |
